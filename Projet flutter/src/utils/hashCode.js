const crypto = require('crypto');

const hashResetCode = (code) => {
  return crypto.createHash('sha256').update(code.toString()).digest('hex');
}

module.exports = hashResetCode;