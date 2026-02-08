const express = require('express');
const { Notification } = require('../models');
const { auth } = require('../middleware/auth');

const router = express.Router();

// GET /api/notifications — Listar notificações do usuário
router.get('/', auth, async (req, res) => {
  try {
    const { page = 1, limit = 30, unreadOnly } = req.query;
    const where = { userId: req.userId };
    if (unreadOnly === 'true') where.isRead = false;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await Notification.findAndCountAll({
      where,
      order: [['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    const unreadCount = await Notification.count({ where: { userId: req.userId, isRead: false } });

    res.json({
      notifications: rows,
      unreadCount,
      pagination: { total: count, page: parseInt(page), pages: Math.ceil(count / parseInt(limit)) },
    });
  } catch (error) {
    console.error('Erro ao buscar notificações:', error);
    res.status(500).json({ error: 'Erro ao buscar notificações' });
  }
});

// PUT /api/notifications/:id/read
router.put('/:id/read', auth, async (req, res) => {
  try {
    const notification = await Notification.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!notification) return res.status(404).json({ error: 'Notificação não encontrada' });

    await notification.update({ isRead: true });
    res.json({ message: 'Notificação marcada como lida' });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao marcar notificação' });
  }
});

// PUT /api/notifications/read-all
router.put('/read-all', auth, async (req, res) => {
  try {
    await Notification.update(
      { isRead: true },
      { where: { userId: req.userId, isRead: false } },
    );
    res.json({ message: 'Todas as notificações marcadas como lidas' });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao marcar notificações' });
  }
});

module.exports = router;
