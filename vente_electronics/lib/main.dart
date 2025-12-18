import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vente_electronics/firebase_options.dart';
import './fetch/device_api.dart';
import 'utils/theme.dart';
import 'app_rotues.dart';
import 'fetch/panier_api.dart';
import 'fetch/liste_souhait_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service/order_notification_service.dart';

// Handler obligatoire pour les messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔔 Background message reçu dans main.dart: ${message.messageId}');
  
  // Déléguer au service de notification
  await OrderNotificationService.firebaseMessagingBackgroundHandler(message);
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialiser service notification
  OrderNotificationService.initialize();

  // Handler background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}


//https://phone-specs-explorer-api.p.rapidapi.com/2164/get%2Bphone%2Bdetails?phone_id=samsung_galaxy_s24_ultra
//x-rapidapi-host: phone-specs-explorer-api.p.rapidapi.com
//x-rapidapi-key: 3121a38062msh65e3161425751fdp1acfcdjsn35c4eaeef9a1
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    requestPermission();
    getFCMToken();
    listenFCMMessages();
  }

  void requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print(settings.authorizationStatus == AuthorizationStatus.authorized
        ? "Permission accordée"
        : "Permission refusée");
  }

  void getFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');

    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      String? userStr = prefs.getString("user");
      Map<String, dynamic>? user = userStr != null ? jsonDecode(userStr) : null;

      int? userId = user?["id"];
      String? tempId = prefs.getString('temp_id');

      String deviceType =
          Platform.isAndroid ? "android" : (Platform.isIOS ? "ios" : "unknown");

      await DeviceAPI.registerDevice(
        fcmToken: token,
        deviceType: deviceType,
        userId: userId,
        tempId: tempId,
      );
    }
  }

  void listenFCMMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("📱 Message reçu en foreground dans main.dart: ${message.notification?.title}");

      // Afficher notification locale
      await OrderNotificationService.showNotification(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (ctx, theme, _) => MaterialApp(
          title: 'KBM TECH',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          initialRoute: '/',
          routes: AppRoutes.getAllRoutes(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  void toggle() {
    _mode =
        _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
