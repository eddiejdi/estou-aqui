const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const WebChatMessage = sequelize.define('WebChatMessage', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    sessionId: {
      type: DataTypes.STRING(64),
      allowNull: false,
    },
    direction: {
      type: DataTypes.ENUM('incoming', 'outgoing'),
      allowNull: false,
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    senderName: {
      type: DataTypes.STRING,
      defaultValue: 'Visitante',
    },
    telegramMessageId: {
      type: DataTypes.INTEGER,
    },
    ipAddress: {
      type: DataTypes.STRING,
    },
    userAgent: {
      type: DataTypes.STRING(512),
    },
    read: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    source: {
      type: DataTypes.STRING,
      defaultValue: 'rpa4all.com',
    },
  }, {
    tableName: 'web_chat_messages',
    timestamps: true,
    underscored: true,
    indexes: [
      { fields: ['session_id'] },
      { fields: ['telegram_message_id'] },
      { fields: ['created_at'] },
    ],
  });

  return WebChatMessage;
};
