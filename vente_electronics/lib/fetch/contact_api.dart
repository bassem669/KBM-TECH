// lib/services/contact_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './auth_api.dart';

class ContactService {
  static String baseUrl = dotenv.env['CONTACT_URL'] ?? 'http://192.168.1.54:5000/api/contact';


   static Future<String> sendContactMessage({
    required String titre,
    required String email,
    required String message,
  }) async {
    print("🟢 Tentative d'envoi de message de contact...");
    String erreur = "";

    try {
      // Récupérer le token si l'utilisateur est connecté
      final token = await AuthAPI.getToken();
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // Ajouter le token d'authentification si disponible
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = Uri.parse(baseUrl);
      final body = jsonEncode({
        'titre': titre,
        'email': email,
        'message': message,
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Message de contact envoyé avec succès !");
        print("📨 Réponse: ${response.body}");
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

  /// 📋 Récupérer l'historique des messages de contact (pour utilisateurs connectés)
  static Future<List<dynamic>> getContactHistory() async {
    print("🟢 Chargement de l'historique des contacts...");

    try {
      final token = await AuthAPI.getToken();
      
      if (token == null || token.isEmpty) {
        throw Exception("Utilisateur non connecté");
      }

      final url = Uri.parse('$baseUrl/history');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print("✅ Historique des contacts récupéré avec succès !");
        return body is List ? body : [];
      } else {
        final body = jsonDecode(response.body);
        final erreur = "Erreur : ${body["message"] ?? 'Une erreur est survenue.'}";
        print("❌ Erreur (${response.statusCode}): ${response.body}");
        throw Exception(erreur);
      }
    } catch (e) {
      print("⚠️ Erreur de connexion : $e");
      throw Exception("⚠️ Erreur de connexion : $e");
    }
  }

  /// 👁️ Récupérer les détails d'un message de contact spécifique
  static Future<Map<String, dynamic>> getContactDetails(int contactId) async {
    print("🟢 Chargement des détails du contact...");

    try {
      final token = await AuthAPI.getToken();
      
      if (token == null || token.isEmpty) {
        throw Exception("Utilisateur non connecté");
      }

      final url = Uri.parse('$baseUrl/$contactId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print("✅ Détails du contact récupérés avec succès !");
        return body is Map<String, dynamic> ? body : {};
      } else {
        final body = jsonDecode(response.body);
        final erreur = "Erreur : ${body["message"] ?? 'Une erreur est survenue.'}";
        print("❌ Erreur (${response.statusCode}): ${response.body}");
        throw Exception(erreur);
      }
    } catch (e) {
      print("⚠️ Erreur de connexion : $e");
      throw Exception("⚠️ Erreur de connexion : $e");
    }
  }

  // Récupérer tous les contacts
  static Future<List<dynamic>> getAllContacts() async {
    try {
      final token = await AuthAPI.getToken();

      print('🔄 Récupération des contacts depuis: $baseUrl');
      
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> contacts = json.decode(response.body);
        print('✅ ${contacts.length} contacts récupérés avec succès');
        return contacts;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception('Erreur ${response.statusCode}: $error');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des contacts: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour un contact
  static Future<Map<String, dynamic>> updateContact(int id, Map<String, dynamic> data) async {
    try {
      print('🔄 Mise à jour du contact ID: $id');
      final token = await AuthAPI.getToken();
      
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> updatedContact = json.decode(response.body);
        print('✅ Contact mis à jour avec succès');
        return updatedContact;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du contact: $e');
      throw Exception('Erreur de mise à jour: $e');
    }
  }

  // Supprimer un contact
  static Future<void> deleteContact(int id) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Suppression du contact ID: $id');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Contact supprimé avec succès');
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression du contact: $e');
      throw Exception('Erreur de suppression: $e');
    }
  }

  // Méthode utilitaire pour gérer les erreurs
  static String _handleErrorResponse(http.Response response) {
    try {
      final errorBody = json.decode(response.body);
      return errorBody['message'] ?? 'Erreur ${response.statusCode}';
    } catch (e) {
      return 'Erreur ${response.statusCode}: ${response.body}';
    }
  }
}