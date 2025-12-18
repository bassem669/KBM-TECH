const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const Produit = require('./Produit');

class Promotion extends Model {}

Promotion.init(
  {
    description: { type: DataTypes.STRING, allowNull: false },
    pourcentage: { type: DataTypes.DOUBLE, allowNull: false },
    dateDebut: { type: DataTypes.DATE, allowNull: false },
    dateFin: { type: DataTypes.DATE, allowNull: false }
  },
  {
    sequelize,
    modelName: 'Promotion',
    tableName: 'promotion',
    timestamps: false
  }
);

module.exports = Promotion;
