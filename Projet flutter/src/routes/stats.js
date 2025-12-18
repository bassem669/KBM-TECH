const express = require('express');
const router = express.Router();
const { getStats } = require('../controllers/statsController.js');
const { authenticate, isAdmin } = require('../middleware/auth');

router.use(authenticate);        // Toutes les routes suivantes nécessitent un token
router.use(isAdmin);  

router.get("/", getStats);

module.exports = router;  // ✅ OBLIGATOIRE
