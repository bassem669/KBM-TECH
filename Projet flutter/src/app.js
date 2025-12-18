require('dotenv').config();

const path = require('path');

const express = require('express');


const sequelize = require('./config/db-sequelize');

const app = express();




// Middleware

app.use(express.json());

app.use('/images',express.static(path.join(__dirname, 'public/images')));

app.get('/test', (req, res) => {
  const imagePath = path.join(__dirname, 'public', 'images', '15pro.png');
  console.log('🔍 Checking file at:', imagePath);
  res.sendFile(imagePath);
});





// Route racine
app.get('/', (req, res) => {
  res.send('Serveur Express connecté à MySQL ✅');
});

// Synchroniser Sequelize et démarrer le serveur
sequelize.sync()
  .then(() => {
    console.log('✅ Tables synchronisées avec Sequelize');
    app.listen(3000, () => console.log('Server running on port 3000'));
  })
  .catch(err => console.error('❌ Erreur Sequelize sync:', err));

module.exports = app;
