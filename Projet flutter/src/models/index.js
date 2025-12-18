// src/models/index.js
const { Sequelize } = require('sequelize');
const path = require('path');

// Connexion DB
const sequelize = require('../config/db-sequelize.js');

// Import des modèles
const Produit = require('./Produit');
const Categorie = require('./Categorie');
const Image = require('./Image');
const Avis = require('./Avis');
const Promotion = require('./Promotion');
const Utilisateur = require('./Utilisateur');
const Commande = require('./Commande');
const LigneCommande = require('./LigneCommande');
const ProduitCategorie = require('./Produit_categorie.js');
const ProduitPromotion = require('./ProduitPromotion.js');
const ListeSouhait = require('./ListeSouhait.js');
const Notification = require('./Notification');
const UserDevice = require("./UserDevice.js"); // ✅ NOUVEAU

// 🔗 Associations existantes
Produit.belongsToMany(Categorie, { 
  through: ProduitCategorie, 
  as: "categories", 
  foreignKey: 'produit_id' 
});

Categorie.belongsToMany(Produit, { 
  through: ProduitCategorie, 
  as: "produits",  
  foreignKey: 'categorie_id' 
});

Produit.belongsToMany(Promotion, {
  through: ProduitPromotion,
  as: 'promotions',
  foreignKey: 'produit_id'
});

Promotion.belongsToMany(Produit, {
  through: ProduitPromotion,
  as: 'produits',
  foreignKey: 'promotion_id'
});

Commande.hasMany(LigneCommande, {
  foreignKey: 'commandeId',
  as: 'lignes',
  onDelete: 'CASCADE'
});

LigneCommande.belongsTo(Commande, {
  foreignKey: 'commandeId',
  as: 'commande'
});

LigneCommande.belongsTo(Produit, {
  foreignKey: 'produitId',
  as: 'produit'
});

// ✅ NOUVELLES Associations pour Notification
Utilisateur.hasMany(Notification, {
  foreignKey: 'recipientId',
  as: 'notifications'
});

Produit.hasMany(LigneCommande, {
  foreignKey: 'produitId',
  onDelete: 'CASCADE'
});

Notification.belongsTo(Utilisateur, {
  foreignKey: 'recipientId',
  as: 'recipient'
});

// ✅ Export complet
module.exports = {
  sequelize,
  Produit,
  Categorie,
  Image,
  Avis,
  Promotion,
  Utilisateur,
  Commande,
  LigneCommande,
  ProduitCategorie,
  ProduitPromotion,
  Notification, // ✅ NOUVEAU
  ListeSouhait,
  UserDevice
};