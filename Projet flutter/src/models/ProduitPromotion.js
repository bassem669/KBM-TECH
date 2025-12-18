const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const Produit = require('./Produit');      // ✅ import du modèle Produit
const Promotion = require('./Promotion');  // ✅ import du modèle Promotion

class ProduitPromotion extends Model {}

ProduitPromotion.init(
  {
    produit_id: {   // ⚠️ cohérence avec foreignKey ci-dessous
      type: DataTypes.INTEGER,
      primaryKey: true,
      references: {
        model: 'produit',
        key: 'id'
      },
      onDelete: 'CASCADE',
      onUpdate: 'CASCADE'
    },
    promotion_id: { // idem ici
      type: DataTypes.INTEGER,
      primaryKey: true,
      references: {
        model: 'promotion',
        key: 'id'
      },
      onDelete: 'CASCADE',
      onUpdate: 'CASCADE'
    }
  },
  {
    sequelize,
    modelName: 'ProduitPromotion',
    tableName: 'produit_promotion',
    timestamps: false
  }
);


module.exports = ProduitPromotion;
