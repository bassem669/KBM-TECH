const { UserDevice, Utilisateur } = require("../models");

// Enregistrer ou mettre à jour un token FCM
exports.registerDevice = async (req, res) => {
  try {
    const { fcm_token, device_type, user_id, temp_id } = req.body;

    if (!fcm_token) {
      return res.status(400).json({ error: "Le token FCM est obligatoire." });
    }

    // Vérifier si le token existe déjà
    let device = await UserDevice.findOne({ where: { fcm_token } });

    if (device) {
      // Mise à jour
      await device.update({
        device_type: device_type || device.device_type,
        user_id: user_id || device.user_id,
        temp_id: temp_id || device.temp_id,
      });

      return res.json({
        message: "Token mis à jour avec succès",
        device,
      });
    }

    // Création
    device = await UserDevice.create({
      fcm_token,
      device_type: device_type || "android",
      user_id: user_id || null,
      temp_id: temp_id || null,
    });

    return res.json({
      message: "Token enregistré avec succès",
      device,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Récupérer tous les tokens d’un user
exports.getUserDevices = async (req, res) => {
  try {
    const { user_id } = req.params;

    const devices = await UserDevice.findAll({
      where: { user_id },
    });

    res.json(devices);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Supprimer un device
exports.deleteDevice = async (req, res) => {
  try {
    const { fcm_token } = req.params;

    const device = await UserDevice.findOne({ where: { fcm_token } });
    if (!device) {
      return res.status(404).json({ error: "Device non trouvé" });
    }

    await device.destroy();

    res.json({ message: "Device supprimé avec succès" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Associer un device à un utilisateur authentifié
exports.assignToUser = async (req, res) => {
  try {
    const { fcm_token, user_id } = req.body;

    if (!fcm_token || !user_id) {
      return res.status(400).json({ error: "fcm_token et user_id obligatoires." });
    }

    const device = await UserDevice.findOne({ where: { fcm_token } });
    if (!device) {
      return res.status(404).json({ error: "Device non trouvé" });
    }

    await device.update({
      user_id,
      temp_id: null, // L’utilisateur n’est plus anonyme
    });

    res.json({ message: "Device associé à l’utilisateur.", device });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
