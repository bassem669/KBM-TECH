// routes/commandes.js
const express = require('express');
const router = express.Router();
const { getUserCommandes, create, getAllCommande, getDetailsCommande, updateCommande } = require('../controllers/commandeController');
const { authenticate, isAdmin } = require('../middleware/auth');
const validate = require('../middleware/validate');
const Joi = require('joi');


const schema = Joi.object({
  lignes: Joi.array().items(
    Joi.object({
      produitId: Joi.number().required(),
      quantite: Joi.number().integer().min(1).required()
    })
  ).min(1).required()
});

router.get('/mes-commandes', authenticate, getUserCommandes);
router.post('/', authenticate, validate(schema), create);

router.use(authenticate);        
router.use(isAdmin);    

router.get('/', getAllCommande);
router.get('/:id', getDetailsCommande);
router.put('/:id', updateCommande);


module.exports = router;