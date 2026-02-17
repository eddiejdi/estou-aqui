const { Sequelize } = require('sequelize');
const config = require('../config/database');

const env = process.env.NODE_ENV || 'development';
const dbConfig = config[env];

let sequelize;
if (dbConfig.use_env_variable) {
  sequelize = new Sequelize(process.env[dbConfig.use_env_variable], dbConfig);
} else {
  sequelize = new Sequelize(dbConfig.database, dbConfig.username, dbConfig.password, dbConfig);
}

// Importar modelos
const User = require('./User')(sequelize);
const Event = require('./Event')(sequelize);
const Checkin = require('./Checkin')(sequelize);
const ChatMessage = require('./ChatMessage')(sequelize);
const CrowdEstimate = require('./CrowdEstimate')(sequelize);
const Notification = require('./Notification')(sequelize);
const TelegramGroup = require('./TelegramGroup')(sequelize);

// Associações
User.hasMany(Event, { foreignKey: 'organizerId', as: 'organizedEvents' });
Event.belongsTo(User, { foreignKey: 'organizerId', as: 'organizer' });

User.hasMany(Checkin, { foreignKey: 'userId', as: 'checkins' });
Checkin.belongsTo(User, { foreignKey: 'userId', as: 'user' });

Event.hasMany(Checkin, { foreignKey: 'eventId', as: 'checkins' });
Checkin.belongsTo(Event, { foreignKey: 'eventId', as: 'event' });

User.hasMany(ChatMessage, { foreignKey: 'userId', as: 'messages' });
ChatMessage.belongsTo(User, { foreignKey: 'userId', as: 'user' });

Event.hasMany(ChatMessage, { foreignKey: 'eventId', as: 'messages' });
ChatMessage.belongsTo(Event, { foreignKey: 'eventId', as: 'event' });

Event.hasMany(CrowdEstimate, { foreignKey: 'eventId', as: 'estimates' });
CrowdEstimate.belongsTo(Event, { foreignKey: 'eventId', as: 'event' });

User.hasMany(Notification, { foreignKey: 'userId', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'userId', as: 'user' });

Event.hasMany(TelegramGroup, { foreignKey: 'eventId', as: 'telegramGroups' });
TelegramGroup.belongsTo(Event, { foreignKey: 'eventId', as: 'event' });

module.exports = {
  sequelize,
  Sequelize,
  User,
  Event,
  Checkin,
  ChatMessage,
  CrowdEstimate,
  Notification,
  TelegramGroup,
};
