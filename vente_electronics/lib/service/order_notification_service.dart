import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

@pragma('vm:entry-point')
class OrderNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    // Initialiser le plugin de notifications locales
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _setupNotificationChannels();
    _setupFirebaseHandlers();
    
    // Vérifier si l'app a été lancée via une notification
    await _checkInitialNotification();
  }

  // Vérifier si l'app a été lancée via une notification
  static Future<void> _checkInitialNotification() async {
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null) {
        print('App lancée via notification: $payload');
        // Traiter la notification initiale
        _handleNotificationPayload(payload);
      }
    }
  }

  // Gérer le tap sur une notification locale
  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _handleNotificationPayload(payload);
    }
  }

  // Traiter le payload de la notification
  static void _handleNotificationPayload(String payload) {
    try {
      // Le payload peut contenir des données JSON
      print('Notification tapped with payload: $payload');
      // Vous pouvez parser le payload et naviguer en conséquence
      // Exemple: final data = jsonDecode(payload);
    } catch (e) {
      print('Erreur lors du traitement du payload: $e');
    }
  }

  // ==========================
  //  Setup Channels Android
  // ==========================
  static void _setupNotificationChannels() {
    const AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
      'new_order_channel',
      'Nouvelles Commandes',
      description: 'Notifications pour les nouvelles commandes',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel stockChannel = AndroidNotificationChannel(
      'stock_alert_channel',
      'Alertes Stock',
      description: 'Stock faible',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
      'default_channel',
      'Notifications',
      description: 'Notifications par défaut',
      importance: Importance.high,
      playSound: true,
    );

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    android?.createNotificationChannel(orderChannel);
    android?.createNotificationChannel(stockChannel);
    android?.createNotificationChannel(defaultChannel);
  }

  // ==========================
  //  Firebase Handlers
  // ==========================
  static void _setupFirebaseHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('🔔 Background notification reçue: ${message.messageId}');
    print('   Titre: ${message.notification?.title}');
    print('   Corps: ${message.notification?.body}');
    print('   Data: ${message.data}');
    
    await _processNotification(message);
    await _showLocalNotification(message); // Afficher notification même en background
  }

  // ==========================
  //  Foreground Notifications
  // ==========================
  static Future<void> _handleForegroundNotification(RemoteMessage message) async {
    print('📱 Foreground notification reçue: ${message.messageId}');
    print('   Titre: ${message.notification?.title}');
    print('   Corps: ${message.notification?.body}');
    
    await _showLocalNotification(message);
    _showInAppNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] ?? 'default';

    final androidDetails = AndroidNotificationDetails(
      type == 'new_order'
          ? 'new_order_channel'
          : type == 'low_stock'
              ? 'stock_alert_channel'
              : 'default_channel',
      'Notification',
      channelDescription: 'Messages importants',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      styleInformation: BigTextStyleInformation(
        message.notification?.body ?? '',
      ),
    );

    // ID unique pour éviter collisions
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notificationsPlugin.show(
      notificationId,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      NotificationDetails(android: androidDetails),
      payload: message.data.toString(),
    );
  }

  static void _showInAppNotification(RemoteMessage message) {
    final type = message.data['type'] ?? '';

    if (type == 'new_order' || type == 'low_stock') {
      Get.snackbar(
        message.notification?.title ?? 'Notification',
        message.notification?.body ?? '',
        backgroundColor:
            type == 'new_order' ? Colors.green : Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  // ==========================
  //  Notification tap
  // ==========================
  static void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] ?? '';
    print('👆 Notification tapped - Type: $type');

    if (type == 'new_order') {
      Get.toNamed('/admin/commandes');
    } else if (type == 'low_stock') {
      Get.toNamed('/admin/products');
    } else {
      Get.toNamed('/admin/dashboard');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Notifications',
      channelDescription: 'Messages importants',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      styleInformation: BigTextStyleInformation(body),
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }


  // ==========================
  //  Background Processing
  // ==========================
  static Future<void> _processNotification(RemoteMessage message) async {
    print("Traitement en background → ${message.data}");
  }
}
