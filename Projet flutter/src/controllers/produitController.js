// controllers/produitController.js
const { Produit, Categorie, Image, Avis, Promotion, Utilisateur, UserDevice } = require('../models');
const { Op } = require('sequelize');
const fs = require('fs');
const path = require('path');
const { sendNotification } = require('../utils/sendFCM');

// === GET TOUS LES PRODUITS ===
const getAll = async (req, res) => {
  try {
    const { page = 1, limit = 10, search, categorie } = req.query;
    const where = search ? { 
      [Op.or]: [
        { nom: { [Op.like]: `%${search}%` } },
        { description: { [Op.like]: `%${search}%` } }
      ] 
    } : {};

    const include = [
      { model: Image, as: 'images' },
      { model: Categorie, as: 'categories', where: categorie ? { id: categorie } : undefined, required: !!categorie },
      { model: Avis, as: 'avis' },
      { model: Promotion, as: 'promotions', through: { attributes: [] } }
    ];

    const { count, rows } = await Produit.findAndCountAll({
      where, include, limit: +limit, offset: (page - 1) * limit, distinct: true
    });

    res.json({
      total: count,
      pages: Math.ceil(count / limit),
      data: rows.map(p => ({ 
        ...p.toJSON(), 
        avisMoyenne: p.avisMoyenne(), 
        nbAvis: p.nbAvis() 
      }))
    });
  } catch (err) { res.status(500).json({ message: err.message }); }
};

const getPlusNotes = async (req, res) => {
  try {
    const produits = await Produit.findAll({
      include: [
        { model: Avis, as: 'avis' },
        { model: Categorie, as: 'categories' },
        { model: Image, as: 'images' },
        { model: Promotion, as: 'promotions', through: { attributes: [] } }
      ]
    });

    // Calcul de la moyenne des avis et tri
    const sorted = produits
      .map(p => ({
        ...p.toJSON(),
        avisMoyenne: p.avisMoyenne(),
        nbAvis: p.nbAvis()
      }))
      .sort((a, b) => b.avisMoyenne - a.avisMoyenne);

    res.json(sorted.slice(0, 10));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getPlusPopulaires = async (req, res) => {
  try {
    const produits = await Produit.findAll({
      include: [
        { model: Image, as: 'images' },
        { model: Avis, as: 'avis' },
        { model: Categorie, as: 'categories' },
        { model: Promotion, as: 'promotions', through: { attributes: [] } }
      ],
      order: [['nbQteAchat', 'DESC']]
    });

    const produitsPlusPop = produits.map(p => ({ 
        ...p.toJSON(), 
        avisMoyenne: p.avisMoyenne(), 
        nbAvis: p.nbAvis() 
      }))

    res.json(produitsPlusPop.slice(0, 10));
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


// === GET PRODUIT PAR ID ===
const getById = async (req, res) => {
  try {
    const produit = await Produit.findByPk(req.params.id, {
      include: [
        { model: Image, as: 'images' },
        { model: Categorie, as: 'categories' },
        { model: Avis, as: 'avis', include: [{ model: Utilisateur, as : 'client', attributes: ['nom', 'prenom'] }] },
        { model: Promotion, as: 'promotions', through: { attributes: [] } }
      ]
    });
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });
    res.json({ ...produit.toJSON(), avisMoyenne: produit.avisMoyenne(), nbAvis: produit.nbAvis() });
  } catch (err) { res.status(500).json({ message: err.message }); }
};

// === CREATE PRODUIT (avec images + notification FCM) ===



const create = async (req, res) => {
  try {
    console.log('🟢 Début création produit');

    const { nom, description, quantite, prix, categorieIds } = req.body;

    if (!nom || !description || quantite === undefined || prix === undefined) {
      return res.status(400).json({
        message: 'Données manquantes: nom, description, quantite et prix sont requis'
      });
    }

    const produit = await Produit.create({
      nom,
      description,
      quantite: parseInt(quantite),
      prix: parseFloat(prix)
    });

    console.log(`📌 Produit créé ID=${produit.id}`);

    if (categorieIds) {
      try {
        await produit.setCategories(JSON.parse(categorieIds));
      } catch {}
    }

    if (req.files?.length > 0) {
      await Promise.all(
        req.files.map(file =>
          Image.create({
            path: `/uploads/${file.filename}`,
            legende: `Image de ${nom}`,
            produitId: produit.id,
          })
        )
      );
    }

    // 🔔 NOTIFICATIONS FCM
    console.log("🔔 Préparation des notifications...");

    const devices = await UserDevice.findAll({
      where: { fcm_token: { [Op.ne]: null } }
    });

    const tokens = devices.map(d => d.fcm_token);

    console.log(`📱 Tokens trouvés : ${tokens.length}`);

    if (tokens.length > 0) {
      const notif = await sendNotification(
        tokens,
        "🆕 Nouveau produit",
        `Découvrez « ${nom} » dès maintenant !`,
        {
          type: "new_product",
          produitId: String(produit.id),
        }
      );

      console.log(`📨 Succès: ${notif.successCount} / Échecs: ${notif.failureCount}`);

      if (notif.failureCount > 0) {
        const invalidTokens = [];

        notif.responses.forEach((r, i) => {
          if (!r.success) invalidTokens.push(tokens[i]);
        });

        if (invalidTokens.length > 0) {
          await UserDevice.destroy({ where: { fcm_token: invalidTokens } });
          console.log(`🧹 ${invalidTokens.length} tokens supprimés`);
        }
      }
    }

    res.status(201).json({ message: "Produit créé avec succès" });

  } catch (err) {
    console.error("❌ Erreur création produit :", err);
    return res.status(500).json({ message: err.message });
  }
};



// === UPDATE PRODUIT ===
const update = async (req, res) => {
  try {
    const produit = await Produit.findByPk(req.params.id);
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });

    const { nom, description, quantite, prix, categorieIds, promotionIds } = req.body;
    await produit.update({ nom, description, quantite, prix });

    if (categorieIds) await produit.setCategories(JSON.parse(categorieIds));
    if (promotionIds) await produit.setPromotions(JSON.parse(promotionIds));

    if (req.files) {
      for (const file of req.files) {
        await Image.create({
          path: `/uploads/${file.filename}`,
          legende: `Image de ${nom || produit.nom}`,
          produitId: produit.id
        });
      }
    }

    res.json(produit);
  } catch (err) { res.status(400).json({ message: err.message }); }
};

