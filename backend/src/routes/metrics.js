/**
 * Metrics Routes
 * Expõe as métricas de tokens de forma similar ao Ollama
 */

const express = require('express');
const tokenMetrics = require('../services/token_metrics');

const router = express.Router();

/**
 * GET /api/metrics
 * Retorna todas as métricas em formato JSON
 */
router.get('/', (req, res) => {
  const metrics = tokenMetrics.getMetrics();
  res.json({
    status: 'ok',
    service: 'estou-aqui-backend',
    metrics,
  });
});

/**
 * GET /api/metrics/tokens
 * Retorna apenas métricas de tokens (compatível com Ollama)
 */
router.get('/tokens', (req, res) => {
  const metrics = tokenMetrics.getMetrics();
  res.json({
    total_tokens: metrics.total_tokens,
    prompt_tokens: metrics.prompt_tokens,
    completion_tokens: metrics.completion_tokens,
    total_requests: metrics.requests,
    total_errors: metrics.errors,
    models: metrics.models_used,
    last_request: metrics.last_request,
  });
});

/**
 * GET /api/metrics/ollama
 * Retorna métricas em formato compatível com Ollama
 */
router.get('/ollama', (req, res) => {
  const ollama_format = tokenMetrics.getOllamaFormat();
  res.json(ollama_format);
});

/**
 * GET /api/metrics/history
 * Retorna histórico de últimas requisições
 */
router.get('/history', (req, res) => {
  const metrics = tokenMetrics.getMetrics();
  const limit = parseInt(req.query.limit) || 20;
  res.json({
    total: metrics.timestamps.length,
    limit,
    data: metrics.timestamps.slice(-limit),
  });
});

/**
 * POST /api/metrics/record
 * Registra manualmente uma métrica (para integração com serviços externos)
 */
router.post('/record', (req, res) => {
  try {
    const { prompt_tokens, completion_tokens, model, error } = req.body;

    if (prompt_tokens === undefined && completion_tokens === undefined) {
      return res.status(400).json({
        error: 'Faltam prompt_tokens ou completion_tokens',
      });
    }

    const metrics = tokenMetrics.recordTokenUsage({
      prompt_tokens: prompt_tokens || 0,
      completion_tokens: completion_tokens || 0,
      model: model || 'manual',
      error: error || false,
    });

    res.json({
      status: 'recorded',
      metrics,
    });
  } catch (error) {
    res.status(500).json({
      error: error.message,
    });
  }
});

/**
 * POST /api/metrics/reset
 * Reseta todas as métricas
 */
router.post('/reset', (req, res) => {
  tokenMetrics.reset();
  res.json({
    status: 'reset',
    message: 'Todas as métricas foram resetadas',
  });
});

/**
 * GET /api/metrics/status
 * Retorna status geral das métricas
 */
router.get('/status', (req, res) => {
  const metrics = tokenMetrics.getMetrics();
  const avgTokensPerRequest = metrics.requests > 0 
    ? Math.round(metrics.total_tokens / metrics.requests) 
    : 0;

  res.json({
    service: 'estou-aqui-backend',
    status: 'ok',
    uptime: `${Math.round(metrics.uptime_seconds)}s`,
    summary: {
      total_tokens: metrics.total_tokens,
      total_requests: metrics.requests,
      total_errors: metrics.errors,
      avg_tokens_per_request: avgTokensPerRequest,
      error_rate: metrics.requests > 0 
        ? ((metrics.errors / metrics.requests) * 100).toFixed(2) + '%'
        : '0%',
    },
    models: Object.entries(metrics.models_used).map(([model, data]) => ({
      name: model,
      requests: data.count,
      tokens: data.tokens,
      avg: Math.round(data.tokens / data.count),
    })),
    last_request: metrics.last_request,
    timestamp: metrics.timestamp,
  });
});

module.exports = router;
