// lib/services/promotion_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_api.dart';

class PromotionAPI {
  static String get baseUrl => dotenv.env['PROMOTION_URL'] ?? 'http://192.168.1.54:5000/api/promotions';

  // Récupérer toutes les promotions
  static Future<List<dynamic>> getAllPromotions() async {
    try {
      print('🔄 Récupération de toutes les promotions depuis: $baseUrl');
      final token = await AuthAPI.getToken();

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
        final List<dynamic> promotions = json.decode(response.body);
        print('✅ ${promotions.length} promotions récupérées avec succès');
        return promotions;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception('Erreur ${response.statusCode}: $error');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des promotions: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les promotions actives
  static Future<List<dynamic>> getActivePromotions() async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Récupération des promotions actives depuis: $baseUrl/active');
      
      final response = await http.get(
        Uri.parse('$baseUrl/active'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Statut HTTP: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> promotions = json.decode(response.body);
        print('✅ ${promotions.length} promotions actives récupérées avec succès');
        return promotions;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception('Erreur ${response.statusCode}: $error');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des promotions actives: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Créer une nouvelle promotion
  static Future<Map<String, dynamic>> createPromotion(Map<String, dynamic> data) async {
    try {
      final token = await AuthAPI.getToken();

      print('🔄 Création d\'une nouvelle promotion');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));


      if (response.statusCode == 201) {
        final Map<String, dynamic> newPromotion = json.decode(response.body);
        print('✅ Promotion créée avec succès');
        return newPromotion;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la création de la promotion: $e');
      throw Exception('Erreur de création: $e');
    }
  }

  // Mettre à jour une promotion
  static Future<Map<String, dynamic>> updatePromotion(int id, Map<String, dynamic> data) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Mise à jour de la promotion ID: $id');
      
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
        final Map<String, dynamic> updatedPromotion = json.decode(response.body);
        print('✅ Promotion mise à jour avec succès');
        return updatedPromotion;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de la promotion: $e');
      throw Exception('Erreur de mise à jour: $e');
    }
  }

  // Supprimer une promotion
  static Future<void> deletePromotion(int id) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Suppression de la promotion ID: $id');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Promotion supprimée avec succès');
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de la promotion: $e');
      throw Exception('Erreur de suppression: $e');
    }
  }

  // Récupérer une promotion par ID
  static Future<Map<String, dynamic>> getPromotionById(int id) async {
    try {
      final token = await AuthAPI.getToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> promotion = json.decode(response.body);
        return promotion;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la promotion: $e');
      throw Exception('Erreur de récupération: $e');
    }
  }

  // Supprimer un produit d'une promotion
  static Future<void> removeProductFromPromotion(int promotionId, int produitId) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Suppression du produit $produitId de la promotion $promotionId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$promotionId/produits/$produitId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Produit retiré de la promotion avec succès');
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression du produit de la promotion: $e');
      throw Exception('Erreur de suppression: $e');
    }
  }

  // Supprimer plusieurs produits d'une promotion
  static Future<void> removeProductsFromPromotion(int promotionId, List<int> produitIds) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Suppression de ${produitIds.length} produits de la promotion $promotionId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$promotionId/produits'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'produitIds': produitIds}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ ${produitIds.length} produits retirés de la promotion avec succès');
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression des produits de la promotion: $e');
      throw Exception('Erreur de suppression: $e');
    }
  }

  // 🆕 Appliquer une promotion à tous les produits
  static Future<Map<String, dynamic>> applyPromotionToAllProducts(Map<String, dynamic> data) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Application d\'une promotion à tous les produits');
      
      final response = await http.post(
        Uri.parse('$baseUrl/apply-to-all'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final Map<String, dynamic> result = json.decode(response.body);
        print('✅ Promotion appliquée à tous les produits avec succès');
        return result;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de l\'application de la promotion à tous les produits: $e');
      throw Exception('Erreur d\'application: $e');
    }
  }

  // 🆕 Appliquer une promotion à une catégorie spécifique
  static Future<Map<String, dynamic>> applyPromotionToCategory(Map<String, dynamic> data) async {
    try {
      final token = await AuthAPI.getToken();
      print('🔄 Application d\'une promotion à une catégorie');
      print(data);
      final response = await http.post(
        Uri.parse('$baseUrl/apply-to-category'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final Map<String, dynamic> result = json.decode(response.body);
        print('✅ Promotion appliquée à la catégorie avec succès');
        return result;
      } else {
        final error = _handleErrorResponse(response);
        throw Exception(error);
      }
    } catch (e) {
      print('❌ Erreur lors de l\'application de la promotion à la catégorie: $e');
      throw Exception('Erreur d\'application: $e');
    }
  }

  // 🆕 Mettre à jour une promotion pour tous les produits
static Future<Map<String, dynamic>> updatePromotionForAllProducts(int promotionId, Map<String, dynamic> data) async {
  try {
    final token = await AuthAPI.getToken();
    print('🔄 Mise à jour de la promotion $promotionId pour tous les produits');
    
    final response = await http.put(
      Uri.parse('$baseUrl/$promotionId/toAll'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> result = json.decode(response.body);
      print('✅ Promotion mise à jour pour tous les produits avec succès');
      return result;
    } else {
      final error = _handleErrorResponse(response);
      throw Exception(error);
    }
  } catch (e) {
    print('❌ Erreur lors de la mise à jour de la promotion pour tous les produits: $e');
    throw Exception('Erreur de mise à jour: $e');
  }
}

// 🆕 Mettre à jour une promotion pour des produits de catégories spécifiques
static Future<Map<String, dynamic>> updatePromotionForCategories(int promotionId, Map<String, dynamic> data) async {
  try {
    final token = await AuthAPI.getToken();
    print('🔄 Mise à jour de la promotion $promotionId pour des catégories spécifiques');
    
    final response = await http.put(
      Uri.parse('$baseUrl/$promotionId/updateCategory'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> result = json.decode(response.body);
      print('✅ Promotion mise à jour pour les catégories avec succès');
      return result;
    } else {
      final error = _handleErrorResponse(response);
      throw Exception(error);
    }
  } catch (e) {
    print('❌ Erreur lors de la mise à jour de la promotion pour les catégories: $e');
    throw Exception('Erreur de mise à jour: $e');
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