const { Produit, Notification } = require('../models');

// Middleware pour vérifier le stock faible après création/mise à jour de commande
const checkLowStockAfterOrder = async (req, res, next) => {
  try {
    if (req.body.lignes || req.body.produits) {
      const items = req.body.lignes || req.body.produits;
      
      for (const item of items) {
        const produit = await Produit.findByPk(item.produitId);
        if (produit && produit.isLowStock()) {
          await Notification.createLowStockNotification(produit);
        }
      }
    }
    next();
  } catch (error) {
    console.error('Erreur dans checkLowStockAfterOrder:', error);
    next();
  }
};

// Vérification périodique de tous les produits en stock faible
const checkAllLowStock = async () => {
  try {
    const lowStockProducts = await Produit.findLowStockProducts();
    
    for (const produit of lowStockProducts) {
      await Notification.createLowStockNotification(produit);
    }
    
    console.log(`✅ Vérification stock faible: ${lowStockProducts.length} produits en stock faible`);
  } catch (error) {
    console.error('❌ Erreur dans checkAllLowStock:', error);
  }
};

module.exports = {
  checkLowStockAfterOrder,
  checkAllLowStock
};