/**
 * Serviço de Estimativa de Público
 * 
 * Métodos de estimativa:
 * 1. Contagem de check-ins com fator multiplicador
 * 2. Cálculo por densidade (área × densidade)
 * 3. Combinação de ambos
 * 
 * O fator multiplicador assume que apenas uma fração dos participantes
 * faz check-in no app. Valores típicos:
 * - Evento com boa divulgação do app: 3-5x
 * - Evento genérico: 8-15x
 * - Grande manifestação: 15-30x
 */

const { Checkin, CrowdEstimate } = require('../models');

const DENSITY_LEVELS = {
  low: parseFloat(process.env.CROWD_DENSITY_LOW || '0.5'),       // Pessoas espalhadas
  medium: parseFloat(process.env.CROWD_DENSITY_MEDIUM || '1.5'), // Multidão moderada
  high: parseFloat(process.env.CROWD_DENSITY_HIGH || '3.0'),     // Multidão densa
  very_high: parseFloat(process.env.CROWD_DENSITY_VERY_HIGH || '5.0'), // Extremamente denso
};

// Fator de ajuste baseado no tamanho do evento
function getAdjustmentFactor(activeCheckins) {
  if (activeCheckins < 10) return 3;      // Evento pequeno, app bem divulgado
  if (activeCheckins < 50) return 5;
  if (activeCheckins < 200) return 8;
  if (activeCheckins < 1000) return 12;
  return 15; // Grande manifestação
}

class CrowdEstimationService {
  /**
   * Estima o número de participantes de um evento
   * @param {Object} event - Instância do modelo Event
   * @param {Object} options - Opções: { densityLevel, customFactor }
   * @returns {Object} Estimativa
   */
  static async estimate(event, options = {}) {
    const activeCheckins = await Checkin.count({
      where: { eventId: event.id, isActive: true },
    });

    let estimatedCount = 0;
    let method = 'checkin_count';
    let confidence = 0.5;
    let densityPerSqMeter = null;

    if (event.areaSquareMeters && options.densityLevel) {
      // Método por densidade
      const density = DENSITY_LEVELS[options.densityLevel] || DENSITY_LEVELS.medium;
      const densityEstimate = Math.round(event.areaSquareMeters * density);

      // Combinar com check-ins para melhor precisão
      const adjustmentFactor = options.customFactor || getAdjustmentFactor(activeCheckins);
      const checkinEstimate = activeCheckins * adjustmentFactor;

      // Média ponderada: prioriza check-ins se muitos, senão densidade
      if (activeCheckins >= 50) {
        estimatedCount = Math.round(checkinEstimate * 0.6 + densityEstimate * 0.4);
        confidence = 0.7;
      } else {
        estimatedCount = Math.round(checkinEstimate * 0.3 + densityEstimate * 0.7);
        confidence = 0.5;
      }

      method = 'density_calc';
      densityPerSqMeter = density;
    } else {
      // Apenas check-ins
      const adjustmentFactor = options.customFactor || getAdjustmentFactor(activeCheckins);
      estimatedCount = activeCheckins * adjustmentFactor;
      confidence = activeCheckins >= 100 ? 0.6 : activeCheckins >= 20 ? 0.4 : 0.3;
    }

    // Garantir mínimo = check-ins confirmados
    estimatedCount = Math.max(estimatedCount, activeCheckins);

    // Salvar estimativa
    const estimate = await CrowdEstimate.create({
      eventId: event.id,
      method,
      estimatedCount,
      confidence,
      areaSquareMeters: event.areaSquareMeters,
      densityPerSqMeter,
      activeCheckins,
      adjustmentFactor: options.customFactor || getAdjustmentFactor(activeCheckins),
    });

    // Atualizar evento
    await event.update({ estimatedAttendees: estimatedCount });

    return estimate;
  }

  /**
   * Estima usando o método de Jacobs (área × densidade)
   * Referência: Herbert Jacobs, 1967
   */
  static jacobsMethod(areaSquareMeters, densityLevel = 'medium') {
    const density = DENSITY_LEVELS[densityLevel] || DENSITY_LEVELS.medium;
    return {
      low: Math.round(areaSquareMeters * DENSITY_LEVELS.low),
      estimate: Math.round(areaSquareMeters * density),
      high: Math.round(areaSquareMeters * DENSITY_LEVELS.very_high),
      density,
    };
  }
}

module.exports = CrowdEstimationService;
