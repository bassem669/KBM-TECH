// controllers/utilisateurController.js
const { Utilisateur, ListeSouhait, Produit } = require('../models');
const { hashPassword, comparePassword } = require('../utils/bcrypt');

const getProfile = async (req, res) => {
  try {
    const user = await Utilisateur.findByPk(req.user.id, {
      attributes: { exclude: ['motDePass'] }
    });
    res.json(user);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const getAllUtilisateur = async (req, res) => {
  try {
    const utilisateurs = await Utilisateur.findAll({
      attributes: ['id', 'nom', 'prenom', 'email', 'role', 'tel', 'nb_commande', 'adresse'],
    });

    res.status(200).json({
      total: utilisateurs.length,
      data: utilisateurs,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { prenom, nom, email, tel, adresse } = req.body;
    const userId = req.user.id;

    // Vérifier si l'utilisateur existe
    const utilisateur = await Utilisateur.findByPk(userId);
    if (!utilisateur) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }

    // Vérifier si l'email est déjà utilisé par un autre utilisateur
    if (email && email !== utilisateur.email) {
      const existingUser = await Utilisateur.findOne({ where: { email } });
      if (existingUser && existingUser.id !== userId) {
        return res.status(400).json({ message: 'Cet email est déjà utilisé' });
      }
    }

    // Préparer les données à mettre à jour
    const updateData = {};
    if (prenom !== undefined) updateData.prenom = prenom;
    if (nom !== undefined) updateData.nom = nom;
    if (email !== undefined) updateData.email = email;
    if (tel !== undefined) updateData.tel = tel;
    if (adresse !== undefined) updateData.adresse = adresse;

    // Mettre à jour l'utilisateur
    await Utilisateur.update(updateData, {
      where: { id: userId }
    });

    // Récupérer l'utilisateur mis à jour
    const updatedUser = await Utilisateur.findByPk(userId, {
      attributes: { exclude: ['motDePass'] }
    });

    res.status(200).json({
      success: true,
      message: 'Profil mis à jour avec succès',
      user: updatedUser
    });

  } catch (err) {
    console.error('Erreur lors de la mise à jour du profil:', err);
    res.status(500).json({ 
      success: false,
      message: 'Erreur lors de la mise à jour du profil',
      error: err.message 
    });
  }
};

const updatePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword, confirmPassword } = req.body;
    const userId = req.user.id;

    // Vérifier que tous les champs sont fournis
    if (!currentPassword || !newPassword || !confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Tous les champs sont obligatoires'
      });
    }

    // Vérifier que le nouveau mot de passe et la confirmation correspondent
    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Le nouveau mot de passe et la confirmation ne correspondent pas'
      });
    }


    // Récupérer l'utilisateur avec le mot de passe
    const utilisateur = await Utilisateur.findByPk(userId);
    if (!utilisateur) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    // Vérifier l'ancien mot de passe
    const isCurrentPasswordValid = await comparePassword(currentPassword, utilisateur.motDePass);
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        success: false,
        message: 'Le mot de passe actuel est incorrect'
      });
    }

    // Vérifier que le nouveau mot de passe est différent de l'ancien
    const isSamePassword = await comparePassword(newPassword, utilisateur.motDePass);
    if (isSamePassword) {
      return res.status(400).json({
        success: false,
        message: 'Le nouveau mot de passe doit être différent de l\'ancien'
      });
    }

    // Hasher le nouveau mot de passe
    const hashedNewPassword = await hashPassword(newPassword);

    // Mettre à jour le mot de passe
    await Utilisateur.update(
      { motDePass: hashedNewPassword },
      { where: { id: userId } }
    );

    res.status(200).json({
      success: true,
      message: 'Mot de passe mis à jour avec succès'
    });

  } catch (err) {
    console.error('Erreur lors de la mise à jour du mot de passe:', err);
    res.status(500).json({
      success: false,
      message: 'Erreur lors de la mise à jour du mot de passe',
      error: err.message
    });
  }
};

const deleteUtilisateur = async (req, res) => {
  try {
    const utilisateur = await Utilisateur.findByPk(req.params.id);
    if (!utilisateur) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }

    await utilisateur.destroy();
    res.status(200).json({ message: 'Utilisateur supprimé avec succès' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const updateRoleUtilisateur = async (req, res) => {
  try {
    const { role } = req.body;
    const utilisateur = await Utilisateur.findByPk(req.params.id);

    if (!utilisateur) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }

    // Vérification basique du rôle
    const rolesAutorises = ['admin', 'client', 'vendeur'];
    if (!rolesAutorises.includes(role)) {
      return res.status(400).json({ message: 'Rôle invalide' });
    }

    utilisateur.role = role;
    await utilisateur.save();

    res.status(200).json({
      message: 'Rôle mis à jour avec succès',
      utilisateur: {
        id: utilisateur.id,
        nom: utilisateur.nom,
        prenom: utilisateur.prenom,
        email: utilisateur.email,
        role: utilisateur.role,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { 
  getProfile, 
  getAllUtilisateur, 
  updateRoleUtilisateur, 
  deleteUtilisateur, 
  updateProfile,
  updatePassword 
};