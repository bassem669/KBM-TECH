// utils/notifyAdmin.js
const { UserDevice } = require('../models');
const { sendNotification } = require('./sendFCM');

exports.notifyAdmins = async (title, body, data) => {
  const admins = await Utilisateur.findAll({
    where: { role: "admin" },
    include: [{ model: UserDevice, as: "devices" }]
  });

  const tokens = admins.flatMap(a => a.devices).map(d => d.fcm_token).filter(Boolean);
  if (!tokens.length) return;

  const notif = await sendNotification(tokens, title, body, data);

  // Supprimer tokens invalides
  if (notif.failureCount > 0) {
    const invalidTokens = [];
    notif.responses.forEach((r, i) => {
      if (!r.success) invalidTokens.push(tokens[i]);
    });
    if (invalidTokens.length > 0) {
      await UserDevice.destroy({ where: { fcm_token: invalidTokens } });
    }
  }
};
