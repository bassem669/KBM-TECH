// controllers/avisController.js
const { Avis, Produit, Utilisateur } = require('../models');

// Créer un avis
// controllers/avisController.js
const create = async (req, res) => {
  const { produit_id, message, note } = req.body;
  
  // Validation des données
  if (!produit_id || !message || note === undefined) {
    return res.status(400).json({ message: 'Données manquantes' });
  }

  if (note < 1 || note > 5) {
    return res.status(400).json({ message: 'La note doit être entre 1 et 5' });
  }

  try {
    // Vérifier si l'utilisateur a déjà posté un avis pour ce produit
    const existingAvis = await Avis.findOne({
      where: { 
        produit_id, 
        client_id: req.user.id 
      }
    });

    if (existingAvis) {
      return res.status(400).json({ 
        message: 'Vous avez déjà posté un avis pour ce produit' 
      });
    }

    const produit = await Produit.findByPk(produit_id);
    if (!produit) {
      return res.status(404).json({ message: 'Produit non trouvé' });
    }

    const avis = await Avis.create({
      produit_id,
      client_id: req.user.id,
      message: message.trim(),
      note,
      date_avis: new Date()
    });

    // Charger les relations pour la réponse
    const avisWithRelations = await Avis.findByPk(avis.id, {
      include: [
        {
          model: Utilisateur,
          as: 'client',
          attributes: ['id', 'nom', 'prenom']
        }
      ]
    });

    res.status(201).json(avisWithRelations);
  } catch (err) {
    console.error('Erreur création avis:', err);
    res.status(500).json({ message: 'Erreur serveur' });
  }
};

// Récupérer tous les avis d'un produit
const getByProduit = async (req, res) => {
  const { produit_id } = req.params;
  
  try {
    const produit = await Produit.findByPk(produit_id);
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });

    const avis = await Avis.findAll({
      where: { produit_id },
      include: [
        {
          model: Utilisateur,
          as : 'client',
          attributes: ['id', 'nom', 'prenom'] // Inclure les infos du client
        }
      ],
      order: [['date_avis', 'DESC']] // Trier par date décroissante
    });

    res.status(200).json(avis);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// Récupérer un avis spécifique
const getOne = async (req, res) => {
  const { id } = req.params;
  
  try {
    const avis = await Avis.findByPk(id, {
      include: [
        {
          model: Client,
          attributes: ['id', 'nom', 'prenom']
        },
        {
          model: Produit,
          attributes: ['id', 'nom']
        }
      ]
    });

    if (!avis) return res.status(404).json({ message: 'Avis non trouvé' });

    res.status(200).json(avis);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// Modifier un avis
const update = async (req, res) => {
  const { id } = req.params;
  const { message, note } = req.body;

  // Validation
  if (!message && note === undefined) {
    return res.status(400).json({ message: 'Aucune donnée à modifier' });
  }

  if (note && (note < 1 || note > 5)) {
    return res.status(400).json({ message: 'La note doit être entre 1 et 5' });
  }

  try {
    const avis = await Avis.findByPk(id);
    
    if (!avis) {
      return res.status(404).json({ message: 'Avis non trouvé' });
    }

    // Vérifier que l'utilisateur est le propriétaire de l'avis
    if (avis.client_id !== req.user.id) {
      return res.status(403).json({ 
        message: 'Non autorisé à modifier cet avis' 
      });
    }

    // Vérifier le délai de modification (ex: 24h)
    const delaiModification = 24 * 60 * 60 * 1000; // 24h en millisecondes
    const delaiEcoule = new Date() - new Date(avis.date_avis);
    
    if (delaiEcoule > delaiModification) {
      return res.status(400).json({ 
        message: 'Impossible de modifier l\'avis après 24h' 
      });
    }

    // Préparer les modifications
    const updates = {};
    if (message !== undefined) updates.message = message.trim();
    if (note !== undefined) updates.note = note;
    updates.date_modification = new Date();

    await avis.update(updates);

    // Recharger avec les relations pour la réponse
    const avisModifie = await Avis.findByPk(id, {
      include: [
        {
          model: Utilisateur,
          as: 'client',
          attributes: ['id', 'nom', 'prenom']
        }
      ]
    });

    res.status(200).json(avisModifie);
  } catch (err) {
    console.error('Erreur modification avis:', err);
    res.status(500).json({ message: 'Erreur lors de la modification' });
  }
};

// Supprimer un avis
const remove = async (req, res) => {
  const { id } = req.params;
  
  try {
    const avis = await Avis.findByPk(id);
    
    if (!avis) {
      return res.status(404).json({ message: 'Avis non trouvé' });
    }

    // Vérifier les permissions
    const isOwner = avis.client_id === req.user.id;
    const isAdmin = req.user.isAdmin || req.user.role === 'admin';
    
    if (!isOwner && !isAdmin) {
      return res.status(403).json({ 
        message: 'Non autorisé à supprimer cet avis' 
      });
    }

    await avis.destroy();
    
    res.status(200).json({ 
      message: 'Avis supprimé avec succès',
      avisId: id 
    });
  } catch (err) {
    console.error('Erreur suppression avis:', err);
    res.status(500).json({ message: 'Erreur lors de la suppression' });
  }
};


// Récupérer l'avis de l'utilisateur connecté pour un produit spécifique
const getMyAvisForProduct = async (req, res) => {
  const { produit_id } = req.params;
  
  try {
    const avis = await Avis.findOne({
      where: { 
        produit_id, 
        client_id: req.user.id 
      }
    });

    res.status(200).json(avis); // Retourne null si pas d'avis
  } catch (err) {
    console.error('Erreur récupération avis produit:', err);
    res.status(500).json({ message: 'Erreur serveur' });
  }
};

module.exports = {
  create,
  getByProduit,
  getOne,
  update,
  remove,
  getMyAvisForProduct
};