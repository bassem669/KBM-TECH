const { Promotion, Produit, Categorie, UserDevice } = require('../models');
const Sequelize = require("sequelize");
const { sendNotification } = require('../utils/sendFCM');
const { Op } = require('sequelize');


const createPromotion = async (req, res) => {
  try {
    const { description, pourcentage, dateDebut, dateFin, produitIds } = req.body;

    if (!description || !pourcentage || !dateDebut || !dateFin) {
      return res.status(400).json({ success: false, message: 'Champs requis manquants' });
    }

    const promotion = await Promotion.create({
      description,
      pourcentage: parseFloat(pourcentage),
      dateDebut: new Date(dateDebut),
      dateFin: new Date(dateFin),
    });

    let produitsAssocies = [];
    if (produitIds && produitIds.length > 0) {
      const ids = Array.isArray(produitIds) ? produitIds : JSON.parse(produitIds);
      await promotion.addProduits(ids);
      produitsAssocies = await Produit.findAll({ where: { id: ids } });
    }

    const devices = await UserDevice.findAll({
      where: { 
        fcm_token: { 
          [Sequelize.Op.ne]: null,
          [Sequelize.Op.ne]: ''
        }
      }
    });

    const tokens = devices.map(d => d.fcm_token);

    if (tokens.length > 0) {
      const title = "🎉 Promotion exclusive !";
      const body = `-${pourcentage}% sur une sélection de produits`;

      await sendNotification(tokens, title, body, {
        type: "promotion",
        promotionId: String(promotion.id),
        produitIds: produitsAssocies.map(p => p.id).join(","),
      });
    }

    const promotionComplete = await Promotion.findByPk(promotion.id, {
      include: [{ model: Produit, as: 'produits', through: { attributes: [] } }]
    });

    res.status(201).json({ 
      success: true,
      message: 'Promotion créée avec succès',
      promotion: promotionComplete
    });

  } catch (err) {
    console.error('Erreur création promotion:', err);
    res.status(500).json({ success: false, message: 'Erreur serveur' });
  }
};


