/**
 * 🚨 Alert Routes
 * Endpoints para receber webhooks de AlertManager e gerenciar alertas
 */

const express = require('express');
const router = express.Router();
const Logger = require('../services/logger');

const logger = Logger.instance();

// ============================================================================
// FACTORY: AlertingService é inicializado dinamicamente no servidor
// ============================================================================
const getAlertingService = (req) => {
  // O io é passado via app.set('io', io) no server.js
  // E temos uma referência global na req.app
  if (!req.app.alertingService) {
    const AlertingService = require('../services/alerting');
    req.app.alertingService = new AlertingService(req.app.get('io'));
  }
  return req.app.alertingService;
};

/**
 * POST /api/alerts/webhook
 * Recebe webhooks do AlertManager
 */
router.post('/webhook', async (req, res) => {
  try {
    const alertingService = getAlertingService(req);
    const payload = req.body;

    logger.info('Received AlertManager webhook', {
      groupLabels: payload.groupLabels,
      numberOfAlerts: payload.alerts?.length || 0
    });

    // Processar webhook
    const result = await alertingService.processAlertManagerWebhook(payload);

    // Responder ao AlertManager (importante para marcar entrega)
    res.status(200).json({
      status: 'received',
      processed: result.processed,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error handling alert webhook', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/alerts/active
 * Retorna alertas ativos no momento
 */
router.get('/active', (req, res) => {
  try {
    const alertingService = getAlertingService(req);
    const active = alertingService.getActiveAlerts();

    res.json({
      status: 'success',
      alerts: active,
      count: active.length,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error fetching active alerts', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/alerts/history
 * Retorna histórico de alertas (últimos N)
 */
router.get('/history', (req, res) => {
  try {
    const alertingService = getAlertingService(req);
    const limit = parseInt(req.query.limit) || 50;
    const history = alertingService.getAlertHistory(limit);

    res.json({
      status: 'success',
      alerts: history,
      count: history.length,
      limit: limit,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error fetching alert history', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/alerts/stats
 * Retorna estatísticas de alertas
 */
router.get('/stats', (req, res) => {
  try {
    const alertingService = getAlertingService(req);
    const stats = alertingService.getAlertStats();

    res.json({
      status: 'success',
      stats: stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error fetching alert stats', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

/**
 * DELETE /api/alerts/clear
 * Limpa alertas antigos
 */
router.delete('/clear', (req, res) => {
  try {
    const alertingService = getAlertingService(req);
    const hoursOld = parseInt(req.query.hours) || 24;
    const removed = alertingService.clearOldAlerts(hoursOld);

    res.json({
      status: 'success',
      removed: removed,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error clearing alerts', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
