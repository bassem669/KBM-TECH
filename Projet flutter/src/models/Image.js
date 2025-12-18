const { Sequelize, DataTypes, Model } = require('sequelize');
const sequelize = require('./../config/db-sequelize');
const Produit = require("./Produit");


class Image extends Model {

}

Image.init(
    {
        path : {
            type : DataTypes.STRING,
            allowNull : false,
        },
        legende : {
            type : DataTypes.STRING,
            allowNull : false,
        },
        produitId : {
            type : DataTypes.INTEGER,
            allowNull : false,
            references : {
                model : Produit,
                key : "id"
            }
        }
    },
    {
        sequelize,
        modelName: 'Image',
        tableName: 'image',
        timestamps: false
    }
);


Produit.hasMany(Image, { foreignKey: 'produitId', as: 'images' });
Image.belongsTo(Produit, { foreignKey: 'produitId', as: 'produit' });

module.exports = Image;