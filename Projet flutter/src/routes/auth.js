// routes/auth.js
const express = require('express');
const router = express.Router();
const { register, login, réinitialisationMotDePass, verifierCode, resetMotDePass } = require('../controllers/authController');
const validate = require('../middleware/validate');
const Joi = require('joi');
const { sendResetEmail } = require('../utils/emailService');
const { passwordResetLimiter } = require('../middleware/rateLimit');

const registerSchema = Joi.object({
  nom: Joi.string().required(),
  prenom: Joi.string().required(),
  email: Joi.string().email().required(),
  motDePass: Joi.string().min(6).required(),
  tel: Joi.string().optional(),
  adresse: Joi.string().optional()
});

const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  motDePass: Joi.string().required()
});


router.post('/register', validate(registerSchema), register);
router.post('/login', validate(loginSchema), login);

router.post('/forgot-password', passwordResetLimiter, réinitialisationMotDePass); //passwordResetLimiter
router.post('/verify-reset-code', verifierCode);
router.post('/reset-password', resetMotDePass);

module.exports = router;