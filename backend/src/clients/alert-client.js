/**
 * 🚨 Alert Client - Socket.io Real-time Alerts
 * Cliente para conectar ao servidor de alertas e receber notificações em tempo real
 * 
 * Uso:
 * ```javascript
 * import AlertClient from './alert-client.js';
 * 
 * const client = new AlertClient('http://localhost:3000');
 * 
 * client.onAlertsUpdate((alerts) => {
 *   console.log('Alertas atualizados:', alerts);
 * });
 * 
 * client.onCriticalAlert((alert) => {
 *   console.log('ALERTA CRÍTICO:', alert);
 *   // Mostrar notificação visual/sonora
 * });
 * ```
 */

import io from 'socket.io-client';

class AlertClient {
  constructor(baseUrl = 'http://localhost:3000') {
    this.baseUrl = baseUrl;
    this.socket = null;
    this.connected = false;

    // Callbacks
    this.onConnectCallback = null;
    this.onDisconnectCallback = null;
    this.onUpdatesCallback = null;
    this.onCriticalCallback = null;
    this.onWarningCallback = null;
    this.onStatsCallback = null;

    this.init();
  }

  /**
   * Inicializa conexão com Socket.io
   */
  init() {
    try {
      this.socket = io(`${this.baseUrl}/alerts`, {
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionDelayMax: 5000,
        reconnectionAttempts: 5
      });

      this._setupListeners();
      console.log('✅ AlertClient initialized');
    } catch (error) {
      console.error('❌ Error initializing AlertClient:', error);
    }
  }

  /**
   * Configura listeners do Socket.io
   */
  _setupListeners() {
    // Conexão estabelecida
    this.socket.on('connect', () => {
      this.connected = true;
      console.log('✅ Connected to alerts namespace');
      this.onConnectCallback?.();

      // Solicitar alertas ativos ao conectar
      this.requestActiveAlerts();
      this.requestStats();
    });

    // Desconexão
    this.socket.on('disconnect', () => {
      this.connected = false;
      console.log('❌ Disconnected from alerts namespace');
      this.onDisconnectCallback?.();
    });

    // Atualização de alertas
    this.socket.on('alerts:update', (data) => {
      console.log('📡 Alerts update:', data);
      this.onUpdatesCallback?.(data.alerts, data.status);
    });

    // Alerta crítico
    this.socket.on('alert:critical', (alert) => {
      console.log('🚨 CRITICAL ALERT:', alert);
      this.onCriticalCallback?.(alert);
      this._playAlert('critical');
    });

    // Alerta de aviso
    this.socket.on('alert:warning', (alert) => {
      console.log('⚠️ WARNING ALERT:', alert);
      this.onWarningCallback?.(alert);
      this._playAlert('warning');
    });

    // Alertas ativos recebidos
    this.socket.on('alerts:active', (data) => {
      console.log('📊 Active alerts:', data);
      this.onUpdatesCallback?.(data.alerts, 'active');
    });

    // Histórico recebido
    this.socket.on('alerts:history', (data) => {
      console.log('📜 Alert history:', data);
    });

    // Estatísticas recebidas
    this.socket.on('alerts:stats', (data) => {
      console.log('📈 Alert stats:', data);
      this.onStatsCallback?.(data.stats);
    });

    // Erro
    this.socket.on('alerts:error', (error) => {
      console.error('❌ Alert error:', error);
    });

    // Erro geral
    this.socket.on('error', (error) => {
      console.error('❌ Socket error:', error);
    });
  }

  /**
   * Registra callback para conexão
   */
  onConnect(callback) {
    this.onConnectCallback = callback;
    if (this.connected) {
      callback();
    }
  }

  /**
   * Registra callback para desconexão
   */
  onDisconnect(callback) {
    this.onDisconnectCallback = callback;
  }

  /**
   * Registra callback para atualizações de alertas
   */
  onAlertsUpdate(callback) {
    this.onUpdatesCallback = callback;
  }

  /**
   * Registra callback para alertas críticos
   */
  onCriticalAlert(callback) {
    this.onCriticalCallback = callback;
  }

  /**
   * Registra callback para alertas de aviso
   */
  onWarningAlert(callback) {
    this.onWarningCallback = callback;
  }

  /**
   * Registra callback para estatísticas
   */
  onStats(callback) {
    this.onStatsCallback = callback;
  }

  /**
   * Solicita alertas ativos
   */
  requestActiveAlerts() {
    if (this.connected) {
      this.socket.emit('alerts:request-active');
    }
  }

  /**
   * Solicita histórico
   */
  requestHistory(limit = 50) {
    if (this.connected) {
      this.socket.emit('alerts:request-history', { limit });
    }
  }

  /**
   * Solicita estatísticas
   */
  requestStats() {
    if (this.connected) {
      this.socket.emit('alerts:request-stats');
    }
  }

  /**
   * Reproduz som de alerta
   */
  _playAlert(severity) {
    try {
      // Criar um simples beep usando Web Audio API
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);

      const frequency = severity === 'critical' ? 1000 : 800;
      const duration = severity === 'critical' ? 0.5 : 0.3;

      oscillator.frequency.value = frequency;
      oscillator.type = 'sine';

      gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + duration);

      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + duration);
    } catch (error) {
      console.warn('Could not play alert sound:', error);
    }
  }

  /**
   * Formata um alerta para exibição
   */
  formatAlert(alert) {
    return {
      title: alert.summary || alert.name,
      message: alert.description || '',
      severity: alert.severity || 'unknown',
      instance: alert.instance || 'unknown',
      timestamp: alert.timestamp,
      status: alert.status,
      icon: this._getSeverityIcon(alert.severity)
    };
  }

  /**
   * Retorna ícone baseado na severidade
   */
  _getSeverityIcon(severity) {
    const icons = {
      critical: '🚨',
      warning: '⚠️',
      info: 'ℹ️',
      unknown: '❓'
    };
    return icons[severity] || icons.unknown;
  }

  /**
   * Desconecta do servidor
   */
  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      console.log('Alert client disconnected');
    }
  }

  /**
   * Verifica se está conectado
   */
  isConnected() {
    return this.connected;
  }
}

export default AlertClient;
