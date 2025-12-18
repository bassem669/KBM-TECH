// utils/bcrypt.js
const bcrypt = require('bcrypt');

const hashPassword = async (password) => await bcrypt.hash(password, 10);
const comparePassword = async (password, hashed) => await bcrypt.compare(password, hashed);

module.exports = { hashPassword, comparePassword };