const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const Utilisateur = require('./Utilisateur');
const Produit = require('./Produit');

class ListeSouhait extends Model {}

ListeSouhait.init(
  {
    date_ajout: { 
      type: DataTypes.DATE, 
      allowNull: false, 
      defaultValue: DataTypes.NOW 
    },
    client_id: { 
      type: DataTypes.INTEGER,   // ✅ correction
      allowNull: false 
    }
  },
  {
    sequelize,
    modelName: 'ListeSouhait',
    tableName: 'listesouhait',
    timestamps: false
  }
);

// Associations
Utilisateur.hasOne(ListeSouhait, { foreignKey: 'client_id', onDelete: 'CASCADE' });
ListeSouhait.belongsTo(Utilisateur, { foreignKey: 'client_id' });

ListeSouhait.belongsToMany(Produit, { 
  through: "listesouhait_produit", 
  foreignKey: 'listeId', 
});

Produit.belongsToMany(ListeSouhait, { 
  through: "listesouhait_produit", 
  foreignKey: 'produitId', 
});

module.exports = ListeSouhait;
