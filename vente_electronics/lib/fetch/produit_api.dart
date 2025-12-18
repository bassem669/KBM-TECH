// lib/fetch/produit_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProduitAPI {
  static String baseUrl = dotenv.env['PRODUIT_URL'] ?? 'http://192.168.1.54:5000/api/produits';

  // Helper method to validate JSON response
  static bool _isJsonResponse(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    return contentType.contains('application/json');
  }

  // Helper method to handle common errors
  static void _handleResponseError(http.Response response) {
    if (!_isJsonResponse(response)) {
      print("❌ Réponse non-JSON reçue:");
      print("   Status: ${response.statusCode}");
      print("   Headers: ${response.headers}");
      print("   Body: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}");
      throw Exception('Le serveur a retourné une page HTML au lieu de données JSON. Vérifiez:\n- L\'URL de l\'API: $baseUrl\n- Les endpoints\n- La configuration serveur');
    }

    if (response.statusCode >= 400) {
      try {
        final body = jsonDecode(response.body);
        final errorMessage = body["message"] ?? 'Erreur ${response.statusCode}';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    }
  }

  // Dans ProduitAPI - Améliorez la méthode fetchAllProduits
static Future<Map<String, dynamic>> fetchAllProduits({
  int page = 1,
  int limit = 10,
  String? search,
  String? categorie,
}) async {
  try {
    print("🟢 Chargement des produits - Page: $page, Limit: $limit");
    
    // Construction des paramètres de requête
    final Map<String, String> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    if (categorie != null && categorie.isNotEmpty) {
      queryParams['categorie'] = categorie;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final response = await http.get(uri);

    print("🔍 Réponse pagination:");
    print("   Status: ${response.statusCode}");
    print("   Page: $page, Limit: $limit");

    // Validate response
    _handleResponseError(response);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final produits = body['data'] ?? [];
      final total = body['total'] ?? 0;
      final pages = body['pages'] ?? 1;
      
      print("✅ ${produits.length} produits récupérés (Page $page/$pages)");
      print("   Total: $total produits");
      
      return {
        'total': total,
        'pages': pages,
        'currentPage': page,
        'data': produits,
      };
    } else {
      throw Exception('Statut HTTP inattendu: ${response.statusCode}');
    }
  } catch (e) {
    print("❌ Erreur lors du chargement des produits: $e");
    rethrow;
  }
}

  static Future<List<dynamic>> fetchProdPlusPop() async {
    try {
      print("🟢 Chargement des produits populaires...");
      final url = "$baseUrl/plusPopulaires";
      print("   URL: $url");

      final response = await http.get(Uri.parse(url));

      print("🔍 Réponse reçue:");
      print("   Status: ${response.statusCode}");
      print("   Content-Type: ${response.headers['content-type']}");

      // Validate response
      _handleResponseError(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print("✅ ${body.length} produits populaires récupérés avec succès !");
        return body as List<dynamic>;
      } else {
        throw Exception('Statut HTTP inattendu: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des produits populaires: $e");
      rethrow;
    }
  }

  static Future<List<dynamic>> fetchProdPlusNotes() async {
    try {
      print("🟢 Chargement des produits les mieux notés...");
      final url = "$baseUrl/plusNotes";
      print("   URL: $url");

      final response = await http.get(Uri.parse(url));

      print("🔍 Réponse reçue:");
      print("   Status: ${response.statusCode}");
      print("   Content-Type: ${response.headers['content-type']}");

      // Validate response
      _handleResponseError(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print("✅ ${body.length} produits bien notés récupérés avec succès !");
        return body as List<dynamic>;
      } else {
        throw Exception('Statut HTTP inattendu: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des produits bien notés: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> fetchProdDetails(int id) async {
    try {
      print("🟢 Chargement des détails du produit $id...");
      final url = "$baseUrl/$id";
      print("   URL: $url");

      final response = await http.get(Uri.parse(url));

      print("🔍 Réponse reçue:");
      print("   Status: ${response.statusCode}");
      print("   Content-Type: ${response.headers['content-type']}");

      // Validate response
      _handleResponseError(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print("✅ Détails du produit récupérés avec succès !");
        return body;
      } else {
        throw Exception('Statut HTTP inattendu: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Erreur lors du chargement des détails du produit: $e");
      rethrow;
    }
  }

  

  // Method to test API connection
  static Future<void> testConnection() async {
    try {
      print("🧪 Test de connexion API...");
      print("   URL de base: $baseUrl");
      
      final response = await http.get(Uri.parse(baseUrl));
      
      print("🔍 Résultat du test:");
      print("   Status: ${response.statusCode}");
      print("   Content-Type: ${response.headers['content-type']}");
      print("   Taille de la réponse: ${response.body.length} caractères");
      
      if (_isJsonResponse(response)) {
        print("✅ La réponse est du JSON valide");
        try {
          jsonDecode(response.body);
          print("✅ Le JSON est valide et peut être parsé");
        } catch (e) {
          print("❌ Le JSON est invalide: $e");
        }
      } else {
        print("❌ La réponse n'est pas du JSON");
        print("   Preview: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}");
      }
    } catch (e) {
      print("❌ Erreur lors du test de connexion: $e");
    }
  }
}