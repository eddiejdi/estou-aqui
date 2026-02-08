const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const CrowdEstimate = sequelize.define('CrowdEstimate', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    eventId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    // Métodos de estimativa
    method: {
      type: DataTypes.ENUM('checkin_count', 'density_calc', 'manual', 'ai_vision'),
      allowNull: false,
    },
    estimatedCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    confidence: {
      type: DataTypes.DOUBLE,
      allowNull: true,
      comment: 'Confiança da estimativa (0.0 a 1.0)',
      validate: { min: 0, max: 1 },
    },
    // Dados usados na estimativa
    areaSquareMeters: {
      type: DataTypes.DOUBLE,
      allowNull: true,
    },
    densityPerSqMeter: {
      type: DataTypes.DOUBLE,
      allowNull: true,
      comment: 'Pessoas por metro quadrado',
    },
    activeCheckins: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    // Multiplicador de ajuste (nem todos fazem check-in)
    adjustmentFactor: {
      type: DataTypes.DOUBLE,
      defaultValue: 1.0,
      comment: 'Fator multiplicador: estimatedCount = activeCheckins * adjustmentFactor',
    },
    notes: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  }, {
    tableName: 'crowd_estimates',
    timestamps: true,
    indexes: [
      { fields: ['eventId', 'createdAt'] },
      { fields: ['method'] },
    ],
  });

  return CrowdEstimate;
};
