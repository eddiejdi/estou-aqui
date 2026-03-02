const express = require('express');
const router = express.Router();
const { BetaSignup } = require('../models');

// Rate limiting simples em memória
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60 * 60 * 1000; // 1 hora
const MAX_REQUESTS_PER_IP = 3;

function checkRateLimit(ip) {
  const now = Date.now();
  const record = rateLimitMap.get(ip);
  if (!record || now - record.firstRequest > RATE_LIMIT_WINDOW) {
    rateLimitMap.set(ip, { firstRequest: now, count: 1 });
    return true;
  }
  if (record.count >= MAX_REQUESTS_PER_IP) return false;
  record.count++;
  return true;
}

// Função para calcular bot score
function calculateBotScore(data, req) {
  let score = 0;

  // Nome muito curto ou sem espaço
  if (!data.name || data.name.length < 4) score += 30;
  if (data.name && !data.name.includes(' ')) score += 15;

  // Motivação muito curta
  if (!data.motivation || data.motivation.length < 20) score += 25;

  // Sem social URL
  if (!data.social_url) score += 10;

  // Email suspeito (temporário)
  const tempDomains = ['tempmail', 'guerrillamail', 'mailinator', 'throwaway', 'yopmail', '10minutemail'];
  if (data.email && tempDomains.some(d => data.email.includes(d))) score += 40;

  // User agent ausente ou genérico
  if (!data.user_agent || data.user_agent.length < 20) score += 20;

  // Timestamp vs horário do servidor (> 5min diferença = suspeito)
  if (data.timestamp) {
    const diff = Math.abs(Date.now() - new Date(data.timestamp).getTime());
    if (diff > 5 * 60 * 1000) score += 15;
  }

  return Math.min(score, 100);
}

// Enviar notificação via Telegram
async function notifyTelegram(signup) {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_ADMIN_CHAT_ID;

  if (!botToken || !chatId) {
    console.warn('Telegram notification not configured (TELEGRAM_BOT_TOKEN / TELEGRAM_ADMIN_CHAT_ID)');
    return;
  }

  const botEmoji = signup.botScore > 50 ? '🤖' : signup.botScore > 25 ? '⚠️' : '✅';
  const statusEmoji = signup.botScore > 50 ? '🔴 SUSPEITO' : signup.botScore > 25 ? '🟡 ATENÇÃO' : '🟢 OK';

  const message = `📋 *Nova Inscrição Beta - Estou Aqui*

👤 *Nome:* ${signup.name}
📧 *Email:* ${signup.email}
🏙️ *Cidade:* ${signup.city}
📱 *Telefone:* ${signup.phone || 'N/I'}
🔗 *Social:* ${signup.socialUrl || 'N/I'}
💬 *Motivação:* ${signup.motivation.substring(0, 200)}
📲 *Dispositivo:* ${signup.device || 'N/I'}

${botEmoji} *Bot Score:* ${signup.botScore}/100 — ${statusEmoji}
🌐 *IP:* ${signup.ipAddress || 'N/D'}

Para aprovar/rejeitar, acesse o painel de administração.`;

  try {
    const fetch = require('node-fetch');
    await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: 'Markdown',
      }),
    });
  } catch (err) {
    console.error('Telegram notification error:', err.message);
  }
}

// POST /api/beta-signup — Nova inscrição
router.post('/', async (req, res) => {
  try {
    const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;

    // Rate limit
    if (!checkRateLimit(ip)) {
      return res.status(429).json({ message: 'Muitas tentativas. Aguarde uma hora.' });
    }

    const { name, email, city, phone, social_url, motivation, device, source, timestamp, user_agent } = req.body;

    // Validação básica
    if (!name || !email || !city || !motivation) {
      return res.status(400).json({ message: 'Campos obrigatórios: nome, email, cidade e motivação.' });
    }

    // Verificar duplicata
    const existing = await BetaSignup.findOne({ where: { email: email.toLowerCase().trim() } });
    if (existing) {
      return res.status(409).json({ message: 'Este e-mail já está inscrito no beta.' });
    }

    // Calcular bot score
    const botScore = calculateBotScore(req.body, req);

    // Criar inscrição
    const signup = await BetaSignup.create({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      city: city.trim(),
      phone: phone ? phone.trim() : null,
      socialUrl: social_url ? social_url.trim() : null,
      motivation: motivation.trim(),
      device: device || null,
      source: source || 'landing_page',
      userAgent: user_agent || req.headers['user-agent'],
      botScore,
      ipAddress: ip,
      status: botScore > 70 ? 'rejected' : 'pending',
    });

    // Notificar admin via Telegram (async, não bloquear resposta)
    notifyTelegram(signup).catch(console.error);

    res.status(201).json({
      message: 'Inscrição recebida com sucesso! Analisaremos em breve.',
      id: signup.id,
    });
  } catch (error) {
    console.error('Beta signup error:', error);
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(409).json({ message: 'Este e-mail já está inscrito.' });
    }
    res.status(500).json({ message: 'Erro ao processar inscrição.' });
  }
});

// GET /api/beta-signup — Listar inscrições (admin — sem auth por hora, proteger depois)
router.get('/', async (req, res) => {
  try {
    const { status } = req.query;
    const where = status ? { status } : {};
    const signups = await BetaSignup.findAll({
      where,
      order: [['createdAt', 'DESC']],
      limit: 100,
    });
    res.json(signups);
  } catch (error) {
    console.error('List beta signups error:', error);
    res.status(500).json({ message: 'Erro ao listar inscrições.' });
  }
});

// PATCH /api/beta-signup/:id — Atualizar status (aprovar/rejeitar)
router.patch('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, reviewNotes } = req.body;

    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Status deve ser "approved" ou "rejected".' });
    }

    const signup = await BetaSignup.findByPk(id);
    if (!signup) return res.status(404).json({ message: 'Inscrição não encontrada.' });

    signup.status = status;
    if (reviewNotes) signup.reviewNotes = reviewNotes;
    await signup.save();

    res.json({ message: `Inscrição ${status === 'approved' ? 'aprovada' : 'rejeitada'}.`, signup });
  } catch (error) {
    console.error('Update beta signup error:', error);
    res.status(500).json({ message: 'Erro ao atualizar inscrição.' });
  }
});

module.exports = router;
