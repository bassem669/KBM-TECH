const { ListeSouhait, Produit, Utilisateur } = require('../models');

// ✅ Créer une liste de souhait (si elle n’existe pas déjà)
const createListe = async (req, res) => {
  try {
    const userId = req.user ? req.user.id : null; // si connecté
    const liste = await ListeSouhait.create({ client_id: userId });
    res.status(201).json(liste);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Ajouter un produit à la liste
const addProduit = async (req, res) => {
  try {
    const { produitId } = req.body;
    const userId = req.user ? req.user.id : null;

    let liste = await ListeSouhait.findOne({ where: { client_id: userId } });
    if (!liste) liste = await ListeSouhait.create({ client_id: userId });

    const produit = await Produit.findByPk(produitId);
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });

    await liste.addProduit(produit);
    res.json({ message: 'Produit ajouté à la liste de souhaits' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Récupérer la liste de souhaits d’un utilisateur
const getListe = async (req, res) => {
  try {
    const userId = req.user ? req.user.id : null;

    const liste = await ListeSouhait.findOne({
      where: { client_id: userId },
      include: [{ model: Produit }]
    });

    if (!liste) return res.status(404).json({ message: 'Aucune liste trouvée' });

    res.json(liste);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Supprimer un produit de la liste
const removeProduit = async (req, res) => {
  try {
    const userId = req.user ? req.user.id : null;
    const { produitId } = req.params;

    const liste = await ListeSouhait.findOne({ where: { client_id: userId } });
    if (!liste) return res.status(404).json({ message: 'Liste non trouvée' });

    const produit = await Produit.findByPk(produitId);
    if (!produit) return res.status(404).json({ message: 'Produit non trouvé' });

    await liste.removeProduit(produit);
    res.json({ message: 'Produit retiré de la liste de souhaits' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { createListe, addProduit, getListe, removeProduit };
