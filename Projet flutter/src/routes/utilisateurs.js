// routes/utilisateurs.js
const express = require('express');
const router = express.Router();
const { getProfile, addToWishlist, updateRoleUtilisateur, getAllUtilisateur, deleteUtilisateur, updateProfile , updatePassword } = require('../controllers/utilisateurController');
const { authenticate, isAdmin } = require('../middleware/auth');
const validate = require('../middleware/validate');
const Joi = require('joi');

router.get('/profil', authenticate, getProfile);
router.put('/profil/update', authenticate, updateProfile);
router.put('/password', authenticate, updatePassword);


router.use(authenticate);        // Toutes les routes suivantes nécessitent un token
router.use(isAdmin);     // Et le rôle admin

router.put('/:id', updateRoleUtilisateur);
router.get('/', getAllUtilisateur);
router.delete('/:id', deleteUtilisateur);

module.exports = router;