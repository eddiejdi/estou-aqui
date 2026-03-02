const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const { WebChatMessage } = require('../models');

// ─── Rate limiting em memória ──────────────────────────────────────────────────
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minuto
const MAX_MESSAGES_PER_MIN = 10;

function checkRateLimit(ip) {
  const now = Date.now();
  const record = rateLimitMap.get(ip);
  if (!record || now - record.firstRequest > RATE_LIMIT_WINDOW) {
    rateLimitMap.set(ip, { firstRequest: now, count: 1 });
    return true;
  }
  if (record.count >= MAX_MESSAGES_PER_MIN) return false;
  record.count++;
  return true;
}

// Limpar rate limit map a cada 5 minutos
setInterval(() => {
  const now = Date.now();
  for (const [ip, record] of rateLimitMap.entries()) {
    if (now - record.firstRequest > RATE_LIMIT_WINDOW) rateLimitMap.delete(ip);
  }
}, 5 * 60 * 1000);

// ─── Helpers ───────────────────────────────────────────────────────────────────
const TELEGRAM_API = 'https://api.telegram.org/bot';
const WEBHOOK_SECRET = process.env.WEBCHAT_WEBHOOK_SECRET || crypto.randomBytes(16).toString('hex');

function getBotToken() { return process.env.TELEGRAM_BOT_TOKEN; }
function getAdminChatId() { return process.env.TELEGRAM_ADMIN_CHAT_ID; }

async function sendTelegramMessage(text, replyToMessageId) {
  const token = getBotToken();
  const chatId = getAdminChatId();
  if (!token || !chatId) {
    console.warn('[webchat] Telegram not configured');
    return null;
  }
  try {
    const payload = {
      chat_id: chatId,
      text,
      parse_mode: 'HTML',
    };
    if (replyToMessageId) payload.reply_to_message_id = replyToMessageId;

    const resp = await axios.post(`${TELEGRAM_API}${token}/sendMessage`, payload);
    return resp.data;
  } catch (err) {
    console.error('[webchat] Telegram send error:', err.message);
    return null;
  }
}

// ─── POST /send — Visitante envia mensagem ─────────────────────────────────────
router.post('/send', async (req, res) => {
  try {
    const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;

    if (!checkRateLimit(ip)) {
      return res.status(429).json({ error: 'Muitas mensagens. Aguarde um minuto.' });
    }

    const { message, sessionId, senderName, source } = req.body;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({ error: 'Mensagem não pode ser vazia.' });
    }
    if (message.length > 2000) {
      return res.status(400).json({ error: 'Mensagem muito longa (máx 2000 caracteres).' });
    }

    // Gerar ou usar sessionId existente
    const sid = sessionId || crypto.randomUUID();
    const name = senderName || 'Visitante';
    const pageSource = source || 'rpa4all.com';

    // Contar mensagens da sessão para contexto
    const msgCount = await WebChatMessage.count({ where: { sessionId: sid } });

    // Salvar mensagem
    const chatMsg = await WebChatMessage.create({
      sessionId: sid,
      direction: 'incoming',
      message: message.trim(),
      senderName: name,
      ipAddress: ip,
      userAgent: req.headers['user-agent'],
      source: pageSource,
    });

    // Enviar para Telegram
    const emoji = msgCount === 0 ? '🆕' : '💬';
    const sourceLabel = pageSource === 'estou-aqui' ? '📱 Estou Aqui' : '🌐 RPA4ALL';
    const telegramText = `${emoji} <b>Chat Web — ${sourceLabel}</b>\n\n` +
      `👤 <b>${name}</b> (sessão: <code>${sid.substring(0, 8)}</code>)\n` +
      `💬 ${message.trim()}\n\n` +
      `${msgCount === 0 ? '🔔 Nova conversa' : `📨 Mensagem #${msgCount + 1}`}\n` +
      `🌍 IP: ${ip || 'N/D'}\n` +
      `ℹ️ <i>Responda esta mensagem para responder ao visitante.</i>`;

    const telegramResp = await sendTelegramMessage(telegramText);

    // Guardar o message_id do Telegram para associar replies
    if (telegramResp && telegramResp.result) {
      chatMsg.telegramMessageId = telegramResp.result.message_id;
      await chatMsg.save();
    }

    res.status(201).json({
      sessionId: sid,
      messageId: chatMsg.id,
      timestamp: chatMsg.createdAt,
    });
  } catch (error) {
    console.error('[webchat] Send error:', error);
    res.status(500).json({ error: 'Erro ao enviar mensagem.' });
  }
});

