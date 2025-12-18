// models/UserDevice.js
const { DataTypes, Model } = require('sequelize');
const sequelize = require('./../config/db-sequelize');
const Utilisateur = require('./Utilisateur');

class UserDevice extends Model {}

UserDevice.init(
  {
    id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
    fcm_token: { type: DataTypes.STRING, allowNull: false },
    device_type: { type: DataTypes.ENUM('android', 'ios', 'web'), defaultValue: 'android' },
    user_id: { type: DataTypes.INTEGER, allowNull: true },
    temp_id: { type: DataTypes.STRING, allowNull: true } // pour utilisateurs anonymes
  },
  {
    sequelize,
    modelName: 'UserDevice',
    tableName: 'user_devices',
    timestamps: true
  }
);

// Associations
UserDevice.belongsTo(Utilisateur, { foreignKey: 'user_id', as: 'user' });
Utilisateur.hasMany(UserDevice, { foreignKey: 'user_id', as: 'devices' });

// Synchronisation optionnelle (à utiliser seulement si tu veux créer la table automatiquement)
sequelize.sync();

module.exports = UserDevice;
