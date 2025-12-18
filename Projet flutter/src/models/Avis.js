const { Sequelize, DataTypes, Model } = require('sequelize');
const sequelize = require('./../config/db-sequelize');
const Produit = require("./Produit");
const Utilisateur = require("./Utilisateur");

class Avis extends Model {}

Avis.init(
    {
        message: {
            type: DataTypes.STRING,
            allowNull: false,
        },
        note: {
            type: DataTypes.DOUBLE,
            allowNull: false,
        },
        date_avis: {
            type: DataTypes.DATE,
            allowNull: false,
        },
        produit_id: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: Produit,
                key: "id"
            }
        },
        client_id: {
            type: DataTypes.INTEGER,
            allowNull: false,
            references: {
                model: Utilisateur,
                key: "id"
            }
        }
    },
    {
        sequelize,
        modelName: 'Avis',
        tableName: 'avis',
        timestamps: false
    }
);

// Associations correctes
Produit.hasMany(Avis, { as: "avis", foreignKey: 'produit_id' });
Avis.belongsTo(Produit, { foreignKey: 'produit_id', as: 'produit' });

Utilisateur.hasMany(Avis, { foreignKey: 'client_id', as: 'avis_utilisateur' });
Avis.belongsTo(Utilisateur, { foreignKey: 'client_id', as: 'client' });

module.exports = Avis;
