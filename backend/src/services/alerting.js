/**
 * 🚨 Alert Integration Service
 * Recebe alertas do AlertManager e os distribui para painéis via Socket.io
 * Também publica no bus de comunicação dos agentes
 */

const Logger = require('./logger');
const logger = Logger.instance();

class AlertingService {
  constructor(io) {
    this.io = io;
    this.activeAlerts = new Map();
    this.alertHistory = [];
    this.maxHistorySize = 100;
  }

  /**
   * Processa webhook do AlertManager
   * @param {Object} payload - Payload do AlertManager
   * @returns {Object} Resultado do processamento
   */
  async processAlertManagerWebhook(payload) {
    try {
      logger.info('Processing AlertManager webhook', {
        groupLabels: payload.groupLabels,
        status: payload.status,
        alerts: payload.alerts?.length || 0
      });

      const alerts = payload.alerts || [];
      const timestamp = new Date().toISOString();

      // Processar cada alerta
      const processedAlerts = [];
      for (const alert of alerts) {
        const processedAlert = await this._processAlert(alert, payload, timestamp);
        processedAlerts.push(processedAlert);
      }

      // Broadcast para clientes Socket.io
      this._broadcastAlerts(processedAlerts, payload.status);

      // Tentar publicar no bus de comunicação (se disponível)
      this._publishToBus(processedAlerts, payload);

      return {
        success: true,
        processed: processedAlerts.length,
        alerts: processedAlerts
      };
    } catch (error) {
      logger.error('Error processing AlertManager webhook', {
        error: error.message,
        stack: error.stack
      });
      return { success: false, error: error.message };
    }
  }

  /**
   * Processa um alerta individual
   */
  async _processAlert(alert, groupPayload, timestamp) {
    const alertKey = alert.labels?.alertname || 'Unknown';
    const severity = alert.labels?.severity || 'unknown';
    const instance = alert.labels?.instance || 'unknown';

    const processedAlert = {
      id: `${alertKey}_${timestamp}_${Math.random().toString(36).substr(2, 9)}`,
      name: alertKey,
      status: alert.status,
      severity: severity,
      instance: instance,
      summary: alert.annotations?.summary || alertKey,
      description: alert.annotations?.description || '',
      startsAt: alert.startsAt,
      endsAt: alert.endsAt,
      labels: alert.labels,
      timestamp: timestamp,
      groupLabels: groupPayload.groupLabels
    };

    // Armazenar/atualizar no cache
    if (alert.status === 'firing') {
      this.activeAlerts.set(alertKey, processedAlert);
    } else if (alert.status === 'resolved') {
      this.activeAlerts.delete(alertKey);
    }

    // Adicionar ao histórico
    this.alertHistory.push(processedAlert);
    if (this.alertHistory.length > this.maxHistorySize) {
      this.alertHistory.shift();
    }

    logger.info('Alert processed', {
      alert: alertKey,
      status: alert.status,
      severity: severity
    });

    return processedAlert;
  }

  /**
   * Broadcast de alertas para clientes Socket.io
   */
  _broadcastAlerts(alerts, status) {
    try {
      // Emitir para todos os clientes conectados
      this.io.emit('alerts:update', {
        status: status,
        alerts: alerts,
        activeCount: this.activeAlerts.size,
        timestamp: new Date().toISOString()
      });

      // Emitir eventos específicos por severity
      for (const alert of alerts) {
        if (alert.severity === 'critical') {
          this.io.emit('alert:critical', alert);
        } else if (alert.severity === 'warning') {
          this.io.emit('alert:warning', alert);
        }
      }

      logger.info('Alerts broadcasted to clients', { count: alerts.length });
    } catch (error) {
      logger.error('Error broadcasting alerts', { error: error.message });
    }
  }

  /**
   * Publica alertas no bus de comunicação dos agentes
   */
  _publishToBus(alerts, payload) {
    try {
      // Tenta importar o bus de agentes se disponível
      // Este é um serviço remoto em :8503
      const axios = require('axios');
      const busUrl = process.env.AGENT_BUS_URL || 'http://localhost:8503';

      for (const alert of alerts) {
        const message = {
          message_type: 'ALERT',
          source: 'estou-aqui-backend',
          target: 'monitoring',
          content: `[${alert.severity.toUpperCase()}] ${alert.summary}`,
          metadata: {
            alert_name: alert.name,
            severity: alert.severity,
            instance: alert.instance,
            status: alert.status,
            description: alert.description,
            group_labels: payload.groupLabels
          }
        };

        // Enviar assincronamente sem bloquear
        axios.post(`${busUrl}/communication/publish`, message)
          .then(res => {
            logger.info('Alert published to bus', {
              alert: alert.name,
              messageId: res.data.message_id
            });
          })
          .catch(err => {
            logger.warn('Could not publish to bus', {
              alert: alert.name,
              error: err.message
            });
          });
      }
    } catch (error) {
      logger.warn('Bus integration unavailable (non-blocking)', {
        error: error.message
      });
    }
  }

  /**
   * Retorna alertas ativos
   */
  getActiveAlerts() {
    return Array.from(this.activeAlerts.values());
  }

  /**
   * Retorna histórico de alertas
   */
  getAlertHistory(limit = 50) {
    return this.alertHistory.slice(-limit);
  }

  /**
   * Retorna estatísticas de alertas
   */
  getAlertStats() {
    const active = this.activeAlerts.values();
    const critical = Array.from(active).filter(a => a.severity === 'critical').length;
    const warning = Array.from(active).filter(a => a.severity === 'warning').length;

    return {
      totalActive: this.activeAlerts.size,
      critical,
      warning,
      history: this.alertHistory.length,
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Limpa alertas antigos
   */
  clearOldAlerts(hoursOld = 24) {
    const now = new Date();
    const cutoff = new Date(now.getTime() - hoursOld * 60 * 60 * 1000);

    const initialSize = this.alertHistory.length;
    this.alertHistory = this.alertHistory.filter(alert => {
      return new Date(alert.timestamp) > cutoff;
    });

    const removed = initialSize - this.alertHistory.length;
    logger.info('Old alerts cleared', { removed, remaining: this.alertHistory.length });

    return removed;
  }
}

module.exports = AlertingService;
