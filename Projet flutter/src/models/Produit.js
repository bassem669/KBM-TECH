const { DataTypes, Model } = require('sequelize');
const sequelize = require('./../config/db-sequelize');

class Produit extends Model {
    avisMoyenne() {
        if (!this.avis || this.avis.length === 0) return 0;
        const total = this.avis.reduce((sum, avis) => sum + avis.note, 0);
        return (total / this.avis.length).toFixed(2);
    }

    nbAvis() {
        if (!this.avis || this.avis.length === 0) return 0;
        return this.avis.length;
    }

    // ✅ NOUVEAU: Méthode pour vérifier le stock faible
    isLowStock() {
        const lowStockThreshold = this.lowStockThreshold || 10; // Seuil par défaut
        return this.quantite <= lowStockThreshold;
    }
}

Produit.init(
    {
        nom: {
            type: DataTypes.STRING,
            allowNull: false,
        },
        description: {
            type: DataTypes.STRING,
            allowNull: false,
        },
        quantite: {
            type: DataTypes.INTEGER,
            allowNull: false,
        },
        prix: {
            type: DataTypes.FLOAT,
            allowNull: false,
        },
        nbQteAchat: {
            type: DataTypes.INTEGER,
            defaultValue: 0,
        },
        // ✅ NOUVEAU: Seuil de stock faible
        lowStockThreshold: {
            type: DataTypes.INTEGER,
            defaultValue: 10,
            field: 'low_stock_threshold'
        }
    },
    {
        sequelize,
        modelName: 'Produit',
        tableName: 'produit',
        timestamps: false,
        hooks: {
            beforeDestroy: async (produit, options) => {
                const fs = require('fs');
                const path = require('path');
                const Image = require('./Image');
                
                const images = await Image.findAll({ where: { produitId: produit.id } });
                for (const img of images) {
                    const filePath = path.join(__dirname, '..', img.path);
                    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
                    await img.destroy();
                }
            },
            // ✅ NOUVEAU: Hook après mise à jour pour vérifier le stock
            afterUpdate: async (produit, options) => {
                if (produit.changed('quantite') && produit.isLowStock()) {
                    const { Notification } = require('./index');
                    await Notification.createLowStockNotification(produit);
                }
            }
        }
    }
);

// ✅ NOUVEAU: Méthode de classe pour trouver les produits en stock faible
Produit.findLowStockProducts = function() {
    return this.findAll({
        where: {
            quantite: {
                [sequelize.Sequelize.Op.lte]: sequelize.Sequelize.col('lowStockThreshold')
            }
        }
    });
};

module.exports = Produit;