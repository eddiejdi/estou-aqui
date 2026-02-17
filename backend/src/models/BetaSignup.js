const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const BetaSignup = sequelize.define('BetaSignup', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
      validate: { isEmail: true },
    },
    city: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    phone: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    socialUrl: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'social_url',
    },
    motivation: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    device: {
      type: DataTypes.STRING,
      allowNull: true,
    },
    source: {
      type: DataTypes.STRING,
      defaultValue: 'landing_page',
    },
    userAgent: {
      type: DataTypes.TEXT,
      allowNull: true,
      field: 'user_agent',
    },
    status: {
      type: DataTypes.ENUM('pending', 'approved', 'rejected'),
      defaultValue: 'pending',
    },
    reviewNotes: {
      type: DataTypes.TEXT,
      allowNull: true,
      field: 'review_notes',
    },
    publicDataCheck: {
      type: DataTypes.JSONB,
      allowNull: true,
      field: 'public_data_check',
    },
    botScore: {
      type: DataTypes.FLOAT,
      defaultValue: 0,
      field: 'bot_score',
    },
    ipAddress: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'ip_address',
    },
  }, {
    tableName: 'beta_signups',
    timestamps: true,
    underscored: true,
  });

  return BetaSignup;
};
