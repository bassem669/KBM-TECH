const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');
const Utilisateur = require('./Utilisateur');

class Contact extends Model {}

Contact.init(
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    titre: { type: DataTypes.STRING, allowNull: false },
    email: { type: DataTypes.STRING, allowNull: false},
    message: { type: DataTypes.TEXT, allowNull: false },
    date_contact: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    etat: {
      type: DataTypes.ENUM('nouveau', 'en cours', 'resolu', 'ferme'),
      defaultValue: 'nouveau',
      allowNull: false
    },
    utilisateur_id: { type: DataTypes.INTEGER, allowNull: true, references: { model: Utilisateur, key: 'id' } }
  },
  {
    sequelize,
    modelName: 'Contact',
    tableName: 'contact',
    timestamps: false
  }
);

Contact.belongsTo(Utilisateur, { as: 'client', foreignKey: 'utilisateur_id' });
Utilisateur.hasMany(Contact, { as: 'contacts', foreignKey: 'utilisateur_id' });

module.exports = Contact;
