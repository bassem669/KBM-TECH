const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const Commande = require('./Commande');
const Produit = require('./Produit');

class LigneCommande extends Model {}

LigneCommande.init(
  {
    quantite: { type: DataTypes.INTEGER, allowNull: false }
  },
  {
    sequelize,
    modelName: 'LigneCommande',
    tableName: 'ligne_commande',
    timestamps: false
  }
);



module.exports = LigneCommande;
