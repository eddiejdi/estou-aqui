const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Checkin = sequelize.define('Checkin', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    eventId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    latitude: {
      type: DataTypes.DOUBLE,
      allowNull: false,
    },
    longitude: {
      type: DataTypes.DOUBLE,
      allowNull: false,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      comment: 'Se o usuário ainda está no local',
    },
    checkedOutAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  }, {
    tableName: 'checkins',
    timestamps: true,
    indexes: [
      { fields: ['userId', 'eventId'], unique: true },
      { fields: ['eventId', 'isActive'] },
    ],
  });

  return Checkin;
};