// 📄 Obtenir toutes les promotions
const getAllPromotions = async (req, res) => {
  try {
    const promotions = await Promotion.findAll({
      include: [{ model: Produit, as: 'produits', through: { attributes: [] } }],
    });
    res.status(200).json(promotions);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🔍 Obtenir une promotion par ID
const getPromotionById = async (req, res) => {
  try {
    const promotion = await Promotion.findByPk(req.params.id, {
      include: [{ model: Produit, as: 'produits', through: { attributes: [] } }],
    });

    if (!promotion) {
      return res.status(404).json({ message: 'Promotion non trouvée' });
    }

    res.json(promotion);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✏️ Mettre à jour une promotion
const updatePromotion = async (req, res) => {
  try {
    const { description, pourcentage, dateDebut, dateFin, produitIds } = req.body;
    const promotion = await Promotion.findByPk(req.params.id);

    if (!promotion) return res.status(404).json({ message: 'Promotion non trouvée' });

    await promotion.update({ description, pourcentage, dateDebut, dateFin });

    // Mettre à jour les produits liés
    if (produitIds) {
      await promotion.setProduits(produitIds);
    }

    const devices = await UserDevice.findAll({
      where: { 
        fcm_token: { 
          [Sequelize.Op.ne]: null,
          [Sequelize.Op.ne]: ''
        }
      }
    });

    let produitsAssocies = [];
    if (produitIds && produitIds.length > 0) {
      const ids = Array.isArray(produitIds) ? produitIds : JSON.parse(produitIds);
      await promotion.addProduits(ids);
      produitsAssocies = await Produit.findAll({ where: { id: ids } });
    }

    const tokens = devices.map(d => d.fcm_token);

    if (tokens.length > 0) {
      const title = "🎉 Promotion exclusive !";
      const body = `-${pourcentage}% sur une sélection de produits`;

      await sendNotification(tokens, title, body, {
        type: "promotion",
        promotionId: String(promotion.id),
        produitIds: produitsAssocies.map(p => p.id).join(","),
      });
    }

    res.json({ message: 'Promotion mise à jour avec succès', promotion });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🗑️ Supprimer une promotion
const deletePromotion = async (req, res) => {
  try {
    const promotion = await Promotion.findByPk(req.params.id);
    if (!promotion) return res.status(404).json({ message: 'Promotion non trouvée' });

    await promotion.destroy();
    res.json({ message: 'Promotion supprimée avec succès' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🔥 Obtenir les promotions actives
const getActivePromotions = async (req, res) => {
  try {
    const now = new Date();
    const promotions = await Promotion.findAll({
      where: {
        dateDebut: { [Op.lte]: now },
        dateFin: { [Op.gte]: now },
      },
      include: [{ model: Produit, as: 'produits', through: { attributes: [] } }],
    });

    res.json(promotions);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🗑️ Supprimer un produit d'une promotion
const removeProductFromPromotion = async (req, res) => {
  try {
    const { promotionId, produitId } = req.params;
    
    const promotion = await Promotion.findByPk(promotionId);
    if (!promotion) {
      return res.status(404).json({ message: 'Promotion non trouvée' });
    }

    // Vérifier si le produit existe
    const produit = await Produit.findByPk(produitId);
    if (!produit) {
      return res.status(404).json({ message: 'Produit non trouvé' });
    }

    // Vérifier si le produit est bien dans la promotion
    const produitsInPromotion = await promotion.getProduits({ where: { id: produitId } });
    if (produitsInPromotion.length === 0) {
      return res.status(404).json({ message: 'Ce produit ne fait pas partie de la promotion' });
    }

    // Supprimer le produit de la promotion
    await promotion.removeProduit(produitId);

    res.json({ message: 'Produit retiré de la promotion avec succès' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🗑️ Supprimer plusieurs produits d'une promotion
const removeProductsFromPromotion = async (req, res) => {
  try {
    const { promotionId } = req.params;
    const { produitIds } = req.body;
    
    if (!produitIds || !Array.isArray(produitIds) || produitIds.length === 0) {
      return res.status(400).json({ message: 'La liste des produits à supprimer est requise' });
    }

    const promotion = await Promotion.findByPk(promotionId);
    if (!promotion) {
      return res.status(404).json({ message: 'Promotion non trouvée' });
    }

    // Supprimer les produits de la promotion
    await promotion.removeProduits(produitIds);

    res.json({ 
      message: `${produitIds.length} produit(s) retiré(s) de la promotion avec succès` 
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const applyPromotionToAllProducts = async (req, res) => {
  try {
    const { description, pourcentage, dateDebut, dateFin } = req.body;

    // Créer la promotion
    const promotion = await Promotion.create({
      description,
      pourcentage,
      dateDebut,
      dateFin,
    });

    // Récupérer tous les produits
    const allProducts = await Produit.findAll();
    
    // Appliquer la promotion à tous les produits
    if (allProducts.length > 0) {
      const productIds = allProducts.map(product => product.id);
      await promotion.addProduits(productIds);
    }

     const devices = await UserDevice.findAll({
      where: {
        fcm_token: {
          [Sequelize.Op.ne]: null,
          [Sequelize.Op.ne]: ''
        }
      }
    });

    const tokens = devices.map(d => d.fcm_token).filter(Boolean);

    if (tokens.length > 0) {
      const title = "🎉 Nouvelle promotion sur tous les produits !";
      const body = `-${pourcentage}% sur tous les produits de la boutique !`;

      await sendNotification(tokens, title, body, {
        type: "promotion_update",
        promotionId: String(promotion.id),
        produitIds: allProducts.map(p => p.id).join(","),
      });
    }


    res.status(201).json({ 
      message: `Promotion appliquée à ${allProducts.length} produit(s) avec succès`, 
      promotion,
      produitsAffectes: allProducts.length
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


  // 🏷️ Appliquer une promotion à une ou plusieurs catégories
  const applyPromotionToCategory = async (req, res) => {
    try {
      const { description, pourcentage, dateDebut, dateFin, categorieIds } = req.body;
      console.log("catecories ID : " + categorieIds);
      // Vérifier que toutes les catégories existent
      const categories = await Categorie.findAll({
        where: {
          id: {
            [Op.in]: categorieIds   // <-- tableau d'IDs
          }
        }
      });
      console.log("catecories : " + categories);
      if (categories.length !== categorieIds.length) {
        return res.status(404).json({ message: 'Une ou plusieurs catégories non trouvées' });
      }

      // Créer la promotion
      const promotion = await Promotion.create({
        description,
        pourcentage,
        dateDebut,
        dateFin,
      });

      // Récupérer tous les produits liés aux catégories (relation N-N)
      const produits = await Produit.findAll({
        include: {
          model: Categorie,
          as : 'categories',
          where: { id: categorieIds }
        }
      });

      // Appliquer la promotion aux produits
      if (produits.length > 0) {
        await promotion.addProduits(produits); // Sequelize gère la relation N-N
      }

      // 🔔 Notification à tous les utilisateurs
      const devices = await UserDevice.findAll({
        where: {
          fcm_token: {
            [Sequelize.Op.ne]: null,
            [Sequelize.Op.ne]: ''
          }
        }
      });

      const tokens = devices.map(d => d.fcm_token).filter(Boolean);

      if (tokens.length > 0) {
        const categoryNames = categories.map(c => c.nom).join(", ");

        const title = `🎉 Nouvelle promotion sur ${categoryNames} !`;
        const body = `-${pourcentage}% sur ${produits.length} produit(s) dans les catégories sélectionnées !`;

        await sendNotification(tokens, title, body, {
          type: "promotion_update_categories",
          promotionId: String(promotion.id),
          categorieIds: categorieIds.join(","),
          produitIds: produits.map(p => p.id).join(","),
        });
      }

      res.status(201).json({
        message: `Promotion appliquée à ${produits.length} produit(s) des catégories sélectionnées avec succès`,
        promotion,
        categories: categories.map(c => c.nom),
        produitsAffectes: produits.length
      });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  };

const updatePromotionForAllProducts = async (req, res) => {
  try {
    const { promotionId } = req.params;
    const { description, pourcentage, dateDebut, dateFin } = req.body;

    // Vérifier si la promotion existe
    const promotion = await Promotion.findByPk(promotionId);
    if (!promotion) {
      return res.status(404).json({ message: 'Promotion non trouvée' });
    }

    // Mettre à jour les infos de la promotion
    await promotion.update({ description, pourcentage, dateDebut, dateFin });

    // Récupérer tous les produits
    const allProducts = await Produit.findAll();
    if (allProducts.length > 0) {
      const productIds = allProducts.map(p => p.id);
      await promotion.setProduits(productIds);
    }

    // 🔔 Notification à tous les utilisateurs
    const devices = await UserDevice.findAll({
      where: {
        fcm_token: {
          [Sequelize.Op.ne]: null,
          [Sequelize.Op.ne]: ''
        }
      }
    });

    const tokens = devices.map(d => d.fcm_token).filter(Boolean);

    if (tokens.length > 0) {
      const title = "🎉 Nouvelle promotion sur tous les produits !";
      const body = `-${pourcentage}% sur tous les produits de la boutique !`;

      await sendNotification(tokens, title, body, {
        type: "promotion_update",
        promotionId: String(promotion.id),
        produitIds: allProducts.map(p => p.id).join(","),
      });
    }

    res.json({
      message: `Promotion mise à jour et appliquée à ${allProducts.length} produit(s)`,
      promotion,
      produitsAffectes: allProducts.length
    });

  } catch (err) {
    console.error('Erreur updatePromotionForAllProducts:', err);
    res.status(500).json({ message: err.message });
  }
};


const updatePromotionForCategories = async (req, res) => {
  try {
    const { promotionId } = req.params;
    const { description, pourcentage, dateDebut, dateFin, categorieIds } = req.body;

    // Vérifier si la promotion existe
    const promotion = await Promotion.findByPk(promotionId);
    if (!promotion) return res.status(404).json({ message: 'Promotion non trouvée' });

    // Mettre à jour les infos de la promotion
    await promotion.update({ description, pourcentage, dateDebut, dateFin });

    // Vérifier que les catégories existent
    const categories = await Categorie.findAll({ where: { id: { [Op.in]: categorieIds } } });
    if (categories.length !== categorieIds.length) {
      return res.status(404).json({ message: 'Une ou plusieurs catégories non trouvées' });
    }

    // Récupérer les produits liés aux catégories
    const produits = await Produit.findAll({
      include: {
        model: Categorie,
        as: 'categories',
        where: { id: categorieIds }
      }
    });

    // Appliquer la promotion à ces produits
    if (produits.length > 0) {
      await promotion.setProduits(produits);
    } else {
      await promotion.setProduits([]); // Aucun produit dans les catégories
    }

    // 🔔 Notification à tous les utilisateurs
    const devices = await UserDevice.findAll({
      where: {
        fcm_token: {
          [Sequelize.Op.ne]: null,
          [Sequelize.Op.ne]: ''
        }
      }
    });

    const tokens = devices.map(d => d.fcm_token).filter(Boolean);

    if (tokens.length > 0) {
      const categoryNames = categories.map(c => c.nom).join(", ");

      const title = `🎉 Nouvelle promotion sur ${categoryNames} !`;
      const body = `-${pourcentage}% sur ${produits.length} produit(s) dans les catégories sélectionnées !`;

      await sendNotification(tokens, title, body, {
        type: "promotion_update_categories",
        promotionId: String(promotion.id),
        categorieIds: categorieIds.join(","),
        produitIds: produits.map(p => p.id).join(","),
      });
    }

    res.json({
      message: `Promotion mise à jour pour les catégories sélectionnées et appliquée à ${produits.length} produit(s)`,
      promotion,
      categories: categories.map(c => c.nom),
      produitsAffectes: produits.length
    });

  } catch (err) {
    console.error('Erreur updatePromotionForCategories:', err);
    res.status(500).json({ message: err.message });
  }
};



module.exports = {
  createPromotion,
  getAllPromotions,
  getPromotionById,
  updatePromotion,
  deletePromotion,
  getActivePromotions,
  removeProductFromPromotion,
  removeProductsFromPromotion,
  applyPromotionToAllProducts,          
  applyPromotionToCategory,             
  updatePromotionForAllProducts,     
  updatePromotionForCategories            
};