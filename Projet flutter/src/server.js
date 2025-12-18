// server.js
const express = require('express');
const sequelize = require('./config/db-sequelize');
require('dotenv').config();
const path = require('path'); // ✅ ajout essentiel
const admin = require("firebase-admin");
const serviceAccount = require("./firebaseServiceAccount.json");
const cors = require('cors');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const app = express();
app.use(express.json());
app.use(cors())

// 🧩 Middleware pour afficher le statut dans le terminal
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    console.log(`[${req.method}] ${req.originalUrl} - Status: ${res.statusCode} - ${Date.now() - start}ms`);
  });
  next();
});

// Routes
app.use('/api/notifications', require('./routes/notifications')); // Nouvelles routes
app.use('/api/stats', require('./routes/stats'));
app.use('/api/auth', require('./routes/auth'));
app.use('/api/produits', require('./routes/produits'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/commandes', require('./routes/commandes'));
app.use('/api/avis', require('./routes/avis'));
app.use('/api/auth/utilisateurs', require('./routes/utilisateurs'));
app.use('/api/promotions', require('./routes/promotions'));
app.use('/api/contact', require('./routes/contact'));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/api/listeSouhait', require('./routes/listeSouhait'));
app.use('/api/device', require('./routes/devices'));
app.use('/api/compare', require('./routes/comparisant'));



const PORT = process.env.PORT || 3000;

sequelize.sync({ alter: true }).then(() => {
  app.listen(PORT, () => console.log(`API en cours sur http://localhost:${PORT}`));
}).catch(err => console.error(err));