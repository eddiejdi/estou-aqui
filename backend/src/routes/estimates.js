const express = require('express');
const { CrowdEstimate, Event, Checkin } = require('../models');
const { auth } = require('../middleware/auth');
const CrowdEstimationService = require('../services/crowdEstimation');

const router = express.Router();

// GET /api/estimates/:eventId — Obter estimativas de um evento
router.get('/:eventId', async (req, res) => {
  try {
    const estimates = await CrowdEstimate.findAll({
      where: { eventId: req.params.eventId },
      order: [['createdAt', 'DESC']],
      limit: 20,
    });

    const event = await Event.findByPk(req.params.eventId);
    const activeCheckins = await Checkin.count({
      where: { eventId: req.params.eventId, isActive: true },
    });

    res.json({
      currentEstimate: event?.estimatedAttendees || 0,
      confirmedCheckins: activeCheckins,
      history: estimates,
    });
  } catch (error) {
    console.error('Erro ao buscar estimativas:', error);
    res.status(500).json({ error: 'Erro ao buscar estimativas' });
  }
});

// POST /api/estimates/:eventId/calculate — Forçar recálculo
router.post('/:eventId/calculate', auth, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.eventId);
    if (!event) return res.status(404).json({ error: 'Evento não encontrado' });

    const { areaSquareMeters, densityLevel } = req.body;

    if (areaSquareMeters) {
      await event.update({ areaSquareMeters });
    }

    const estimate = await CrowdEstimationService.estimate(event, { densityLevel });

    // Notificar via Socket.IO
    const io = req.app.get('io');
    io.to(`event:${event.id}`).emit('estimate:updated', {
      eventId: event.id,
      estimatedAttendees: estimate.estimatedCount,
      method: estimate.method,
      confidence: estimate.confidence,
    });

    res.json({ estimate });
  } catch (error) {
    console.error('Erro ao calcular estimativa:', error);
    res.status(500).json({ error: 'Erro ao calcular estimativa' });
  }
});

// POST /api/estimates/:eventId/manual — Estimativa manual (verificador)
router.post('/:eventId/manual', auth, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.eventId);
    if (!event) return res.status(404).json({ error: 'Evento não encontrado' });

    const { estimatedCount, notes } = req.body;
    if (!estimatedCount || estimatedCount < 0) {
      return res.status(400).json({ error: 'Estimativa inválida' });
    }

    const estimate = await CrowdEstimate.create({
      eventId: event.id,
      method: 'manual',
      estimatedCount,
      confidence: 0.7,
      notes,
    });

    await event.update({ estimatedAttendees: estimatedCount });

    res.status(201).json({ estimate });
  } catch (error) {
    console.error('Erro na estimativa manual:', error);
    res.status(500).json({ error: 'Erro ao registrar estimativa' });
  }
});

module.exports = router;
