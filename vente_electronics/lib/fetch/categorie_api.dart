// lib/fetch/categorie_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_api.dart';

class CategorieAPI {
  static String baseUrl = dotenv.env['CATEGORIE_URL'] ?? 'http://192.168.1.54:5000/api/categories';

  // Récupérer toutes les catégories
  static Future<List<dynamic>> getAllCategories() async {
    try {
      print('🔄 Tentative de connexion à: $baseUrl');
      
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> categories = json.decode(response.body);
        print('✅ ${categories.length} catégories récupérées avec succès');
        return categories;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception('Erreur ${response.statusCode}: $error');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des catégories: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Créer une nouvelle catégorie
  static Future<Map<String, dynamic>> createCategory(String nom) async {
    try {
      print('🔄 Création d\'une nouvelle catégorie: $nom');
      final token = await AuthAPI.getToken();
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: json.encode({
          'nom': nom,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final Map<String, dynamic> newCategory = json.decode(response.body);
        print('✅ Catégorie créée avec succès: $nom (ID: ${newCategory['id']})');
        return newCategory;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la création de la catégorie: $e');
      throw Exception('Erreur de création: $e');
    }
  }

  // Modifier une catégorie
  static Future<Map<String, dynamic>> updateCategory(int id, String nom) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Modification de la catégorie ID: $id -> $nom');
      
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {
          
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: json.encode({
          'nom': nom,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> updatedCategory = json.decode(response.body);
        print('✅ Catégorie modifiée avec succès: $nom');
        return updatedCategory;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la modification de la catégorie: $e');
      throw Exception('Erreur de modification: $e');
    }
  }

  // Supprimer une catégorie
  static Future<void> deleteCategory(int id) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Suppression de la catégorie ID: $id');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Catégorie supprimée avec succès: $id - ${result['message']}');
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de la catégorie: $e');
      throw Exception('Erreur de suppression: $e');
    }
  }

  // Récupérer une catégorie par son ID
  static Future<Map<String, dynamic>> getCategoryById(int id) async {
    try {
      print('🔄 Récupération de la catégorie ID: $id');
      
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> category = json.decode(response.body);
        print('✅ Catégorie récupérée avec succès: ${category['nom']}');
        return category;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la catégorie: $e');
      throw Exception('Erreur de récupération: $e');
    }
  }

  // Méthode utilitaire pour gérer les erreurs de réponse
  static String _handleErrorResponse(http.Response response) {
    try {
      final errorBody = json.decode(response.body);
      return errorBody['message'] ?? 'Erreur ${response.statusCode}';
    } catch (e) {
      return 'Erreur ${response.statusCode}: ${response.body}';
    }
  }

  // Méthode de test de connexion
  static Future<void> testConnexion() async {
    try {
      print('🧪 TEST DE CONNEXION CATÉGORIES');
      print('🔧 Base URL: $baseUrl');
      
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      print('📡 Statut: ${response.statusCode}');
      print('📦 Body: ${response.body}');
      
    } catch (e) {
      print('❌ Test échoué: $e');
    }
  }
}