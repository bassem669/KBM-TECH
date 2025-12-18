const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const Utilisateur = require('./Utilisateur');

class Commande extends Model {}

Commande.init(
  {
    date_commande: { type: DataTypes.DATE, allowNull: false },
    etat: { type: DataTypes.STRING, allowNull: false }
  },
  {
    sequelize,
    modelName: 'Commande',
    tableName: 'commande',
    timestamps: false,
  }
);

Commande.belongsTo(Utilisateur, { foreignKey: 'clientId', as: 'client' });
Commande.belongsTo(Utilisateur, { foreignKey: 'administrateurId' });

module.exports = Commande;