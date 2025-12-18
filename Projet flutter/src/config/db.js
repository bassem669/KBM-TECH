const mysql = require('mysql2');

// Créer une connexion à la base de données
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT,
});

// Connecter à la base
db.connect((err) => {
  if (err) {
    console.error('❌ Erreur de connexion à MySQL :', err.message);
    process.exit(1);
  } else {
    console.log('✅ Connexion à MySQL réussie');
  }
});

module.exports = db;
