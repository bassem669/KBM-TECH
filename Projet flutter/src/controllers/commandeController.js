// controllers/commandeController.js
const { Commande, LigneCommande, Produit, Utilisateur, sequelize, Image, UserDevice, Notification } = require('../models');
const { Op } = require('sequelize');
const { sendNotification, generateNotificationMessage } = require('../utils/sendFCM');
const { checkLowStockAfterOrder } = require('../middleware/notifications');
const getUserCommandes = async (req, res) => {
  try {
    const commandes = await Commande.findAll({
      where: { clientId: req.user.id },
      include: [
        {
          model: LigneCommande,
          as: 'lignes',
          include: [
            {
              model: Produit,
              as: 'produit',
              include: [
                {
                  model: Image,
                  as: 'images',
                }
              ]
            }
          ]
        },
        {
          model: Utilisateur,
          as: 'client',
          attributes: ['nom', 'prenom']
        }
      ],
      order: [['date_commande', 'DESC']]
    });

    res.json(commandes);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


const create = async (req, res) => {
  const { lignes } = req.body;
  const transaction = await sequelize.transaction();

  try {
    const produitsMap = new Map();
    for (const ligne of lignes) {
      const produit = await Produit.findByPk(ligne.produitId, { transaction });
      if (!produit) throw new Error(`Produit ${ligne.produitId} introuvable`);
      if (produit.quantite < ligne.quantite) throw new Error(`Stock insuffisant pour ${produit.nom}`);
      produitsMap.set(ligne.produitId, produit);
    }

    const commande = await Commande.create({
      clientId: req.user.id,
      date_commande: new Date(),
      etat: 'en_attente'
    }, { transaction });

    const lignesData = lignes.map(l => ({
      commandeId: commande.id,
      produitId: l.produitId,
      quantite: l.quantite
    }));

    await LigneCommande.bulkCreate(lignesData, { transaction });

    // Mise à jour stock et nbQteAchat
    for (const ligne of lignes) {
      await Produit.decrement('quantite', { by: ligne.quantite, where: { id: ligne.produitId }, transaction });
      await Produit.increment('nbQteAchat', { by: ligne.quantite, where: { id: ligne.produitId }, transaction });
    }

    // 🔹 Mise à jour du nombre de commandes pour l'utilisateur
    await Utilisateur.increment('nb_commande', { by: 1, where: { id: req.user.id }, transaction });

    await transaction.commit();

    // Notifications
    Notification.createNewOrderNotification(commande);

    const admins = await Utilisateur.findAll({
      where: { role: 'admin' },
      include: [{ model: UserDevice, as: 'devices' }]
    });

    const adminTokens = admins.flatMap(a => a.devices).map(d => d.fcm_token).filter(Boolean);
    if (adminTokens.length) {
      const notif = await sendNotification(adminTokens,
        "Nouvelle commande",
        `Une nouvelle commande #${commande.id} a été passée.`,
        { type: "new_order", commandeId: String(commande.id) }
      );

      // Supprimer tokens invalides
      if (notif.failureCount > 0) {
        const invalidTokens = [];
        notif.responses.forEach((r, i) => {
          if (!r.success) invalidTokens.push(adminTokens[i]);
        });
        if (invalidTokens.length) await UserDevice.destroy({ where: { fcm_token: invalidTokens } });
      }
    }

    // Notifications stock faible
    for (const ligne of lignes) {
      const produit = produitsMap.get(ligne.produitId);
      checkLowStockAfterOrder(req, res, () => {});
      if (produit && produit.isLowStock()) {
        if (adminTokens.length) {
          await sendNotification(adminTokens,
            "Stock faible",
            `Le produit "${produit.nom}" est faible (${produit.quantite} restants).`,
            { type: "low_stock", produitId: String(produit.id) }
          );
        }
      }
    }

    res.status(201).json({ success: true, message: "Commande passée", commandeId: commande.id });

  } catch (err) {
    await transaction.rollback();
    console.error('Erreur création commande:', err);
    res.status(500).json({ message: err.message });
  }
};



const getAllCommande = async (req, res) => {
  try {
    const commandes = await Commande.findAll({
      include: [
        {
          model: LigneCommande,
          as: 'lignes',
          include: [{
            model: Produit,
            as: 'produit'
          }]
        },
        {
          model: Utilisateur, // CORRIGÉ : Utilisateur au lieu de Client
          as: 'client',
          attributes: ['nom', 'prenom']
        }
      ],
      order: [['date_commande', 'DESC']]
    });

    res.json(commandes);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getDetailsCommande = async (req, res) => {
  try {
    const commande = await Commande.findByPk(req.params.id, {
      include: [
        {
          model: LigneCommande,
          as: 'lignes',
          include: [{
            model: Produit,
            as: 'produit'
          }]
        },
        {
          model: Utilisateur, // CORRIGÉ : Utilisateur au lieu de Client
          as: 'client',
          attributes: ['nom', 'prenom']
        }
      ]
    });

    if (!commande) {
      return res.status(404).json({ message: 'Commande non trouvée' });
    }

    res.json(commande);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const updateCommande = async (req, res) => {
  const transaction = await sequelize.transaction();

  try {
    const { id } = req.params;
    const { etat } = req.body;

    const etatsValides = ['en_attente', 'confirmee', 'expediee', 'expédiée', 'livree'];
    if (!etatsValides.includes(etat)) {
      await transaction.rollback();
      return res.status(400).json({ message: `État invalide: ${etatsValides.join(', ')}` });
    }

    const commande = await Commande.findByPk(id, {
      transaction,
      include: [
        {
          model: Utilisateur,
          as: 'client',
          include: [{ model: UserDevice, as: 'devices' }]
        }
      ]
    });

    if (!commande) {
      await transaction.rollback();
      return res.status(404).json({ message: 'Commande non trouvée' });
    }

    const ancienEtat = commande.etat;
    await commande.update({ etat }, { transaction });
    await transaction.commit();

    // 🔔 Notification au client
    if (commande.client?.devices?.length) {
      const clientTokens = commande.client.devices
        .map(d => d.fcm_token)
        .filter(Boolean);

      if (clientTokens.length) {
        try {
          const { title, body } = generateNotificationMessage(ancienEtat, etat, commande.id);

          const notif = await sendNotification(clientTokens, title, body, {
            type: "commande_status_update",
            commandeId: String(commande.id),
            ancienEtat,
            nouvelEtat: etat,
            screen: "commande_detail",
            timestamp: new Date().toISOString()
          });

          // Supprimer tokens invalides
          if (notif.failureCount > 0) {
            const invalidTokens = [];
            notif.responses.forEach((r, i) => {
              if (!r.success) invalidTokens.push(clientTokens[i]);
            });
            if (invalidTokens.length) {
              await UserDevice.destroy({ where: { fcm_token: invalidTokens } });
            }
          }

          console.log(`✅ Notification envoyée au client: ${etat}`);
        } catch (notifErr) {
          console.error('❌ Erreur notification client:', notifErr.message);
        }
      }
    }

    // Récupérer la commande mise à jour avec relations
    const commandeMiseAJour = await Commande.findByPk(id, {
      include: [
        { model: LigneCommande, as: 'lignes', include: [{ model: Produit, as: 'produit' }] },
        { model: Utilisateur, as: 'client', attributes: ['id', 'nom', 'prenom', 'email'] }
      ]
    });

    res.status(200).json({
      success: true,
      message: 'Commande mise à jour avec succès',
      commande: commandeMiseAJour,
      notification: { sent: true, message: `État changé de "${ancienEtat}" à "${etat}"` }
    });

  } catch (err) {
    await transaction.rollback();
    console.error('❌ Erreur mise à jour commande:', err);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour de la commande',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
};


module.exports = {
  getUserCommandes,
  create,
  updateCommande,
  getDetailsCommande,
  getAllCommande
};
