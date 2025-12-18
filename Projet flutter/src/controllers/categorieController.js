// controllers/categorieController.js
const { Categorie } = require('../models');

// Récupérer toutes les catégories
const getAll = async (req, res) => {
  try {
    const categories = await Categorie.findAll();
    res.json(categories);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Créer une nouvelle catégorie
const create = async (req, res) => {
  const { nom } = req.body;
  try {
    const categorie = await Categorie.create({ nom });
    res.status(201).json(categorie);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// Modifier une catégorie
const update = async (req, res) => {
  const { id } = req.params;
  const { nom } = req.body;

  try {
    const categorie = await Categorie.findByPk(id);
    if (!categorie) {
      return res.status(404).json({ message: 'Catégorie non trouvée' });
    }

    categorie.nom = nom || categorie.nom;
    await categorie.save();

    res.json(categorie);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// Supprimer une catégorie
const remove = async (req, res) => {
  const { id } = req.params;

  try {
    const categorie = await Categorie.findByPk(id);
    if (!categorie) {
      return res.status(404).json({ message: 'Catégorie non trouvée' });
    }

    await categorie.destroy();
    res.json({ message: 'Catégorie supprimée avec succès' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getAll, create, update, remove };
