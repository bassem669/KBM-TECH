// services/comparison_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ComparisonService {
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.1.54:5000/api/categories';

  static Future<Map<String, dynamic>> compareProducts(List<int> productIds) async {
    // Convertit la liste en JSON (liste réelle) et encode pour l'URL
    final String productIdsString = Uri.encodeComponent(jsonEncode(productIds));

    final response = await http.get(
      Uri.parse('$baseUrl/compare?produitIds=$productIdsString'),
    );

    if (response.statusCode == 200) {
        print(response.body);
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load comparison: ${response.statusCode}');
    }
  }
}