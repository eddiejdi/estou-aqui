const express = require('express');
const { body, validationResult } = require('express-validator');
const { ChatMessage, User } = require('../models');
const { auth } = require('../middleware/auth');

const router = express.Router();

// GET /api/chat/:eventId — Buscar mensagens de um evento
router.get('/:eventId', auth, async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await ChatMessage.findAndCountAll({
      where: { eventId: req.params.eventId, isDeleted: false },
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'avatar'] }],
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({
      messages: rows.reverse(),
      pagination: {
        total: count,
        page: parseInt(page),
        pages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Erro ao buscar mensagens:', error);
    res.status(500).json({ error: 'Erro ao buscar mensagens' });
  }
});

// POST /api/chat/:eventId — Enviar mensagem
router.post('/:eventId', auth, [
  body('content').trim().isLength({ min: 1, max: 2000 }),
  body('type').optional().isIn(['text', 'image', 'location', 'alert']),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const message = await ChatMessage.create({
      userId: req.userId,
      eventId: req.params.eventId,
      content: req.body.content,
      type: req.body.type || 'text',
    });

    const fullMessage = await ChatMessage.findByPk(message.id, {
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'avatar'] }],
    });

    // Emitir via Socket.IO
    const io = req.app.get('io');
    io.to(`event:${req.params.eventId}`).emit('chat:message', fullMessage);

    res.status(201).json({ message: fullMessage });
  } catch (error) {
    console.error('Erro ao enviar mensagem:', error);
    res.status(500).json({ error: 'Erro ao enviar mensagem' });
  }
});

// DELETE /api/chat/message/:id — Deletar mensagem (soft delete)
router.delete('/message/:id', auth, async (req, res) => {
  try {
    const message = await ChatMessage.findByPk(req.params.id);
    if (!message) return res.status(404).json({ error: 'Mensagem não encontrada' });
    if (message.userId !== req.userId) {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    await message.update({ isDeleted: true });
    res.json({ message: 'Mensagem removida' });
  } catch (error) {
    console.error('Erro ao deletar mensagem:', error);
    res.status(500).json({ error: 'Erro ao deletar mensagem' });
  }
});

module.exports = router;
