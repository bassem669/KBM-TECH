const { Sequelize, DataTypes, Model } = require('sequelize');
const sequelize = require('./../config/db-sequelize');
const Produit = require("./Produit");
const Categorie = require("./Categorie");

class ProduitCategorie extends Model {}

ProduitCategorie.init(
  {
    produit_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: Produit,
        key: "id"
      }
    },
    categorie_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: Categorie,
        key: "id"
      }
    }
  },
  {
    sequelize,
    modelName: 'ProduitCategorie',
    tableName: 'produit_categorie',
    timestamps: false
  }
);




module.exports = ProduitCategorie;
