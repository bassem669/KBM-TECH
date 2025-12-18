// lib/services/utilisateur_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_api.dart';

class UtilisateurService {
  static String get baseUrl => dotenv.env['USER_URL'] ?? 'http://192.168.1.54:5000/api/auth/utilisateurs';

  // Récupérer tous les utilisateurs
  static Future<Map<String, dynamic>> getAllUtilisateurs() async {
    try {
      final token = await AuthAPI.getToken();

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('✅ ${data['data']?.length ?? 0} utilisateurs récupérés');
        return data;
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des utilisateurs: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Mettre à jour le rôle d'un utilisateur
  static Future<Map<String, dynamic>> updateUserRole(int id, String newRole) async {
    try {
      final token = await AuthAPI.getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'role': newRole,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        print('✅ Rôle utilisateur mis à jour: $id -> $newRole');
        return result;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du rôle: $e');
      throw Exception('Erreur de mise à jour: $e');
    }
  }

  // Supprimer un utilisateur
  static Future<void> deleteUtilisateur(int id) async {
    
    try {
      final token = await AuthAPI.getToken();

      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Utilisateur supprimé avec succès: $id');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Erreur lors de la suppression');
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de l\'utilisateur: $e');
      throw Exception('Erreur de suppression: $e');
    }
  }
}