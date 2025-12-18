// routes/avis.js
const express = require('express');
const router = express.Router();
const avisController = require('../controllers/avisController');
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validate');
const Joi = require('joi');

const schema = Joi.object({
  produit_id: Joi.number().required(),
  message: Joi.string().required(),
  note: Joi.number().min(1).max(5).required()
});

router.get('/produit/:produit_id', avisController.getByProduit);
router.post('/', authenticate, validate(schema), avisController.create);


router.get('/:id', avisController.getOne);
router.put('/:id', authenticate, avisController.update);
router.delete('/:id', authenticate, avisController.remove);
router.get('/produit/:produit_id/mon-avis', authenticate, avisController.getMyAvisForProduct);


module.exports = router;