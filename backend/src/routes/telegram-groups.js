const express = require('express');
const { auth } = require('../middleware/auth');
const TelegramGroupService = require('../services/telegramGroup');
const models = require('../models');

const router = express.Router();
const telegramService = new TelegramGroupService(models);

/**
 * POST /api/telegram-groups/:eventId/join
 * Obtém ou cria grupo Telegram para o evento.
 * Se o grupo não existe, cria. Se está lotado, cria versão nova.
 */
router.post('/:eventId/join', auth, async (req, res) => {
  try {
    const result = await telegramService.getOrCreateGroup(
      req.params.eventId,
      req.userId,
    );

    res.json({
      success: true,
      group: result,
      message: result.isNew
        ? 'Grupo criado! Use o link para entrar.'
        : 'Grupo encontrado! Use o link para entrar.',
    });
  } catch (error) {
    console.error('Erro ao obter/criar grupo Telegram:', error);

    // Se o Bot API não suporta criação direta, retornar fallback
    if (error.message.includes('não suporta criação direta')) {
      return res.status(501).json({
        success: false,
        error: 'Criação automática de grupos ainda não disponível. ' +
          'O organizador precisa criar o grupo manualmente e vinculá-lo.',
        needsManualSetup: true,
      });
    }

    res.status(500).json({
      success: false,
      error: 'Erro ao processar grupo do Telegram',
    });
  }
});

/**
 * GET /api/telegram-groups/:eventId
 * Lista todos os grupos Telegram de um evento (incluindo versionados)
 */
router.get('/:eventId', auth, async (req, res) => {
  try {
    const groups = await telegramService.listGroups(req.params.eventId);

    res.json({
      success: true,
      groups,
      count: groups.length,
    });
  } catch (error) {
    console.error('Erro ao listar grupos:', error);
    res.status(500).json({ success: false, error: 'Erro ao listar grupos' });
  }
});

/**
 * POST /api/telegram-groups/:eventId/link
 * Organizador vincula manualmente um grupo Telegram existente ao evento.
 * Body: { chatId, inviteLink }
 */
router.post('/:eventId/link', auth, async (req, res) => {
  try {
    const { Event, TelegramGroup } = models;
    const event = await Event.findByPk(req.params.eventId);

    if (!event) {
      return res.status(404).json({ success: false, error: 'Evento não encontrado' });
    }

    // Apenas organizador ou admin pode vincular
    if (event.organizerId !== req.userId) {
      return res.status(403).json({ success: false, error: 'Apenas o organizador pode vincular grupos' });
    }

    const { chatId, inviteLink } = req.body;
    if (!inviteLink) {
      return res.status(400).json({ success: false, error: 'inviteLink é obrigatório' });
    }

    // Verificar versão existente
    const existingCount = await TelegramGroup.count({
      where: { eventId: req.params.eventId, isActive: true },
    });

    const group = await TelegramGroup.create({
      eventId: req.params.eventId,
      chatId: chatId || BigInt(Date.now()) * BigInt(-1), // placeholder se não informado
      inviteLink,
      title: `${event.title}${existingCount > 0 ? ` #${existingCount + 1}` : ''}`,
      version: existingCount + 1,
    });

    // Se chatId real fornecido, tentar obter contagem de membros
    if (chatId) {
      try {
        const memberCount = await telegramService._getMemberCount(chatId);
        await group.update({ memberCount });
      } catch (_) {
        // Ignora erro — talvez o bot não esteja no grupo
      }
    }

    res.status(201).json({
      success: true,
      group: {
        id: group.id,
        chatId: group.chatId.toString(),
        inviteLink: group.inviteLink,
        title: group.title,
        version: group.version,
        memberCount: group.memberCount,
      },
    });
  } catch (error) {
    console.error('Erro ao vincular grupo:', error);
    res.status(500).json({ success: false, error: 'Erro ao vincular grupo' });
  }
});

module.exports = router;
