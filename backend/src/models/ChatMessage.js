const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const ChatMessage = sequelize.define('ChatMessage', {
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
    content: {
      type: DataTypes.TEXT,
      allowNull: false,
      validate: { len: [1, 2000] },
    },
    type: {
      type: DataTypes.ENUM('text', 'image', 'location', 'alert'),
      defaultValue: 'text',
    },
    isDeleted: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
  }, {
    tableName: 'chat_messages',
    timestamps: true,
    indexes: [
      { fields: ['eventId', 'createdAt'] },
      { fields: ['userId'] },
    ],
  });

  return ChatMessage;
};
