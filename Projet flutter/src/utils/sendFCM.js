const admin = require("firebase-admin");


exports.sendNotification = async (tokens, title, body, data = {}) => {
  if (!tokens || tokens.length === 0) return null;

  // Nettoyage des tokens
  const validTokens = tokens.filter(token => 
    token && typeof token === 'string' && token.length > 0
  );

  if (validTokens.length === 0) return null;

  const message = {
    tokens: validTokens,
    notification: {
      title,
      body
    },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'high_importance_channel'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default'
        }
      }
    }
  };


  try {
    // ✅ Utilisez sendEachForMulticast au lieu de sendMulticast
    const response = await admin.messaging().sendEachForMulticast(message);
    
    // Gestion des tokens invalides
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(validTokens[idx]);
          console.warn('FCM failed:', resp.error?.message || 'Unknown error');
          
          // Supprimer les tokens invalides spécifiques
          if (resp.error?.code === 'messaging/registration-token-not-registered') {
            console.log(`Token invalide à supprimer: ${validTokens[idx]}`);
            // Ici vous pouvez appeler une fonction pour supprimer le token de la BDD
            // await UserDevice.destroy({ where: { fcm_token: validTokens[idx] } });
          }
        }
      });
    }
    
    console.log(`Notifications envoyées: ${response.successCount}/${validTokens.length}`);
    return response;
  } catch (err) {
    console.error("FCM Error:", err.message);
    return null;
  }
};


exports.generateNotificationMessage = (ancienEtat, nouvelEtat, commandeId) => {
  const title = `Mise à jour de votre commande #${commandeId}`;

  let body = '';
  switch (nouvelEtat) {
    case 'en_attente':
      body = `Votre commande #${commandeId} est maintenant en attente.`;
      break;
    case 'confirmee':
      body = `Bonne nouvelle ! Votre commande #${commandeId} a été confirmée.`;
      break;
    case 'expediee':
    case 'expédiée':
      body = `Votre commande #${commandeId} a été expédiée.`;
      break;
    case 'livree':
      body = `Votre commande #${commandeId} a été livrée.`;
      break;
    default:
      body = `L'état de votre commande #${commandeId} a changé de "${ancienEtat}" à "${nouvelEtat}".`;
      break;
  }

  return { title, body };
}