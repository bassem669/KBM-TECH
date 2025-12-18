const { Sequelize, DataTypes, Model } = require('sequelize');
const sequelize = require('./../config/db-sequelize');

class Categorie extends Model {

}

Categorie.init(
    {
        nom : {
            type : DataTypes.STRING,
            allowNull : false,
        }
    },
    {
        sequelize,
        modelName: 'Categorie',
        tableName: 'categorie',
        timestamps: false
    }
);

module.exports = Categorie;