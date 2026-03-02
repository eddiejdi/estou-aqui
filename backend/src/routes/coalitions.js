const express = require('express');
const { body, validationResult } = require('express-validator');
const { Op } = require('sequelize');
const { Coalition, Event, User, Checkin, sequelize } = require('../models');
const { auth, optionalAuth } = require('../middleware/auth');

const router = express.Router();

// GET /api/coalitions — Listar coalizões ativas
router.get('/', optionalAuth, async (req, res) => {
  try {
    const { status = 'active', category, page = 1, limit = 20 } = req.query;
    const where = {};
    if (status !== 'all') where.status = status;
    if (category) where.category = category;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await Coalition.findAndCountAll({
      where,
      include: [
        { model: User, as: 'creator', attributes: ['id', 'name', 'avatar'] },
        {
          model: Event,
          as: 'events',
          attributes: ['id', 'title', 'city', 'state', 'status', 'confirmedAttendees', 'latitude', 'longitude', 'startDate'],
        },
      ],
      order: [['totalAttendees', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({
      coalitions: rows,
      pagination: { total: count, page: parseInt(page), pages: Math.ceil(count / parseInt(limit)) },
    });
  } catch (error) {
    console.error('Erro ao listar coalizões:', error);
    res.status(500).json({ error: 'Erro ao buscar coalizões' });
  }
});

// GET /api/coalitions/:id — Detalhes da coalizão com todos os eventos
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const coalition = await Coalition.findByPk(req.params.id, {
      include: [
        { model: User, as: 'creator', attributes: ['id', 'name', 'avatar'] },
        {
          model: Event,
          as: 'events',
          include: [
            { model: User, as: 'organizer', attributes: ['id', 'name', 'avatar'] },
            { model: Checkin, as: 'checkins', attributes: ['id'] },
          ],
          order: [['startDate', 'ASC']],
        },
      ],
    });

    if (!coalition) return res.status(404).json({ error: 'Coalizão não encontrada' });

    // Recalcular totais
    const events = coalition.events || [];
    const totalAttendees = events.reduce((sum, e) => sum + (e.confirmedAttendees || 0), 0);
    const cities = [...new Set(events.map(e => e.city).filter(Boolean))];

    res.json({
      ...coalition.toJSON(),
      totalEvents: events.length,
      totalAttendees,
      totalCities: cities.length,
      cities,
    });
  } catch (error) {
    console.error('Erro ao buscar coalizão:', error);
    res.status(500).json({ error: 'Erro ao buscar coalizão' });
  }
});

// POST /api/coalitions — Criar coalizão
router.post('/', auth, [
  body('name').trim().notEmpty().withMessage('Nome é obrigatório'),
  body('description').trim().notEmpty().withMessage('Descrição é obrigatória'),
  body('hashtag').optional().trim(),
  body('category').optional().isIn([
    'manifestacao', 'protesto', 'marcha', 'ato_publico',
    'assembleia', 'greve', 'ocupacao', 'vigilia', 'outro',
  ]),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  try {
    const coalition = await Coalition.create({
      ...req.body,
      creatorId: req.user.id,
    });
    res.status(201).json(coalition);
  } catch (error) {
    console.error('Erro ao criar coalizão:', error);
    res.status(500).json({ error: 'Erro ao criar coalizão' });
  }
});

// PUT /api/coalitions/:id — Atualizar coalizão
router.put('/:id', auth, async (req, res) => {
  try {
    const coalition = await Coalition.findByPk(req.params.id);
    if (!coalition) return res.status(404).json({ error: 'Coalizão não encontrada' });
    if (coalition.creatorId !== req.user.id) return res.status(403).json({ error: 'Não autorizado' });

    await coalition.update(req.body);
    res.json(coalition);
  } catch (error) {
    console.error('Erro ao atualizar coalizão:', error);
    res.status(500).json({ error: 'Erro ao atualizar coalizão' });
  }
});

// POST /api/coalitions/:id/join — Vincular evento a uma coalizão
router.post('/:id/join', auth, async (req, res) => {
  try {
    const { eventId } = req.body;
    if (!eventId) return res.status(400).json({ error: 'eventId é obrigatório' });

    const coalition = await Coalition.findByPk(req.params.id);
    if (!coalition) return res.status(404).json({ error: 'Coalizão não encontrada' });

    const event = await Event.findByPk(eventId);
    if (!event) return res.status(404).json({ error: 'Evento não encontrado' });
    if (event.organizerId !== req.user.id) return res.status(403).json({ error: 'Apenas o organizador pode vincular o evento' });

    await event.update({ coalitionId: coalition.id });

    // Recalcular totais
    const allEvents = await Event.findAll({ where: { coalitionId: coalition.id } });
    const totalAttendees = allEvents.reduce((sum, e) => sum + (e.confirmedAttendees || 0), 0);
    const cities = [...new Set(allEvents.map(e => e.city).filter(Boolean))];
    await coalition.update({
      totalEvents: allEvents.length,
      totalAttendees,
      totalCities: cities.length,
    });

    res.json({ success: true, message: 'Evento vinculado à coalizão', coalition });
  } catch (error) {
    console.error('Erro ao vincular evento:', error);
    res.status(500).json({ error: 'Erro ao vincular evento' });
  }
});

// GET /api/coalitions/:id/stats — Estatísticas agregadas da coalizão
router.get('/:id/stats', optionalAuth, async (req, res) => {
  try {
    const coalition = await Coalition.findByPk(req.params.id, {
      include: [{
        model: Event,
        as: 'events',
        attributes: ['id', 'title', 'city', 'state', 'status', 'confirmedAttendees', 'estimatedAttendees', 'startDate', 'category'],
      }],
    });

    if (!coalition) return res.status(404).json({ error: 'Coalizão não encontrada' });

    const events = coalition.events || [];
    const activeEvents = events.filter(e => e.status === 'active');
    const endedEvents = events.filter(e => e.status === 'ended');
    const cities = [...new Set(events.map(e => e.city).filter(Boolean))];
    const states = [...new Set(events.map(e => e.state).filter(Boolean))];
    const totalConfirmed = events.reduce((s, e) => s + (e.confirmedAttendees || 0), 0);
    const totalEstimated = events.reduce((s, e) => s + (e.estimatedAttendees || 0), 0);

    // Timeline: agrupar por data
    const byDate = {};
    events.forEach(e => {
      const day = e.startDate.toISOString().split('T')[0];
      byDate[day] = (byDate[day] || 0) + 1;
    });

    res.json({
      coalitionId: coalition.id,
      name: coalition.name,
      totalEvents: events.length,
      activeEvents: activeEvents.length,
      endedEvents: endedEvents.length,
      totalConfirmedAttendees: totalConfirmed,
      totalEstimatedAttendees: totalEstimated,
      totalCities: cities.length,
      totalStates: states.length,
      cities,
      states,
      timeline: Object.entries(byDate).sort().map(([date, count]) => ({ date, events: count })),
    });
  } catch (error) {
    console.error('Erro ao buscar stats:', error);
    res.status(500).json({ error: 'Erro ao buscar estatísticas' });
  }
});

module.exports = router;
