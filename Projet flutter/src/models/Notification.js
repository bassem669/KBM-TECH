const { DataTypes, Model } = require('sequelize');
const sequelize = require('../config/db-sequelize');

class Notification extends Model {
  // Méthode pour marquer comme lu
  markAsRead() {
    return this.update({ isRead: true });
  }
}

Notification.init(
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    type: {
      type: DataTypes.ENUM('low_stock', 'new_order', 'system'),
      allowNull: false
    },
    title: {
      type: DataTypes.STRING,
      allowNull: false
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: false
    },
    data: {
      type: DataTypes.JSON,
      allowNull: true
    },
    recipientId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      field: 'recipient_id'
    },
    isRead: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      field: 'is_read'
    },
    priority: {
      type: DataTypes.ENUM('low', 'medium', 'high'),
      defaultValue: 'medium'
    }
  }, 
  {
    sequelize,
    modelName: 'Notification',
    tableName: 'notifications',
    timestamps: true
  }
);

// ✅ Méthode pour créer une notification de stock faible
Notification.createLowStockNotification = async function(produit) {
  try {
    // Vérifier si une notification similaire existe déjà récemment
    const existingNotification = await this.findOne({
      where: {
        type: 'low_stock',
        'data.productId': produit.id,
        createdAt: {
          [sequelize.Sequelize.Op.gte]: new Date(new Date() - 24 * 60 * 60 * 1000)
        }
      }
    });

    if (!existingNotification) {
      return await this.create({
        type: 'low_stock',
        title: 'Stock faible',
        message: `Le produit "${produit.nom}" a un stock faible (${produit.quantite} unités restantes)`,
        data: {
          productId: produit.id,
          productName: produit.nom,
          currentQuantity: produit.quantite,
          threshold: produit.lowStockThreshold || 10
        },
        priority: 'high'
      });
    }
  } catch (error) {
    console.error('Erreur création notification stock faible:', error);
  }
};

// ✅ Méthode pour créer une notification de nouvelle commande
Notification.createNewOrderNotification = async function(commande) {
  try {
    return await this.create({
      type: 'new_order',
      title: 'Nouvelle commande',
      message: `Une nouvelle commande #${commande.id} a été passée`,
      data: {
        commandeId: commande.id,
        clientId: commande.clientId,
        dateCommande: commande.date_commande
      },
      priority: 'medium'
    });
  } catch (error) {
    console.error('Erreur création notification nouvelle commande:', error);
  }
};


// Méthode pour marquer comme lu
Notification.prototype.markAsRead = async function() {
  this.isRead = true;
  return await this.save();
};

// Méthode statique pour récupérer les non lues
Notification.getUnread = async function() {
  return await this.findAll({
    where: { isRead: false },
    order: [['createdAt', 'DESC']]
  });
};

module.exports = Notification;