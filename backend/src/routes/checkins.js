const express = require('express');
const { body, validationResult } = require('express-validator');
const { Checkin, Event, User } = require('../models');
const { auth } = require('../middleware/auth');
const CrowdEstimationService = require('../services/crowdEstimation');

const router = express.Router();

// POST /api/checkins — Fazer check-in em um evento
router.post('/', auth, [
  body('eventId').isUUID(),
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { eventId, latitude, longitude } = req.body;

    const event = await Event.findByPk(eventId);
    if (!event) return res.status(404).json({ error: 'Evento não encontrado' });
    if (event.status === 'cancelled' || event.status === 'ended') {
      return res.status(400).json({ error: 'Evento não está ativo ou agendado' });
    }

    // Verificar se já fez check-in
    const existing = await Checkin.findOne({
      where: { userId: req.userId, eventId, isActive: true },
    });
    if (existing) {
      return res.status(409).json({ error: 'Você já fez check-in neste evento' });
    }

    const checkin = await Checkin.create({
      userId: req.userId,
      eventId,
      latitude,
      longitude,
    });

    // Atualizar contagem de participantes
    const activeCount = await Checkin.count({ where: { eventId, isActive: true } });
    await event.update({ confirmedAttendees: activeCount });

    // Recalcular estimativa de público
    const estimate = await CrowdEstimationService.estimate(event);

    // Notificar via Socket.IO
    const io = req.app.get('io');
    io.to(`event:${eventId}`).emit('checkin:new', {
      eventId,
      activeCheckins: activeCount,
      estimatedAttendees: estimate.estimatedCount,
    });

    res.status(201).json({ checkin, activeCheckins: activeCount, estimate });
  } catch (error) {
    console.error('Erro no check-in:', error);
    res.status(500).json({ error: 'Erro ao fazer check-in' });
  }
});

// DELETE /api/checkins/:eventId — Check-out de um evento
router.delete('/:eventId', auth, async (req, res) => {
  try {
    const checkin = await Checkin.findOne({
      where: { userId: req.userId, eventId: req.params.eventId, isActive: true },
    });

    if (!checkin) {
      return res.status(404).json({ error: 'Check-in não encontrado' });
    }

    await checkin.update({ isActive: false, checkedOutAt: new Date() });

    const activeCount = await Checkin.count({
      where: { eventId: req.params.eventId, isActive: true },
    });

    const event = await Event.findByPk(req.params.eventId);
    await event.update({ confirmedAttendees: activeCount });

    const io = req.app.get('io');
    io.to(`event:${req.params.eventId}`).emit('checkout', {
      eventId: req.params.eventId,
      activeCheckins: activeCount,
    });

    res.json({ message: 'Check-out realizado', activeCheckins: activeCount });
  } catch (error) {
    console.error('Erro no check-out:', error);
    res.status(500).json({ error: 'Erro ao fazer check-out' });
  }
});

// GET /api/checkins/event/:eventId — Listar check-ins de um evento
router.get('/event/:eventId', async (req, res) => {
  try {
    const checkins = await Checkin.findAll({
      where: { eventId: req.params.eventId, isActive: true },
      include: [{ model: User, as: 'user', attributes: ['id', 'name', 'avatar'] }],
      order: [['createdAt', 'DESC']],
    });

    res.json({ checkins, total: checkins.length });
  } catch (error) {
    console.error('Erro ao listar check-ins:', error);
    res.status(500).json({ error: 'Erro ao buscar check-ins' });
  }
});

// GET /api/checkins/me — Meus check-ins ativos
router.get('/me', auth, async (req, res) => {
  try {
    const checkins = await Checkin.findAll({
      where: { userId: req.userId, isActive: true },
      include: [{ model: Event, as: 'event' }],
      order: [['createdAt', 'DESC']],
    });

    res.json({ checkins });
  } catch (error) {
    console.error('Erro ao buscar meus check-ins:', error);
    res.status(500).json({ error: 'Erro ao buscar check-ins' });
  }
});

module.exports = router;
