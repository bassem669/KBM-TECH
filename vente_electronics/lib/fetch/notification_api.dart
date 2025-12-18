import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  static String get baseUrl => dotenv.env['NOTIFICATION_URL'] ?? 'http://10.205.182.163:5000/api/notifications';
  
  static Future<int> getUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/unread/count'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['unread'] ?? 0;
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
  // Récupérer toutes les notifications avec pagination et filtrage
  static Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String type = 'all',
  }) async {
    try {
      final Uri uri;
      if (type == 'all') {
        uri = Uri.parse('$baseUrl?page=$page&limit=$limit');
      } else {
        uri = Uri.parse('$baseUrl/type/$type?page=$page&limit=$limit');
      }

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body);
        return {
          'success': true,
          'data': notifications,
          'pagination': {
            'page': page,
            'limit': limit,
            'hasMore': notifications.length == limit,
          }
        };
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les notifications non lues
  static Future<List<dynamic>> getUnreadNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/unread'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Récupérer les statistiques
  static Future<Map<String, dynamic>> getNotificationStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final stats = json.decode(response.body);
        return {
          'success': true,
          'data': {
            'total': stats['total'] ?? 0,
            'unread': stats['unread'] ?? 0,
            'lowStockCount': stats['lowStockCount'] ?? 0,
            'newOrderCount': stats['newOrderCount'] ?? 0,
            'read': stats['read'] ?? 0,
          }
        };
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Marquer une notification comme lue
  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$notificationId/read'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final notification = json.decode(response.body);
        return {
          'success': true,
          'data': notification,
          'message': 'Notification marquée comme lue'
        };
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Marquer toutes les notifications comme lues
  static Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/read-all'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return {
          'success': true,
          'message': result['message'] ?? 'Toutes les notifications marquées comme lues'
        };
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Supprimer une notification
  static Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$notificationId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return {
          'success': true,
          'message': result['message'] ?? 'Notification supprimée avec succès'
        };
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}

// Helper functions pour manipuler les données JSON
class NotificationHelpers {
  // Obtenir l'icône selon le type
  static String getIcon(String type) {
    switch (type) {
      case 'low_stock':
        return '📦';
      case 'new_order':
        return '🛒';
      case 'system':
        return '⚙️';
      default:
        return '🔔';
    }
  }

  // Obtenir la couleur selon le type
  static int getColor(String type) {
    switch (type) {
      case 'low_stock':
        return 0xFFFFA000; // Orange
      case 'new_order':
        return 0xFF2196F3; // Blue
      case 'system':
        return 0xFF4CAF50; // Green
      default:
        return 0xFF757575; // Grey
    }
  }

  // Obtenir le texte du type
  static String getTypeText(String type) {
    switch (type) {
      case 'low_stock':
        return 'Stock faible';
      case 'new_order':
        return 'Nouvelle commande';
      case 'system':
        return 'Système';
      default:
        return 'Notification';
    }
  }

  // Formater la date
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // Formater les données supplémentaires
  static String formatData(Map<String, dynamic> data) {
    return data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
  }
}