// ─── GET /messages/:sessionId — Buscar mensagens da sessão ─────────────────────
router.get('/messages/:sessionId', async (req, res) => {
  try {
    const { sessionId } = req.params;
    const { since } = req.query; // ISO timestamp para pegar apenas msgs novas

    const where = { sessionId };
    if (since) {
      const { Op } = require('sequelize');
      where.createdAt = { [Op.gt]: new Date(since) };
    }

    const messages = await WebChatMessage.findAll({
      where,
      order: [['createdAt', 'ASC']],
      limit: 200,
      attributes: ['id', 'direction', 'message', 'senderName', 'read', 'createdAt'],
    });

    res.json({ messages, sessionId });
  } catch (error) {
    console.error('[webchat] Messages error:', error);
    res.status(500).json({ error: 'Erro ao buscar mensagens.' });
  }
});

// ─── POST /telegram-webhook — Receber resposta do admin via Telegram ───────────
router.post('/telegram-webhook', async (req, res) => {
  try {
    // Verificar secret token
    const secretHeader = req.headers['x-telegram-bot-api-secret-token'];
    if (secretHeader !== WEBHOOK_SECRET) {
      console.warn('[webchat] Invalid webhook secret');
      return res.sendStatus(403);
    }

    const update = req.body;
    if (!update || !update.message) {
      return res.sendStatus(200); // Ignorar updates sem mensagem
    }

    const msg = update.message;
    const adminChatId = getAdminChatId();

    // Só processar mensagens do admin
    if (String(msg.chat.id) !== String(adminChatId)) {
      return res.sendStatus(200);
    }

    // Verificar se é uma resposta a uma mensagem do chat
    if (!msg.reply_to_message) {
      return res.sendStatus(200); // Ignorar mensagens que não são reply
    }

    const replyToId = msg.reply_to_message.message_id;

    // Encontrar a mensagem original pelo telegramMessageId
    const originalMsg = await WebChatMessage.findOne({
      where: { telegramMessageId: replyToId },
    });

    if (!originalMsg) {
      // Pode não ser uma reply a uma msg do chat web
      console.log('[webchat] No matching session for telegram message_id:', replyToId);
      return res.sendStatus(200);
    }

    // Salvar resposta do admin
    const adminReply = await WebChatMessage.create({
      sessionId: originalMsg.sessionId,
      direction: 'outgoing',
      message: msg.text || '(mídia não suportada)',
      senderName: msg.from.first_name || 'Admin',
      source: originalMsg.source,
    });

    console.log(`[webchat] Admin reply stored for session ${originalMsg.sessionId}`);

    // Confirmar no Telegram
    await sendTelegramMessage(
      `✅ Resposta enviada ao visitante (sessão: ${originalMsg.sessionId.substring(0, 8)})`,
      msg.message_id
    );

    res.sendStatus(200);
  } catch (error) {
    console.error('[webchat] Webhook error:', error);
    res.sendStatus(200); // Sempre retornar 200 para Telegram não reenviar
  }
});

// ─── POST /setup-webhook — Configurar webhook do Telegram ──────────────────────
router.post('/setup-webhook', async (req, res) => {
  try {
    const token = getBotToken();
    if (!token) {
      return res.status(400).json({ error: 'TELEGRAM_BOT_TOKEN não configurado' });
    }

    const webhookUrl = req.body.url || `https://estouaqui.rpa4all.com/api/webchat/telegram-webhook`;

    const resp = await axios.post(`${TELEGRAM_API}${token}/setWebhook`, {
      url: webhookUrl,
      secret_token: WEBHOOK_SECRET,
      allowed_updates: ['message'],
    });

    console.log('[webchat] Webhook configured:', webhookUrl);
    console.log('[webchat] Webhook secret:', WEBHOOK_SECRET);
    res.json({
      ok: resp.data.ok,
      description: resp.data.description,
      webhookUrl,
      secret: WEBHOOK_SECRET,
    });
  } catch (error) {
    console.error('[webchat] Setup webhook error:', error.message);
    res.status(500).json({ error: 'Falha ao configurar webhook: ' + error.message });
  }
});

// ─── GET /webhook-info — Verificar status do webhook ───────────────────────────
router.get('/webhook-info', async (req, res) => {
  try {
    const token = getBotToken();
    if (!token) return res.status(400).json({ error: 'Token não configurado' });

    const resp = await axios.get(`${TELEGRAM_API}${token}/getWebhookInfo`);
    res.json(resp.data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
