/**
 * Bus Integration Service
 * Conecta ao Communication Bus do homelab para compartilhar métricas
 */

const axios = require('axios');

class BusIntegrationService {
  constructor() {
    this.busUrl = process.env.HOMELAB_BUS_URL || 'http://192.168.15.2:8503';
    this.serviceName = 'estou-aqui-backend';
    this.connected = false;
  }

  /**
   * Inicializa conexão com o bus
   */
  async connect() {
    try {
      const response = await axios.get(`${this.busUrl}/health`, {
        timeout: 5000,
      });
      if (response.status === 200) {
        this.connected = true;
        console.log(`[BusIntegration] Conectado ao bus: ${this.busUrl}`);
        return true;
      }
    } catch (error) {
      console.warn(`[BusIntegration] Falha ao conectar ao bus: ${error.message}`);
      this.connected = false;
      return false;
    }
  }

  /**
   * Publica mensagem no bus
   */
  async publish(messageData) {
    if (!this.connected) {
      return null;
    }

    try {
      const payload = {
        message_type: messageData.message_type || 'event',
        source: messageData.source || this.serviceName,
        target: messageData.target || 'coordinator',
        content: typeof messageData.content === 'string' 
          ? messageData.content 
          : JSON.stringify(messageData.content),
        metadata: messageData.metadata || {},
      };

      const response = await axios.post(
        `${this.busUrl}/communication/publish`,
        payload,
        { timeout: 5000 }
      );

      return response.data;
    } catch (error) {
      console.error('[BusIntegration] Erro ao publicar:', error.message);
      // Não falha a operação se o bus estiver indisponível
      return null;
    }
  }

  /**
   * Anuncia presença do serviço no bus (heartbeat)
   */
  async announcePresence(capabilities = []) {
    const content = {
      type: 'service_online',
      service: this.serviceName,
      version: '1.0.0',
      capabilities: [
        'token_tracking',
        'llm_metrics',
        'chat_api',
        'event_management',
        ...capabilities,
      ],
      timestamp: new Date().toISOString(),
    };

    return this.publish({
      message_type: 'response',
      source: this.serviceName,
      target: 'coordinator',
      content,
      metadata: {
        service_type: 'backend-api',
        heartbeat: true,
      },
    });
  }

  /**
   * Registra uma métrica no bus
   */
  async recordMetric(metricType, value, tags = {}) {
    return this.publish({
      message_type: 'metric',
      source: this.serviceName,
      target: 'metrics-aggregator',
      content: {
        metric_type: metricType,
        value,
        timestamp: new Date().toISOString(),
        tags,
      },
    });
  }

  /**
   * Reporta erro para o bus
   */
  async reportError(error, context = {}) {
    return this.publish({
      message_type: 'event',
      source: this.serviceName,
      target: 'error-handler',
      content: {
        type: 'error',
        message: error.message,
        stack: error.stack,
        context,
        timestamp: new Date().toISOString(),
      },
      metadata: {
        severity: 'error',
      },
    });
  }

  /**
   * Verifica status de conexão
   */
  isConnected() {
    return this.connected;
  }
}

module.exports = new BusIntegrationService();
