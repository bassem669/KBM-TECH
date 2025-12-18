// lib/fetch/avis_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AvisAPI {
  static String baseUrl = dotenv.env['AVIS_URL'] ?? 'http://10.205.182.163:5000/api/avis';
  // Méthode utilitaire pour les headers
  static Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (withAuth) {
      final token = await AuthAPI.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }

  // Ajouter un avis
  static Future<Map<String, dynamic>> ajouter(int produitId, String message, int note) async {
    try {
      final headers = await _getHeaders();
      
      final res = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode({
          'produit_id': produitId,
          'message': message.trim(),
          'note': note
        }),
      );

      print('🟢 Statut réponse ajout avis: ${res.statusCode}');
      print('🟢 Corps réponse: ${res.body}');

      if (res.statusCode == 201) {
        final avisData = jsonDecode(res.body);
        return {
          'success': true,
          'data': avisData,
          'message': 'Avis ajouté avec succès'
        };
      } else {
        final error = jsonDecode(res.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de l\'ajout de l\'avis',
          'statusCode': res.statusCode
        };
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ajout d\'avis: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e'
      };
    }
  }

  // Récupérer les avis d'un produit
  static Future<Map<String, dynamic>> fetchAvisParProduit(int produitId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/produit/$produitId'),
        headers: await _getHeaders(withAuth: false),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        List<dynamic> avisList = [];
        
        if (responseData is List) {
          avisList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          avisList = responseData['avis'] ?? responseData['data'] ?? [];
        }
        
        return {
          'success': true,
          'data': avisList,
          'erreur': null,
        };
      }
      else if (response.statusCode == 404) {
        return {
          'success': true,
          'data': [],
          'erreur': 'Produit non trouvé',
        };
      }
      else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': [],
          'erreur': errorData['message'] ?? 'Erreur lors du chargement des avis',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      print('❌ Erreur fetchAvisParProduit: $e');
      return {
        'success': false,
        'data': [],
        'erreur': 'Erreur de connexion: $e',
      };
    }
  }

  // Récupérer l'avis de l'utilisateur connecté pour un produit spécifique
  static Future<Map<String, dynamic>> getMonAvisPourProduit(int produitId) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/produit/$produitId/mon-avis'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        return {
          'success': true,
          'data': responseData, // peut être null si pas d'avis
          'erreur': null,
        };
      }
      else if (response.statusCode == 404) {
        return {
          'success': true,
          'data': null, // Pas d'avis pour ce produit
          'erreur': null,
        };
      }
      else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'erreur': errorData['message'] ?? 'Erreur lors de la vérification de l\'avis',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      print('❌ Erreur getMonAvisPourProduit: $e');
      return {
        'success': false,
        'data': null,
        'erreur': 'Erreur de connexion: $e',
      };
    }
  }

  // Modifier un avis
  static Future<Map<String, dynamic>> modifier(int avisId, String message, int note) async {
    try {
      final headers = await _getHeaders();
      
      final res = await http.put(
        Uri.parse('$baseUrl/$avisId'),
        headers: headers,
        body: jsonEncode({
          'message': message.trim(),
          'note': note
        }),
      );

      print('🟢 Statut réponse modification avis: ${res.statusCode}');
      print('🟢 Corps réponse: ${res.body}');

      if (res.statusCode == 200) {
        final avisData = jsonDecode(res.body);
        return {
          'success': true,
          'data': avisData,
          'message': 'Avis modifié avec succès'
        };
      } else {
        final error = jsonDecode(res.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de la modification de l\'avis',
          'statusCode': res.statusCode
        };
      }
    } catch (e) {
      print('❌ Erreur lors de la modification d\'avis: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e'
      };
    }
  }

  // Supprimer un avis
  static Future<Map<String, dynamic>> supprimer(int avisId) async {
    try {
      final headers = await _getHeaders();
      
      final res = await http.delete(
        Uri.parse('$baseUrl/$avisId'),
        headers: headers,
      );

      print('🟢 Statut réponse suppression avis: ${res.statusCode}');
      print('🟢 Corps réponse: ${res.body}');

      if (res.statusCode == 200) {
        return {
          'success': true,
          'message': 'Avis supprimé avec succès'
        };
      } else {
        final error = jsonDecode(res.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de la suppression de l\'avis',
          'statusCode': res.statusCode
        };
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression d\'avis: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e'
      };
    }
  }

  // Récupérer tous les avis de l'utilisateur connecté
  static Future<Map<String, dynamic>> getMesAvis() async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/utilisateur/mes-avis'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        List<dynamic> avisList = [];
        
        if (responseData is List) {
          avisList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          avisList = responseData['avis'] ?? responseData['data'] ?? [];
        }
        
        return {
          'success': true,
          'data': avisList,
          'erreur': null,
        };
      }
      else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': [],
          'erreur': errorData['message'] ?? 'Erreur lors du chargement de vos avis',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      print('❌ Erreur getMesAvis: $e');
      return {
        'success': false,
        'data': [],
        'erreur': 'Erreur de connexion: $e',
      };
    }
  }

  // Méthodes utilitaires pour travailler avec les données brutes
  static String getNomUtilisateur(Map<String, dynamic> avis) {
    if (avis['client'] != null) {
      final client = avis['client'];
      return '${client['prenom'] ?? ''} ${client['nom'] ?? ''}'.trim();
    }
    return 'Utilisateur';
  }

  static String getDateAvisFormatee(Map<String, dynamic> avis) {
    final dateString = avis['date_avis'] ?? avis['date_creation'];
    if (dateString != null) {
      try {
        final date = DateTime.parse(dateString);
        return '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        return 'Date invalide';
      }
    }
    return 'Date inconnue';
  }

  static String getEtoiles(int note) {
    return '⭐' * note;
  }

  static bool estProprietaire(Map<String, dynamic> avis, int userId) {
    return avis['client_id'] == userId;
  }
}