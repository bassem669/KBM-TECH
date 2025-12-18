// routes/categories.js
const express = require('express');
const router = express.Router();
const { compare } = require('../controllers/comparisantController');
const { authenticate } = require('../middleware/auth');

router.get('/', compare);



module.exports = router;