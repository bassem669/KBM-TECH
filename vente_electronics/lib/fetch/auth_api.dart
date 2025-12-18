import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'device_api.dart';
class AuthAPI {
  static String baseUrl = dotenv.env['AUTH_URL'] ?? 'http://192.168.1.54:5000/api/auth';
   static const int timeoutSeconds = 30;

  static Future<String> registre(Map<String, String> data) async {
    print("🟢 Tentative de création du compte...");
    String erreur = "";

    final url = Uri.parse("$baseUrl/register");

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Compte créé avec succès !");
        print(response.body);
      } else {
        final body = jsonDecode(response.body);
        erreur = "Erreur : ${body["message"] ?? 'Une erreur est survenue.'}";
        print("❌ Erreur (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      erreur = "⚠️ Erreur de connexion : $e";
      print("⚠️ Erreur de connexion : $e");
    }

    return erreur;
  }

  static Future<String> login(Map<String, String> data) async {
  print("🟢 Tentative de connexion du compte...");
  String erreur = "";

  final url = Uri.parse("$baseUrl/login");

  try {
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Connexion réussie !");
      print("Response body: ${response.body}");

      // ⬇️ Décode d’abord
      final body = jsonDecode(response.body);

      // Token + user
      final String? token = body['token'];
      final Map<String, dynamic>? user = body['user'] != null
          ? Map<String, dynamic>.from(body['user'])
          : null;

      if (token != null && user != null) {
        // Sauvegarde localement
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user', jsonEncode(user));

        print("👤 Utilisateur connecté: ${user['prenom']} ${user['nom']}");

        // ⬇️ Maintenant tu peux associer le device !
        String? fcmTocken = await DeviceAPI.getFCMToken();
        await DeviceAPI.assignDeviceToUser(
          fcmToken: fcmTocken,
          userId: body['user']["id"],
        );


        print("📱 Device associé à l’utilisateur !");
      } else {
        erreur = "Erreur: Données de connexion manquantes dans la réponse";
        print("❌ $erreur");
      }
    } else {
      final body = jsonDecode(response.body);
      erreur = "Erreur : ${body["message"] ?? 'Une erreur est survenue.'}";
      print("❌ Erreur (${response.statusCode}): ${response.body}");
    }
  } catch (e) {
    erreur = "⚠️ Erreur de connexion : $e";
    print("⚠️ Erreur de connexion : $e");
  }
  return erreur;
}


  static Future<String> logout() async {
    print("🟢 Tentative de déconnexion...");
    String erreur = "";

    try {
      // Récupérer le token pour l'envoyer au serveur
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      // Si un token existe, appeler l'API de déconnexion
      if (token != null) { 
        // Nettoyer les données locales dans tous les cas
        await prefs.clear();
        print("✅ Déconnexion locale effectuée - données supprimées");       
          
      }
    } catch (e) {
      erreur = "⚠️ Erreur lors de la déconnexion : $e";
      print("❌ Erreur lors de la déconnexion : $e");
    }

    return erreur;
  }

  static Future<Map<String, dynamic>?> fetchUserProfile(String token) async {
    print("🟢 Chargement du profil utilisateur...");

    final url = Uri.parse("$baseUrl/utilisateurs/profil");

    try {
      final token = await AuthAPI.getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Profil chargé avec succès !");
        final body = jsonDecode(response.body);
        return body;
      } else {
        print("❌ Erreur (${response.statusCode}): ${response.body}");
        return null;
      }
    } catch (e) {
      print("⚠️ Erreur de connexion : $e");
      return null;
    }
  }

  static Future<String> updateUserProfile(Map<String, dynamic> data, String token) async {
    print("🟢 Mise à jour du profil...");
    String erreur = "";

    final url = Uri.parse("$baseUrl/utilisateurs/profil/update");

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Profil mis à jour avec succès !");
        
        // Update local user data if the update was successful
        final updatedUser = jsonDecode(response.body);
        if (updatedUser['user'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(updatedUser['user']));
          print("✅ Données utilisateur locales mises à jour");
        }
        
      } else {
        final body = jsonDecode(response.body);
        erreur = "Erreur : ${body["message"] ?? 'Une erreur est survenue.'}";
        print("❌ Erreur (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      erreur = "⚠️ Erreur de connexion : $e";
      print("⚠️ Erreur de connexion : $e");
    }

    return erreur;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('user');
    if (json != null) {
      try {
        return jsonDecode(json);
      } catch (e) {
        print("❌ Erreur lors du parsing des données utilisateur: $e");
        return null;
      }
    }
    return null;
  }



  /// 🔐 Mettre à jour le mot de passe de l'utilisateur
  static Future<Map<String, dynamic>> updatePassword(Map<String, dynamic> passwordData, String token) async {
  try {
    final response = await http.put(
      Uri.parse('$baseUrl/utilisateurs/password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(passwordData),
    );

    if (response.statusCode == 200) {
      return {'success': true};
    } else {
      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'error': errorData['message'] ?? 'Erreur lors de la mise à jour du mot de passe'
      };
    }
  } catch (e) {
    print('❌ Erreur updatePassword: $e');
    return {
      'success': false,
      'error': 'Erreur de connexion: $e'
    };
  }
  }



  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> verifyCode(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'code': code}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(
    String code,
    String newPassword,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'code': code,
        'newPassword': newPassword,
      }),
    );
    return json.decode(response.body);
  }
}