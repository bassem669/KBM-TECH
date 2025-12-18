const Contact = require('../models/Contact');
const Utilisateur = require('../models/Utilisateur');

// ✅ Créer un contact (visiteur ou utilisateur connecté)
const createContact = async (req, res) => {
  const { titre, email,message } = req.body;
  try {
    const contact = await Contact.create({
      titre,
      email,
      message,
      utilisateur_id: req.user ? req.user.id : null
    });
    res.status(201).json(contact);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// ✅ Récupérer tous les contacts (admin)
const getAllContacts = async (req, res) => {
  try {
    const contacts = await Contact.findAll({
      include: [{ model: Utilisateur, as: 'client', attributes: ['nom', 'prenom', 'email'] }],
      order: [['date_contact', 'DESC']]
    });
    res.json(contacts);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Récupérer un contact par id
const getContactById = async (req, res) => {
  try {
    const contact = await Contact.findByPk(req.params.id, {
      include: [{ model: Utilisateur, as: 'client', attributes: ['nom', 'prenom', 'email'] }]
    });
    if (!contact) return res.status(404).json({ message: 'Contact non trouvé' });
    res.json(contact);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Supprimer un contact
const deleteContact = async (req, res) => {
  try {
    const contact = await Contact.findByPk(req.params.id);
    if (!contact) return res.status(404).json({ message: 'Contact non trouvé' });
    await contact.destroy();
    res.json({ message: 'Contact supprimé' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Mettre à jour un contact (par exemple titre ou message)
const updateContact = async (req, res) => {
  try {
    const contact = await Contact.findByPk(req.params.id);
    if (!contact) return res.status(404).json({ message: 'Contact non trouvé' });

    const { titre, message, etat } = req.body;
    if (etat && !['nouveau', 'en cours', 'resolu', 'ferme'].includes(etat)) {
      return res.status(400).json({ message: 'État invalide' });
    }

    await contact.update({ titre, message, etat });
    res.json(contact);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};


module.exports = {
  createContact,
  getAllContacts,
  getContactById,
  deleteContact,
  updateContact
};
