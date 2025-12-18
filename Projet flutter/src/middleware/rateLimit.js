// middleware/rateLimit.js
const rateLimit = require('express-rate-limit');

const passwordResetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 3, // 3 tentatives max
  message: {
    message: 'Trop de tentatives de réinitialisation. Réessayez dans 15 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = { passwordResetLimiter };