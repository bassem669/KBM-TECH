🚀 KBM-TECH

KBM-TECH est une application e-commerce dédiée à la vente de produits électroniques.
Le projet a été développé par deux étudiants en utilisant Flutter pour le frontend et Node.js (Express.js) pour le backend.

✨ Fonctionnalités

🔔 Notifications push via Firebase Cloud Messaging (FCM)

🤖 Comparaison intelligente de deux produits électroniques grâce à l’API Gemini

📱 Interface utilisateur moderne et intuitive

🗄️ Base de données MySQL avec création automatique des tables au démarrage du backend via Sequelize

🛠️ Technologies utilisées
    Frontend
        - Flutter

    Backend
        - Node.js
        - Express.js
        - Sequelize (ORM)

    Base de données
        - MySQL
        - Nom de la base : VenteElectronique

    Services
        - Firebase Cloud Messaging (FCM)
        - API Gemini

▶️ Commandes de démarrage
    📱 Frontend (Flutter)
    cd vente_electronics
    flutter run

🌐 Backend (Node.js + Express + Sequelize)
    cd "Projet flutter"
    npm install
    node src/server.js


⚙️ Remarque :
- Au démarrage du backend, Sequelize synchronise automatiquement les modèles et crée les tables nécessaires dans la base de données VenteElectronique.

⚙️ Configuration de la base de données (Sequelize)

Assurez-vous que :

MySQL est en cours d’exécution

    Les paramètres de connexion (host, user, password, database) sont correctement configurés

    La base de données VenteElectronique existe avant le démarrage du serveur

    (Optionnel : configuration via un fichier .env)

👨‍💻 Auteurs

Projet développé par deux étudiants 
  - Bassem Mathlouthi 
  - Khaled Rouai
