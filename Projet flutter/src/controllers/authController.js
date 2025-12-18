// controllers/authController.js
const hashResetCode = require('./../utils/hashCode');
const Utilisateur = require('./../models/Utilisateur');
const { hashPassword, comparePassword } = require('../utils/bcrypt');
const jwt = require('jsonwebtoken');
require('dotenv').config();
const { sendResetEmail } = require('./../utils/emailService.js');
const { Op } = require('sequelize');

const register = async (req, res) => {
  const { nom, prenom, email, motDePass, tel, adresse } = req.body;
  try {
    if (await Utilisateur.findOne({ where: { email } })) {
      return res.status(400).json({ message: 'Email déjà utilisé' });
    }
    const hashed = await hashPassword(motDePass.trim());
    const user = await Utilisateur.create({ nom, prenom, email, motDePass: hashed, tel, adresse });
    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ token, user: { id: user.id, nom, prenom, email } });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const login = async (req, res) => {
  const { email, motDePass } = req.body;
  try {
    const user = await Utilisateur.findOne({ where: { email } });
    const isValid = user && await comparePassword(motDePass.trim(), user.motDePass);
    if (!isValid) {
      return res.status(400).json({ message: 'Identifiants incorrects' });
    }
    const token = jwt.sign({ id: user.id, role: String(user.role) }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, user: { id: user.id, nom: user.nom, prenom: user.prenom, email } });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const réinitialisationMotDePass = async (req, res) => {
  try {
    const { email } = req.body;
    
    const utilisateur = await Utilisateur.findOne({ where: { email } });
    
    // Réponse générique dans tous les cas pour la sécurité
    if (!utilisateur) {
      return res.json({
        success: true,
        message: 'Si un compte existe avec cet email, un lien de réinitialisation a été envoyé'
      });
    }

    const code = Math.floor(100000 + Math.random() * 900000);
    // Générer token

    const resetCodeHash = hashResetCode(code);
    
    // Mettre à jour l'utilisateur avec Sequelize
    await Utilisateur.update(
      {
        resetPasswordCode: resetCodeHash,
        resetPasswordExpires: new Date(Date.now() + 30 * 60 * 1000) // 30 minutes
      },
      { where: { id: utilisateur.id } }
    );

    try {
      await sendResetEmail(utilisateur.email, code);
    } catch (emailError) {
      // Si l'email échoue, annuler le token pour éviter un état incohérent
      await Utilisateur.update(
        {
          resetPasswordCode: null,
          resetPasswordExpires: null
        },
        { where: { id: utilisateur.id } }
      );
      throw new Error('Échec de l\'envoi de l\'email de réinitialisation');
    }

    res.json({
      success: true,
      message: 'Si un compte existe avec cet email, un lien de réinitialisation a été envoyé'
    });

  } catch (error) {
    console.error('Erreur dans forgot-password:', error);
    res.status(500).json({ 
      success: false,
      error: 'Erreur serveur lors de la demande de réinitialisation' 
    });
  }
};

const verifierCode = async (req, res) => {
  try {
    const { code } = req.body; // ✅ Seulement le code maintenant
    
    if (!code) {
      return res.status(400).json({
        success: false,
        error: 'Code requis'
      });
    }
    
    const resetCodeHash = hashResetCode(code);
    
    // Rechercher l'utilisateur par le code hash uniquement
    const utilisateur = await Utilisateur.findOne({
      where: {
        resetPasswordCode: resetCodeHash,
        resetPasswordExpires: { [Op.gt]: new Date() }
      }
    });

    if (!utilisateur) {
      return res.status(400).json({ 
        success: false,
        error: 'Code de réinitialisation invalide ou expiré' 
      });
    }

    res.json({ 
      success: true, 
      valid: true,
      email: utilisateur.email, // On retourne l'email pour l'étape suivante
      prenom: utilisateur.prenom 
    });
  } catch (error) {
    console.error('Erreur dans verify-reset-code:', error);
    res.status(500).json({ 
      success: false,
      error: 'Erreur serveur lors de la vérification du code' 
    });
  }
};

const resetMotDePass = async (req, res) => {
  try {
    const { code, newPassword } = req.body;

    const resetCodeHash = hashResetCode(code);
    
    const utilisateur = await Utilisateur.findOne({
      where: {
        resetPasswordCode: resetCodeHash,
        resetPasswordExpires: { [Op.gt]: new Date() }
      }
    });

    if (!utilisateur) {
      return res.status(400).json({ 
        success: false,
        error: 'Lien de réinitialisation invalide ou expiré' 
      });
    }

    const isSamePassword = await comparePassword(newPassword, utilisateur.motDePass);
    if (isSamePassword) {
      return res.status(400).json({
        success: false,
        error: 'Le nouveau mot de passe doit être différent de l\'ancien'
      });
    }

    const motDePassHashed = await hashPassword(newPassword);
    // Mettre à jour le mot de passe (le hook beforeSave hash automatiquement)
    await Utilisateur.update(
      {
        motDePass: motDePassHashed,
        resetPasswordCode: null,
        resetPasswordExpires: null
      },
      { where: { id: utilisateur.id } }
    );

    res.json({ 
      success: true, 
      message: 'Mot de passe réinitialisé avec succès' 
    });

  } catch (error) {
    console.error('Erreur dans reset-password:', error);
    res.status(500).json({ 
      success: false,
      error: 'Erreur serveur lors de la réinitialisation' 
    });
  }
};

module.exports = { register, login, réinitialisationMotDePass, verifierCode, resetMotDePass };