const remove = async (req, res) => {
  try {
    const produit = await Produit.findByPk(req.params.id, { include: 'categories' });
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });

    // Supprimer les associations dans la table produit_categorie
    await produit.setCategories([]);

    // Maintenant supprimer le produit
    await produit.destroy();

    res.json({ message: 'Produit supprimé avec succès' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


// === UPLOAD / DELETE IMAGE ===
const uploadImage = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'Image requise' });
    const produit = await Produit.findByPk(req.params.id);
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });
    const image = await Image.create({
      path: `/uploads/${req.file.filename}`,
      legende: req.body.legende || 'Image produit',
      produitId: produit.id
    });
    res.status(201).json(image);
  } catch (err) { res.status(500).json({ message: err.message }); }
};

const deleteImage = async (req, res) => {
  try {
    console.log('🗑️ Suppression image:', req.params.imageId, 'du produit:', req.params.id);
    
    const image = await Image.findByPk(req.params.imageId);
    if (!image) {
      console.log('❌ Image non trouvée:', req.params.imageId);
      return res.status(404).json({ message: 'Image non trouvée' });
    }

    // Vérifier que l'image appartient bien au produit
    if (image.produitId != req.params.id) {
      console.log('❌ Image ne correspond pas au produit');
      return res.status(400).json({ message: 'Cette image n\'appartient pas à ce produit' });
    }

    const filePath = path.join(__dirname, '..', image.path);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      console.log('✅ Fichier supprimé du disque:', filePath);
    } else {
      console.warn('⚠️ Fichier non trouvé sur le disque:', filePath);
    }

    await image.destroy();
    console.log('✅ Image supprimée de la base de données');

    res.json({ message: 'Image supprimée' });
  } catch (err) { 
    console.error('❌ Erreur suppression image:', err);
    res.status(500).json({ message: err.message }); 
  }
};

// AJOUTEZ cette fonction dans produitController.js
const getProductImages = async (req, res) => {
  try {
    console.log('🖼️ Récupération images du produit:', req.params.id);
    
    const produit = await Produit.findByPk(req.params.id, {
      include: [
        { 
          model: Image, 
          as: 'images',
          attributes: ['id', 'path', 'legende', 'produitId'] // Sélectionner seulement les champs nécessaires
        }
      ]
    });
    
    if (!produit) {
      console.log('❌ Produit non trouvé:', req.params.id);
      return res.status(404).json({ message: 'Produit non trouvé' });
    }

    console.log(`✅ ${produit.images.length} image(s) trouvée(s) pour le produit ${produit.id}`);
    
    res.json({
      success: true,
      data: produit.images,
      count: produit.images.length
    });
    
  } catch (err) { 
    console.error('❌ Erreur récupération images:', err);
    res.status(500).json({ 
      success: false,
      message: err.message 
    }); 
  }
};



module.exports = { getPlusNotes, getProductImages, getPlusPopulaires, getAll, getById, create, update, remove, uploadImage, deleteImage };
