// lib/fetch/commande_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CommandeAPI {
  static String baseUrl = dotenv.env['COMMANDE_URL'] ?? 'http://192.168.1.54:5000/api/commandes';

  static Future<Map<String, dynamic>> createCommande(List<Map<String, dynamic>> lignes) async {
    try {
      final token = await AuthAPI.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      // VALIDATION DES DONNÉES AJOUTÉE
      for (var ligne in lignes) {
        if (ligne['produitId'] == null) {
          throw Exception('ID produit manquant dans une ligne de commande');
        }
        if (ligne['quantite'] == null || ligne['quantite'] <= 0) {
          throw Exception('Quantité invalide pour le produit ${ligne['produitId']}');
        }
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'lignes': lignes,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur de validation');
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé - Veuillez vous reconnecter');
      } else if (response.statusCode == 500) {
        throw Exception('Erreur serveur interne');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la création de la commande: $e');
      rethrow;
    }
  }

  // Les autres méthodes restent inchangées...
  static Future<List<dynamic>> getUserCommandes() async {
    try {
      final token = await AuthAPI.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/mes-commandes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé - Token invalide');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des commandes: $e');
      rethrow;
    }
  }


  // Récupérer toutes les commandes (pour admin)
  static Future<List<dynamic>> getAllCommandes() async {
    try {
      final token = await AuthAPI.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé - Accès administrateur requis');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération de toutes les commandes: $e');
      rethrow;
    }
  }

  // Récupérer les détails d'une commande spécifique
  static Future<Map<String, dynamic>> getDetailsCommande(int commandeId) async {
    try {
      final token = await AuthAPI.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/$commandeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Commande non trouvée');
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la récupération des détails de la commande: $e');
      rethrow;
    }
  }

  // Mettre à jour l'état d'une commande
  static Future<Map<String, dynamic>> updateCommande(int commandeId, String etat) async {
    try {
      final token = await AuthAPI.getToken();
      if (token == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/$commandeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'etat': etat,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Commande non trouvée');
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé');
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de la commande: $e');
      rethrow;
    }
  }

    // Méthode utilitaire pour formater les données du panier en lignes de commande
  static List<Map<String, dynamic>> formatLignesFromCart(List<Map<String, dynamic>> cartItems) {
    return cartItems.map((item) {
      final product = item['product'] as Map<String, dynamic>;
      return {
        'produitId': product['id'],
        'quantite': item['quantite'],
      };
    }).toList();
  }

  // Calculer le total d'une commande
  static double calculateTotal(List<dynamic> lignes) {
    return lignes.fold(0.0, (total, ligne) {
      final produit = ligne['produit'] as Map<String, dynamic>;
      final quantite = ligne['quantite'] as int;
      final prix = (produit['prix'] is num ? produit['prix'].toDouble() : 0.0);
      return total + (prix * quantite);
    });
  }

  // Obtenir le libellé de l'état de la commande
  static String getEtatLibelle(String etat) {
    switch (etat) {
      case 'en_attente':
        return 'En attente';
      case 'confirmee':
        return 'Confirmée';
      case 'en_preparation':
        return 'En préparation';
      case 'expediee':
        return 'Expédiée';
      case 'livree':
        return 'Livrée';
      case 'annulee':
        return 'Annulée';
      default:
        return etat;
    }
  }

  // Obtenir la couleur selon l'état de la commande
  static int getEtatColor(String etat) {
    switch (etat) {
      case 'en_attente':
        return 0xFFFFA726; // Orange
      case 'confirmee':
        return 0xFF42A5F5; // Blue
      case 'en_preparation':
        return 0xFF26C6DA; // Cyan
      case 'expediee':
        return 0xFF7E57C2; // Purple
      case 'livree':
        return 0xFF66BB6A; // Green
      case 'annulee':
        return 0xFFEF5350; // Red
      default:
        return 0xFF757575; // Grey
    }
  }
}