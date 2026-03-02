const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Coalition = sequelize.define('Coalition', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING(200),
      allowNull: false,
      comment: 'Nome da causa/coalizão (ex: "Contra a PEC X")',
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    hashtag: {
      type: DataTypes.STRING(100),
      allowNull: true,
      comment: 'Hashtag unificadora (ex: #ForaPEC)',
    },
    imageUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    category: {
      type: DataTypes.STRING(50),
      defaultValue: 'manifestacao',
      validate: {
        isIn: [['manifestacao', 'protesto', 'marcha', 'ato_publico',
                'assembleia', 'greve', 'ocupacao', 'vigilia', 'outro']],
      },
    },
    status: {
      type: DataTypes.STRING(20),
      defaultValue: 'active',
      validate: {
        isIn: [['active', 'ended', 'cancelled']],
      },
    },
    // Totais agregados (atualizados com triggers)
    totalEvents: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Quantidade total de eventos vinculados',
    },
    totalAttendees: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Soma de participantes em todos os eventos',
    },
    totalCities: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Número de cidades com eventos',
    },
    // Criador
    creatorId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    tags: {
      type: DataTypes.ARRAY(DataTypes.STRING),
      defaultValue: [],
    },
  }, {
    tableName: 'coalitions',
    timestamps: true,
    indexes: [
      { fields: ['status'] },
      { fields: ['hashtag'] },
      { fields: ['category'] },
      { fields: ['creatorId'] },
    ],
  });

  return Coalition;
};
