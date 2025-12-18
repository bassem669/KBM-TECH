// routes/categories.js
const express = require('express');
const router = express.Router();
const { getAll, create, update, remove } = require('../controllers/categorieController');
const { authenticate, isAdmin } = require('../middleware/auth');
const validate = require('../middleware/validate');
const Joi = require('joi');

const schema = Joi.object({ nom: Joi.string().required() });

router.get('/', getAll);


router.use(authenticate);        // Toutes les routes suivantes nécessitent un token
router.use(isAdmin);     // Et le rôle admin

router.post('/', validate(schema), create);
router.put('/:id', update);
router.delete('/:id', remove);


module.exports = router;