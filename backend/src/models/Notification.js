const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Notification = sequelize.define('Notification', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    title: {
      type: DataTypes.STRING(200),
      allowNull: false,
    },
    body: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    type: {
      type: DataTypes.ENUM('event_nearby', 'event_starting', 'event_update', 'chat_mention', 'crowd_milestone', 'system'),
      allowNull: false,
    },
    data: {
      type: DataTypes.JSONB,
      allowNull: true,
      comment: 'Dados extras (eventId, etc)',
    },
    isRead: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    sentAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  }, {
    tableName: 'notifications',
    timestamps: true,
    indexes: [
      { fields: ['userId', 'isRead'] },
      { fields: ['type'] },
    ],
  });

  return Notification;
};
