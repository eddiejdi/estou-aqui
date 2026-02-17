const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Event = sequelize.define('Event', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    title: {
      type: DataTypes.STRING(200),
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    category: {
      type: DataTypes.ENUM(
        'manifestacao',
        'protesto',
        'marcha',
        'ato_publico',
        'assembleia',
        'greve',
        'ocupacao',
        'vigilia',
        'outro'
      ),
      defaultValue: 'manifestacao',
    },
    imageUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    // Localização
    latitude: {
      type: DataTypes.DOUBLE,
      allowNull: false,
    },
    longitude: {
      type: DataTypes.DOUBLE,
      allowNull: false,
    },
    address: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    city: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    state: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },
    // Localização de chegada (para passeatas/marchas)
    endLatitude: {
      type: DataTypes.DOUBLE,
      allowNull: true,
      comment: 'Latitude do ponto de chegada (passeatas)',
    },
    endLongitude: {
      type: DataTypes.DOUBLE,
      allowNull: true,
      comment: 'Longitude do ponto de chegada (passeatas)',
    },
    endAddress: {
      type: DataTypes.STRING(500),
      allowNull: true,
      comment: 'Endereço do ponto de chegada (passeatas)',
    },
    // Datas
    startDate: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    endDate: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    // Status
    status: {
      type: DataTypes.ENUM('scheduled', 'active', 'ended', 'cancelled'),
      defaultValue: 'scheduled',
    },
    // Estimativas
    estimatedAttendees: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Estimativa atual de participantes baseada em check-ins e algoritmo',
    },
    confirmedAttendees: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
      comment: 'Número de check-ins confirmados',
    },
    // Área do evento (para estimativa de densidade)
    areaSquareMeters: {
      type: DataTypes.DOUBLE,
      allowNull: true,
      comment: 'Área estimada do evento em metros quadrados',
    },
    // Organizador
    organizerId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    // Tags para busca
    tags: {
      type: DataTypes.ARRAY(DataTypes.STRING),
      defaultValue: [],
    },
    isVerified: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
  }, {
    tableName: 'events',
    timestamps: true,
    indexes: [
      { fields: ['latitude', 'longitude'] },
      { fields: ['startDate'] },
      { fields: ['status'] },
      { fields: ['city', 'state'] },
      { fields: ['category'] },
    ],
  });

  return Event;
};
