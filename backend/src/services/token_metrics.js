/**
 * Token Metrics Service
 * Rastreia e publica o uso de tokens como o Ollama faz
 */

class TokenMetricsService {
  constructor() {
    this.metrics = {
      total_tokens: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      requests: 0,
      errors: 0,
      last_request: null,
      models_used: {},
      timestamps: [],
    };
    this.busPublisher = null;
  }

  /**
   * Set bus publisher (Communication Bus)
   */
  setBusPublisher(publisher) {
    this.busPublisher = publisher;
  }

  /**
   * Registra uso de tokens (chamada por LLM/API)
   */
  recordTokenUsage(data) {
    const {
      prompt_tokens = 0,
      completion_tokens = 0,
      model = 'unknown',
      error = false,
    } = data;

    const total = prompt_tokens + completion_tokens;

    // Atualiza métricas
    this.metrics.total_tokens += total;
    this.metrics.prompt_tokens += prompt_tokens;
    this.metrics.completion_tokens += completion_tokens;
    this.metrics.requests += 1;
    if (error) this.metrics.errors += 1;

    // Registra modelo usado
    if (!this.metrics.models_used[model]) {
      this.metrics.models_used[model] = { count: 0, tokens: 0 };
    }
    this.metrics.models_used[model].count += 1;
    this.metrics.models_used[model].tokens += total;

    // Timestamp
    this.metrics.last_request = new Date().toISOString();
    this.metrics.timestamps.push({
      time: this.metrics.last_request,
      prompt_tokens,
      completion_tokens,
      total_tokens: total,
      model,
    });

    // Manter últimos 100 timestamps
    if (this.metrics.timestamps.length > 100) {
      this.metrics.timestamps.shift();
    }

    // Log local
    console.log(
      `[TokenMetrics] ${model} - P:${prompt_tokens} C:${completion_tokens} T:${total}`
    );

    // Publicar no bus se disponível
    if (this.busPublisher) {
      this.publishToBus(data);
    }

    return this.metrics;
  }

  /**
   * Publica métricas no Communication Bus (similar ao Ollama)
   */
  publishToBus(event) {
    if (!this.busPublisher) return;

    try {
      this.busPublisher({
        message_type: 'event',
        source: 'estou-aqui-backend',
        target: 'metrics-aggregator',
        content: JSON.stringify({
          event_type: 'token_usage',
          metrics: {
            total_tokens: this.metrics.total_tokens,
            prompt_tokens: this.metrics.prompt_tokens,
            completion_tokens: this.metrics.completion_tokens,
            requests_total: this.metrics.requests,
            errors_total: this.metrics.errors,
            latest: event,
          },
          timestamp: new Date().toISOString(),
          service: 'estou-aqui-backend',
        }),
        metadata: {
          metric_type: 'token_usage',
          aggregated: true,
        },
      });
    } catch (error) {
      console.error('[TokenMetrics] Erro ao publicar no bus:', error);
    }
  }

  /**
   * Retorna métricas atuais
   */
  getMetrics() {
    return {
      ...this.metrics,
      uptime_seconds: process.uptime(),
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Retorna métricas em formato Ollama-compatible
   */
  getOllamaFormat() {
    return {
      models: Object.entries(this.metrics.models_used).map(([model, data]) => ({
        name: model,
        size: 0,
        digest: '',
        modified_at: new Date().toISOString(),
        token_count: data.tokens,
        request_count: data.count,
      })),
      total_tokens: this.metrics.total_tokens,
      total_requests: this.metrics.requests,
      total_errors: this.metrics.errors,
    };
  }

  /**
   * Reset de métricas
   */
  reset() {
    this.metrics = {
      total_tokens: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      requests: 0,
      errors: 0,
      last_request: null,
      models_used: {},
      timestamps: [],
    };
  }
}

module.exports = new TokenMetricsService();
