// models/Utilisateur.js
const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const bcrypt = require('bcryptjs');

class Utilisateur extends Model {}


Utilisateur.init(
  {
    nom: { type: DataTypes.STRING, allowNull: false },
    prenom: { type: DataTypes.STRING, allowNull: false },
    email: { type: DataTypes.STRING, allowNull: false },
    motDePass: { type: DataTypes.STRING, allowNull: false },
    tel: { type: DataTypes.STRING, allowNull: true },
    adresse: { type: DataTypes.STRING, allowNull: true },
    role: { type: DataTypes.STRING, allowNull: true, defaultValue: 'client'},
    nb_commande: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
    // Nouveaux champs pour la réinitialisation
    resetPasswordCode: { type: DataTypes.STRING, allowNull: true },
    resetPasswordExpires: { type: DataTypes.DATE, allowNull: true }
  },
  {
    sequelize,
    modelName: 'Utilisateur',
    tableName: 'utilisateur',
    timestamps: false
  }
);

sequelize.sync();

module.exports = Utilisateur;