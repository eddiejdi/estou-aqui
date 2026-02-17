const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const TelegramGroup = sequelize.define('TelegramGroup', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    eventId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    chatId: {
      type: DataTypes.BIGINT,
      allowNull: false,
      comment: 'Telegram chat ID do supergrupo',
    },
    inviteLink: {
      type: DataTypes.STRING(500),
      allowNull: false,
      comment: 'Link de convite do grupo',
    },
    title: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    version: {
      type: DataTypes.INTEGER,
      defaultValue: 1,
      comment: 'Versão do grupo (1, 2, 3...) para quando lota',
    },
    memberCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    maxMembers: {
      type: DataTypes.INTEGER,
      defaultValue: 200000,
      comment: 'Limite do Telegram para supergrupos',
    },
    isFull: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
  }, {
    tableName: 'telegram_groups',
    timestamps: true,
    indexes: [
      { fields: ['eventId'] },
      { fields: ['chatId'], unique: true },
      { fields: ['eventId', 'version'] },
      { fields: ['isFull'] },
    ],
  });

  return TelegramGroup;
};
