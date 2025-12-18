import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeviceAPI {
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.25:5000/api';

  
  static Future<String?> getFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Demander permission (iOS)
    await messaging.requestPermission();

    // Récupérer le token
    String? token = await messaging.getToken();
    print("🔑 Token FCM: $token");

    return token;
  }

  static Future registerDevice({
    required String fcmToken,
    required String deviceType,
    int? userId,
    String? tempId,
  }) async {

    final url = Uri.parse("$baseUrl/device/register");

    final body = {
      "fcm_token": fcmToken,
      "device_type": deviceType,
      "user_id": userId,
      "temp_id": tempId,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("📩 registerDevice => ${response.body}");
    return jsonDecode(response.body);
  }

  static Future getUserDevices(int userId) async {

    final url = Uri.parse("$baseUrl/device/user/$userId");

    final response = await http.get(url);

    print("📩 getUserDevices => ${response.body}");
    return jsonDecode(response.body);
  }

  static Future deleteDevice(String fcmToken) async {
    const String baseUrl = "http://10.0.2.2:3000";

    final url = Uri.parse("$baseUrl/device/$fcmToken");

    final response = await http.delete(url);

    print("🗑 deleteDevice => ${response.body}");
    return jsonDecode(response.body);
  }

  static assignDeviceToUser({
    required String? fcmToken,
    required int userId,
  }) async {
    final url = Uri.parse("$baseUrl/device/assign");

    final body = {
      "fcm_token": fcmToken,
      "user_id": userId,
    };

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("📩 assignDeviceToUser => ${response.body}");
    return jsonDecode(response.body);
  }


}