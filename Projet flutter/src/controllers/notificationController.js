const { Notification } = require('../models');


exports.getUnreadCount = async (req, res) => {
  try {
    const unreadCount = await Notification.count({
      where: { isRead: false }
    });

    res.json({ unread: unreadCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getAllNotifications = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const { count, rows: notifications } = await Notification.findAndCountAll({
      order: [['createdAt', 'DESC']],
      limit: limit,
      offset: offset
    });

    res.json(notifications);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Récupérer les notifications par type avec pagination
exports.getNotificationsByType = async (req, res) => {
  try {
    const { type } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const { count, rows: notifications } = await Notification.findAndCountAll({
      where: { type },
      order: [['createdAt', 'DESC']],
      limit: limit,
      offset: offset
    });

    res.json(notifications);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Récupérer les notifications non lues avec pagination
exports.getUnreadNotifications = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const { count, rows: notifications } = await Notification.findAndCountAll({
      where: { isRead: false },
      order: [['createdAt', 'DESC']],
      limit: limit,
      offset: offset
    });

    res.json(notifications);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};


// Marquer une notification comme lue
exports.markAsRead = async (req, res) => {
  try {
    const notification = await Notification.findByPk(req.params.id);
    if (!notification) {
      return res.status(404).json({ error: 'Notification non trouvée' });
    }
    
    await notification.markAsRead();
    res.json(notification);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Marquer toutes les notifications comme lues
exports.markAllAsRead = async (req, res) => {
  try {
    await Notification.update(
      { isRead: true },
      { where: { isRead: false } }
    );
    res.json({ message: 'Toutes les notifications marquées comme lues' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};


// Supprimer une notification
exports.deleteNotification = async (req, res) => {
  try {
    const notification = await Notification.findByPk(req.params.id);
    if (!notification) {
      return res.status(404).json({ error: 'Notification non trouvée' });
    }
    
    await notification.destroy();
    res.json({ message: 'Notification supprimée avec succès' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Récupérer les statistiques des notifications
exports.getNotificationStats = async (req, res) => {
  try {
    const total = await Notification.count();
    const unread = await Notification.count({ where: { isRead: false } });
    const lowStockCount = await Notification.count({ where: { type: 'low_stock' } });
    const newOrderCount = await Notification.count({ where: { type: 'new_order' } });
    
    res.json({
      total,
      unread,
      lowStockCount,
      newOrderCount,
      read: total - unread
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};