/**
 * Token Tracking Middleware
 * Rastreia automaticamente o uso de tokens em operações LLM
 */

const tokenMetrics = require('../services/token_metrics');

/**
 * Middleware para registrar uso de tokens
 * Espera um objeto res.locals.tokenUsage com dados de tokens
 */
const trackTokenMiddleware = (req, res, next) => {
  const originalSend = res.send;

  res.send = function (data) {
    // Se houver dados de token no locals, registrar
    if (res.locals.tokenUsage) {
      tokenMetrics.recordTokenUsage(res.locals.tokenUsage);
    }

    return originalSend.call(this, data);
  };

  next();
};

/**
 * Helper para registrar tokens em rotas específicas
 * Uso: res.locals.tokenUsage = { prompt_tokens: 50, completion_tokens: 100, model: 'qwen3:4b' }
 */
const recordTokens = (res, promptTokens, completionTokens, model = 'unknown', error = false) => {
  res.locals.tokenUsage = {
    prompt_tokens: promptTokens,
    completion_tokens: completionTokens,
    model,
    error,
  };
};

module.exports = {
  trackTokenMiddleware,
  recordTokens,
};
