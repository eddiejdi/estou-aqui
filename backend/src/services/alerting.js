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
   * Processa payloads enviados pelo Grafana Alerting (webhook)
   * Mapeia o payload do Grafana para o formato interno e publica no bus
   */
  async processGrafanaWebhook(payload) {
    try {
      logger.info('Processing Grafana webhook', { rule: payload.ruleName || payload.title, state: payload.state });

      const state = payload.state || (payload.evalMatches && payload.evalMatches.length ? 'alerting' : 'ok');
      const timestamp = new Date().toISOString();

      // Construir um alerta interno a partir do payload do Grafana
      const alertName = payload.ruleName || payload.title || 'grafana_alert';
      const summary = payload.title || payload.ruleName || '';
      const description = payload.message || '';
      const tags = payload.tags || {};

      // Criar um objeto que imite o formato do AlertManager para reaproveitar _processAlert
      const fakeAlert = {
        status: state === 'alerting' ? 'firing' : 'resolved',
        labels: Object.assign({}, tags, { alertname: alertName, instance: (payload.evalMatches && payload.evalMatches[0] && payload.evalMatches[0].tags && payload.evalMatches[0].tags.instance) || 'grafana' }),
        annotations: {
          summary,
          description
        },
        startsAt: timestamp,
        endsAt: null
      };

      const processed = await this._processAlert(fakeAlert, { groupLabels: {} }, timestamp);

      // Broadcast + publish
      this._broadcastAlerts([processed], state);
      this._publishToBus([processed], { source: 'grafana', state, payload });

      return { success: true, processed: 1, alert: processed };
    } catch (error) {
      logger.error('Error processing Grafana webhook', { error: error.message, stack: error.stack });
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
      const configured = process.env.AGENT_BUS_URL && process.env.AGENT_BUS_URL.trim();
      // Try common endpoints (container host-gateway first, then localhost)
      const candidates = [];
      if (configured) candidates.push(configured);
      candidates.push('http://172.17.0.1:8503');
      candidates.push('http://127.0.0.1:8503');

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

        // Tenta publicar no primeiro endpoint disponível (não bloqueante)
        (async () => {
          let published = false;
          for (const base of candidates) {
            try {
              const res = await axios.post(`${base}/communication/publish`, message, { timeout: 3000 });

              // Increment metric on successful publish (non-blocking)
              try {
                if (alertsPublishedCounter) {
                  alertsPublishedCounter.inc({ source: message.source || 'estou-aqui-backend', severity: alert.severity || 'unknown' }, 1);
                }
              } catch (mErr) {
                logger.warn('Could not update alerts_published metric', { error: mErr.message });
              }

              logger.info('Alert published to bus', {
                alert: alert.name,
                via: base,
                messageId: res.data && res.data.message_id
              });

              published = true;
              break;
            } catch (err) {
              logger.debug('Publish to bus failed, trying next candidate', { candidate: base, err: err.message });
              continue;
            }
          }

          if (!published) {
            logger.warn('Could not publish alert to any agent-bus candidate', { alert: alert.name });
          }
        })();
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
