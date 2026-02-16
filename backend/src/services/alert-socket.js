/**
 * 🚨 Socket.io Setup for Real-time Alerts
 * Configura eventos de alerta para transmissão em tempo real
 */

const Logger = require('./logger');
const logger = Logger.instance();

const setupAlertSocket = (io) => {
  /**
   * Namespace para alertas
   */
  const alertNamespace = io.of('/alerts');

  alertNamespace.on('connection', (socket) => {
    logger.info('Alert client connected', {
      socketId: socket.id,
      namespace: '/alerts'
    });

    /**
     * Cliente solicita alertas ativos
     */
    socket.on('alerts:request-active', () => {
      try {
        // Obter o serviço de alertas da app
        const app = socket.handshake.headers.app;
        if (app && app.alertingService) {
          const alerts = app.alertingService.getActiveAlerts();
          socket.emit('alerts:active', {
            alerts,
            count: alerts.length,
            timestamp: new Date().toISOString()
          });
        }
      } catch (error) {
        logger.error('Error responding to alerts:request-active', {
          error: error.message
        });
        socket.emit('alerts:error', { message: error.message });
      }
    });

    /**
     * Cliente solicita histórico
     */
    socket.on('alerts:request-history', (data) => {
      try {
        const limit = data?.limit || 50;
        const app = socket.handshake.headers.app;
        if (app && app.alertingService) {
          const history = app.alertingService.getAlertHistory(limit);
          socket.emit('alerts:history', {
            alerts: history,
            count: history.length,
            limit,
            timestamp: new Date().toISOString()
          });
        }
      } catch (error) {
        logger.error('Error responding to alerts:request-history', {
          error: error.message
        });
        socket.emit('alerts:error', { message: error.message });
      }
    });

    /**
     * Cliente solicita estatísticas
     */
    socket.on('alerts:request-stats', () => {
      try {
        const app = socket.handshake.headers.app;
        if (app && app.alertingService) {
          const stats = app.alertingService.getAlertStats();
          socket.emit('alerts:stats', {
            stats,
            timestamp: new Date().toISOString()
          });
        }
      } catch (error) {
        logger.error('Error responding to alerts:request-stats', {
          error: error.message
        });
        socket.emit('alerts:error', { message: error.message });
      }
    });

    /**
     * Cliente se desconecta
     */
    socket.on('disconnect', () => {
      logger.info('Alert client disconnected', { socketId: socket.id });
    });

    /**
     * Erro no socket
     */
    socket.on('error', (error) => {
      logger.error('Alert socket error', {
        socketId: socket.id,
        error: error.message
      });
    });
  });

  logger.info('Alert Socket.io namespace configured', { namespace: '/alerts' });
  return alertNamespace;
};

module.exports = setupAlertSocket;
