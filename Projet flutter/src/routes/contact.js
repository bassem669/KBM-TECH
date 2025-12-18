const express = require('express');
const router = express.Router();
const contactController = require('../controllers/contactController');
const { authenticate, isAdmin } = require('../middleware/auth');

// Créer un contact (visiteur ou utilisateur connecté)
router.post('/', authenticate.optional, contactController.createContact);

// 🔒 Routes admin pour gérer les contacts
router.use(authenticate); // token requis
router.use(isAdmin);       // rôle admin uniquement

router.get('/', contactController.getAllContacts);
router.get('/:id', contactController.getContactById);
router.put('/:id', contactController.updateContact);
router.delete('/:id', contactController.deleteContact);

module.exports = router;
