const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');

// Routes pour les notifications
router.get('/', notificationController.getAllNotifications);
router.get('/unread', notificationController.getUnreadNotifications);
router.get('/stats', notificationController.getNotificationStats);
router.get('/type/:type', notificationController.getNotificationsByType);

router.patch('/:id/read', notificationController.markAsRead);
router.patch('/read-all', notificationController.markAllAsRead);

router.delete('/:id', notificationController.deleteNotification);
router.get('/unread/count', notificationController.getUnreadCount);


module.exports = router;