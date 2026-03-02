const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { Op } = require('sequelize');
const { Event, User, Checkin, Coalition } = require('../models');
const { auth, optionalAuth } = require('../middleware/auth');

const router = express.Router();

// GET /api/events — Listar eventos (com filtros)
router.get('/', optionalAuth, async (req, res) => {
  try {
    const {
      lat, lng, radius = 50, // km
      status, category, city,
      page = 1, limit = 20,
    } = req.query;

    const where = {};
    if (status) where.status = status;
    if (category) where.category = category;
    if (city) where.city = { [Op.iLike]: `%${city}%` };

    // Filtro por proximidade (simplificado — para produção usar PostGIS)
    if (lat && lng) {
      const radiusDeg = parseFloat(radius) / 111; // ~111 km por grau
      where.latitude = { [Op.between]: [parseFloat(lat) - radiusDeg, parseFloat(lat) + radiusDeg] };
      where.longitude = { [Op.between]: [parseFloat(lng) - radiusDeg, parseFloat(lng) + radiusDeg] };
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await Event.findAndCountAll({
      where,
      include: [{ model: User, as: 'organizer', attributes: ['id', 'name', 'avatar'] }],
      order: [['startDate', 'ASC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({
      events: rows,
      pagination: {
        total: count,
        page: parseInt(page),
        pages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Erro ao listar eventos:', error);
    res.status(500).json({ error: 'Erro ao buscar eventos' });
  }
});

// GET /api/events/:id
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.id, {
      include: [
        { model: User, as: 'organizer', attributes: ['id', 'name', 'avatar'] },
        { model: Checkin, as: 'checkins', where: { isActive: true }, required: false },
        { model: Coalition, as: 'coalition', attributes: ['id', 'name', 'hashtag', 'totalEvents', 'totalAttendees', 'totalCities'], required: false },
      ],
    });

    if (!event) {
      return res.status(404).json({ error: 'Evento não encontrado' });
    }

    res.json({ event });
  } catch (error) {
    console.error('Erro ao buscar evento:', error);
    res.status(500).json({ error: 'Erro ao buscar evento' });
  }
});

// POST /api/events
router.post('/', auth, [
  body('title').trim().isLength({ min: 3, max: 200 }),
  body('description').trim().isLength({ min: 10 }),
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
  body('startDate').isISO8601(),
  body('category').optional().isIn([
    'manifestacao', 'protesto', 'marcha', 'ato_publico',
    'assembleia', 'greve', 'ocupacao', 'vigilia', 'outro',
  ]),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const event = await Event.create({
      ...req.body,
      organizerId: req.userId,
      status: 'scheduled',
    });

    res.status(201).json({ event });
  } catch (error) {
    console.error('Erro ao criar evento:', error);
    res.status(500).json({ error: 'Erro ao criar evento' });
  }
});

// PUT /api/events/:id
router.put('/:id', auth, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ error: 'Evento não encontrado' });
    if (event.organizerId !== req.userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    await event.update(req.body);
    res.json({ event });
  } catch (error) {
    console.error('Erro ao atualizar evento:', error);
    res.status(500).json({ error: 'Erro ao atualizar evento' });
  }
});

// PUT /api/events/:id/status
router.put('/:id/status', auth, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ error: 'Evento não encontrado' });
    if (event.organizerId !== req.userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    const { status } = req.body;
    if (!['scheduled', 'active', 'ended', 'cancelled'].includes(status)) {
      return res.status(400).json({ error: 'Status inválido' });
    }

    await event.update({ status });

    // Notificar via Socket.IO
    const io = req.app.get('io');
    io.to(`event:${event.id}`).emit('event:status', { eventId: event.id, status });

    res.json({ event });
  } catch (error) {
    console.error('Erro ao atualizar status:', error);
    res.status(500).json({ error: 'Erro ao atualizar status' });
  }
});

module.exports = router;
