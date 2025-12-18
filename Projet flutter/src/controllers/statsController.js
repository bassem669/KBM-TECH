const { Commande, Promotion, Utilisateur } = require('../models');
const jwt = require('jsonwebtoken');
require('dotenv').config();

// Version alternative avec Promise.all pour plus de performance
const getStats =  async (req, res) => {
  try {
    // Exécuter toutes les requêtes en parallèle
    const [
      nbUtilisateurs,
      nbCommandes,
      nbPromotions,
    ] = await Promise.all([
      Utilisateur.count(),
      Commande.count(),
      Promotion.count(),
    ]);
    
    const statistiques = {
      nb_utilisateurs: nbUtilisateurs,
      nb_commandes: nbCommandes,
      nb_promotions: nbPromotions,
    };
    
    res.status(200).json({
      success: true,
      data: statistiques
    });
    
  } catch (error) {
    console.error('Erreur lors de la récupération des statistiques:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
};

module.exports = { getStats }