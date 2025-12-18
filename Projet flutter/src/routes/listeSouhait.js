const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const controller = require('../controllers/listeSouhaitController');

// 🔒 Toutes les routes nécessitent un utilisateur connecté
router.use(authenticate);

router.post('/', controller.createListe);                  // créer une liste (si inexistante)
router.post('/add', controller.addProduit);                // ajouter produit à la liste
router.get('/', controller.getListe);                      // récupérer la liste de l’utilisateur
router.delete('/:produitId', controller.removeProduit);    // retirer un produit

module.exports = router;
