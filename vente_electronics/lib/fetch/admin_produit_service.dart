// lib/services/admin_produit_service.dart
import '../fetch/produit_api.dart';
import '../fetch/auth_api.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';



class AdminProduitService {
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.74.118.163:5000/api';

  // Créer un produit AVEC IMAGES - VERSION CORRIGÉE
 static Future<Map<String, dynamic>> createProduit({
  required String nom,
  required String description,
  required double prix,
  required int quantite,
  required List<XFile> images,
  required List<int> categorieIds,
}) async {
  try {
    final token = await _getToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/produits'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    // Champs texte
    request.fields['nom'] = nom.trim();
    request.fields['description'] = description.trim();
    request.fields['prix'] = prix.toString();
    request.fields['quantite'] = quantite.toString();

    // ⚠️ IMPORTANT : en JSON string, pas directement une liste
    request.fields['categorieIds'] = json.encode(categorieIds);

    // Images
    for (int i = 0; i < images.length; i++) {
      final file = File(images[i].path);

      if (!await file.exists()) {
        throw Exception("Image introuvable: ${images[i].path}");
      }

      final mimeType = _getMimeType(images[i].path);
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();

      request.files.add(
        http.MultipartFile(
          'images',
          stream,
          length,
          filename: 'image_$i.${images[i].path.split('.').last}',
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    print("📌 [DEBUG] Status: ${response.statusCode}");
    print("📌 [DEBUG] Body: $responseBody");

    // Cas HTML → erreur serveur
    if (responseBody.trim().startsWith('<')) {
      throw Exception("Le serveur a renvoyé du HTML. Mauvais token ou erreur API.");
    }

    final data = jsonDecode(responseBody);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    }

    // Gestions d’erreurs courantes
    if (response.statusCode == 401) {
      throw Exception("Token expiré ou invalide.");
    }
    if (response.statusCode == 403) {
      throw Exception("Accès refusé. Vous n'êtes pas administrateur.");
    }

    throw Exception("Erreur ${response.statusCode}: ${data["message"]}");
  } catch (e) {
    print("❌ Erreur création produit: $e");
    throw Exception("Erreur lors de la création du produit: $e");
  }
}

  // Modifier un produit AVEC IMAGES - VERSION CORRIGÉE
  static Future<Map<String, dynamic>> updateProduit({
    required int id,
    required String nom,
    required String description,
    required double prix,
    required int quantite,
    required List<XFile> images,
    required List<int> categorieIds, // ← AJOUT
  }) async {
    try {
      final token = await _getToken();
      
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/produits/$id'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      // Ajouter les champs texte
      request.fields['nom'] = nom;
      request.fields['description'] = description;
      request.fields['prix'] = prix.toString();
      request.fields['quantite'] = quantite.toString();
      request.fields['categorieIds'] = json.encode(categorieIds); // ← IMPORTANT
      request.fields['promotionIds'] = '[]';
      
      // Ajouter les nouvelles images
      for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final file = File(image.path);
      
      if (!await file.exists()) {
        throw Exception('Fichier image non trouvé: ${image.path}');
      }
      
      final fileStream = http.ByteStream(file.openRead());
      final length = await file.length();
      
      final multipartFile = http.MultipartFile(
        'images', // ← CORRECTION : 'images' au lieu de 'files'
        fileStream,
        length,
        filename: 'produit_${DateTime.now().millisecondsSinceEpoch}_$i.${image.path.split('.').last}',
      );
      
      request.files.add(multipartFile);
    }
            
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print("📊 Réponse modification - Status: ${response.statusCode}");

      // Vérifier si c'est une réponse HTML (erreur)
      if (responseBody.trim().startsWith('<!DOCTYPE') || responseBody.trim().startsWith('<html')) {
        print("❌ HTML DÉTECTÉ AU LIEU DE JSON");
        throw Exception('Le serveur a retourné une page HTML. Vérifiez votre authentification et droits administrateur.');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final body = jsonDecode(responseBody);
          print("✅ Produit modifié avec succès !");
          return body;
        } catch (e) {
          throw Exception('Erreur de parsing JSON: $e');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé. Token invalide ou expiré. Veuillez vous reconnecter.');
      } else if (response.statusCode == 403) {
        throw Exception('Accès refusé. Droits administrateur requis.');
      } else if (response.statusCode == 404) {
        throw Exception('Produit non trouvé (ID: $id)');
      } else {
        try {
          final body = jsonDecode(responseBody);
          final erreur = "Erreur ${response.statusCode}: ${body["message"] ?? 'Une erreur est survenue lors de la modification du produit'}";
          throw Exception(erreur);
        } catch (e) {
          throw Exception('Erreur ${response.statusCode}: $responseBody');
        }
      }
    } catch (e) {
      print("❌ Erreur modification produit: $e");
      throw Exception('Erreur lors de la modification du produit: $e');
    }
  }

  // Supprimer un produit
  static Future<bool> deleteProduit(int id) async {
    try {
      await _callAdminApi(
        'DELETE',
        '$baseUrl/produits/$id',
        null,
      );
      
      print("✅ Produit supprimé avec succès !");
      return true;
    } catch (e) {
      print("❌ Erreur suppression produit: $e");
      throw Exception('Erreur lors de la suppression du produit: $e');
    }
  }

  // Upload d'images séparément pour un produit existant
  static Future<Map<String, dynamic>> uploadImagesForProduct(int produitId, List<XFile> images) async {
    try {
      final token = await _getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/produits/$produitId/images'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      // Valider les images avant l'upload
      _validateImages(images);
      
      // Ajouter les images
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final file = File(image.path);
        
        // Vérifier que le fichier existe
        if (!await file.exists()) {
          throw Exception('Fichier image non trouvé: ${image.path}');
        }
        
        final fileStream = http.ByteStream(file.openRead());
        final length = await file.length();
        
        final multipartFile = http.MultipartFile(
          'files',
          fileStream,
          length,
          filename: 'produit_${produitId}_${DateTime.now().millisecondsSinceEpoch}_$i.${image.path.split('.').last}',
        );
        
        request.files.add(multipartFile);
      }
      
      print("🟢 Upload de ${images.length} image(s) pour le produit $produitId");
      
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print("📊 Réponse upload images - Status: ${response.statusCode}");

      // Vérifier si c'est une réponse HTML (erreur)
      if (responseBody.trim().startsWith('<!DOCTYPE') || responseBody.trim().startsWith('<html')) {
        print("❌ HTML DÉTECTÉ AU LIEU DE JSON");
        throw Exception('Le serveur a retourné une page HTML. Vérifiez votre authentification et droits administrateur.');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final body = jsonDecode(responseBody);
          print("✅ Images uploadées avec succès !");
          return body;
        } catch (e) {
          throw Exception('Erreur de parsing JSON: $e');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé. Token invalide ou expiré. Veuillez vous reconnecter.');
      } else if (response.statusCode == 403) {
        throw Exception('Accès refusé. Droits administrateur requis.');
      } else if (response.statusCode == 404) {
        throw Exception('Produit non trouvé (ID: $produitId)');
      } else {
        try {
          final body = jsonDecode(responseBody);
          final erreur = "Erreur ${response.statusCode}: ${body["message"] ?? 'Une erreur est survenue lors de l\'upload des images'}";
          throw Exception(erreur);
        } catch (e) {
          throw Exception('Erreur ${response.statusCode}: $responseBody');
        }
      }
    } catch (e) {
      print("❌ Erreur upload images: $e");
      throw Exception('Erreur lors de l\'upload des images: $e');
    }
  }

  // Ajoutez cette méthode dans AdminProduitService
static Future<bool> deleteProductImage(int produitId, int imageId) async {
  try {
    print('🗑️ Suppression image $imageId du produit $produitId');
    
    await _callAdminApi(
      'DELETE',
      '$baseUrl/produits/$produitId/images/$imageId',
      null,
    );
    
    print('✅ Image supprimée avec succès !');
    return true;
  } catch (e) {
    print('❌ Erreur suppression image: $e');
    throw Exception('Erreur lors de la suppression de l\'image: $e');
  }
}

// Dans AdminProduitService - méthode getProductImages
static Future<List<dynamic>> getProductImages(int produitId) async {
  try {
    final response = await _callAdminApi(
      'GET',
      '$baseUrl/produits/$produitId/images',
      null,
    );
    
    // Adapter selon la structure de votre réponse
    if (response['success'] == true) {
      return response['data'] ?? [];
    } else {
      return [];
    }
  } catch (e) {
    print('❌ Erreur récupération images: $e');
    return [];
  }
}

  // Méthodes de compatibilité (sans images) - VERSION CORRIGÉE
  static Future<Map<String, dynamic>> createProduitWithoutImages({
    required String nom,
    required String description,
    required double prix,
    required int quantite,
  }) async {
    try {
      final produitData = {
        'nom': nom,
        'description': description,
        'prix': prix,
        'quantite': quantite,
        'categorieIds': [],
        'promotionIds': [],
      };

      final response = await _callAdminApi(
        'POST',
        '$baseUrl/produits',
        produitData,
      );
      
      print("✅ Produit créé avec succès !");
      return response;
    } catch (e) {
      print("❌ Erreur création produit: $e");
      throw Exception('Erreur lors de la création du produit: $e');
    }
  }

  static Future<Map<String, dynamic>> updateProduitWithoutImages({
    required int id,
    required String nom,
    required String description,
    required double prix,
    required int quantite,
  }) async {
    try {
      final produitData = {
        'nom': nom,
        'description': description,
        'prix': prix,
        'quantite': quantite,
        'categorieIds': [],
        'promotionIds': [],
      };

      print("🟢 Modification produit $id (sans images):");
      print("   - Données: $produitData");

      final response = await _callAdminApi(
        'PUT',
        '$baseUrl/produits/$id',
        produitData,
      );
      
      print("✅ Produit modifié avec succès !");
      return response;
    } catch (e) {
      print("❌ Erreur modification produit: $e");
      throw Exception('Erreur lors de la modification du produit: $e');
    }
  }

  // Helper method to get product details
  static Future<Map<String, dynamic>> _getProduct(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/produits/$id'));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch product details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching product: $e');
    }
  }

  // Validation des images
  static void _validateImages(List<XFile> images) {
    if (images.isEmpty) {
      throw Exception('Aucune image à uploader');
    }
    
    if (images.length > 10) {
      throw Exception('Maximum 10 images autorisées');
    }
    
    for (final image in images) {
      final file = File(image.path);
      
      // Vérifier l'extension du fichier
      final extension = image.path.toLowerCase().split('.').last;
      final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      
      if (!allowedExtensions.contains(extension)) {
        throw Exception('Format d\'image non supporté: $extension. Formats autorisés: ${allowedExtensions.join(', ')}');
      }
      
      // Vérifier la taille du fichier (10MB max)
      final fileSize = file.lengthSync();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image trop volumineuse: ${image.name} (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum: 10MB');
      }
    }
  }

  // Méthode helper pour les appels API admin
  static Future<Map<String, dynamic>> _callAdminApi(
    String method, 
    String url, 
    Map<String, dynamic>? data,
  ) async {
    try {
      final token = await _getToken();
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print("🟢 Appel API Admin: $method $url");
      if (data != null) {
        print("📦 Données envoyées: $data");
      }

      http.Response response;

      switch (method) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: headers);
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: data != null ? json.encode(data) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: headers,
            body: data != null ? json.encode(data) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: headers);
          break;
        case 'PATCH':
          response = await http.patch(
            Uri.parse(url),
            headers: headers,
            body: data != null ? json.encode(data) : null,
          );
          break;
        default:
          throw Exception('Méthode HTTP non supportée: $method');
      }

      print("📊 Réponse reçue - Status: ${response.statusCode}");

      // Check for HTML response first
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        print("❌ HTML DÉTECTÉ AU LIEU DE JSON");
        print("📄 Extrait HTML: ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}");
        throw Exception('Le serveur a retourné une page HTML au lieu de JSON. Vérifiez:\n1. Votre authentification (token valide)\n2. Vos droits administrateur\n3. L\'URL: $url');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          throw Exception('Erreur de parsing JSON: $e');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Non autorisé. Token invalide ou expiré. Veuillez vous reconnecter.');
      } else if (response.statusCode == 403) {
        throw Exception('Accès refusé. Droits administrateur requis.');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé (404). Vérifiez l\'URL: $url');
      } else {
        try {
          final body = jsonDecode(response.body);
          final erreur = "Erreur ${response.statusCode}: ${body["message"] ?? 'Une erreur est survenue.'}";
          print("❌ Erreur API ($method $url): ${response.body}");
          throw Exception(erreur);
        } catch (e) {
          throw Exception('Erreur ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      print("⚠️ Erreur connexion API ($method $url): $e");
      rethrow;
    }
  }

  // Méthode pour récupérer le token depuis AuthAPI
  static Future<String> _getToken() async {
    try {
      final token = await AuthAPI.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token non disponible. Veuillez vous reconnecter.');
      }
      print("🔐 Token récupéré avec succès (${token.length} caractères)");
      return token;
    } catch (e) {
      print("❌ Erreur récupération token: $e");
      throw Exception('Token non disponible. Veuillez vous reconnecter.');
    }
  }

  // Helper methods cohérents avec votre structure de données existante
  static bool hasActivePromotion(Map<String, dynamic> produit) {
    final promotions = produit['promotions'] as List? ?? [];
    final now = DateTime.now();
    
    for (var promo in promotions) {
      try {
        final dateDebut = DateTime.parse(promo['dateDebut']);
        final dateFin = DateTime.parse(promo['dateFin']);
        
        if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
          return true;
        }
      } catch (e) {
        print("⚠️ Erreur parsing date promotion: $e");
      }
    }
    return false;
  }

  static String getFirstImageUrl(Map<String, dynamic> produit) {
    final images = produit['images'] as List? ?? [];
    if (images.isEmpty) return '';
    final firstImage = images.first;
    final imagePath = firstImage['path'] ?? '';
    
    // Handle both absolute and relative URLs
    if (imagePath.startsWith('http')) {
      return imagePath;
    } else {
      return '${ProduitAPI.baseUrl}$imagePath';
    }
  }

  static double getAvisMoyenne(Map<String, dynamic> produit) {
    final avisMoyenne = produit['avisMoyenne'];
    if (avisMoyenne == null) return 0.0;
    
    // Handle both string and numeric types
    if (avisMoyenne is String) {
      return double.tryParse(avisMoyenne) ?? 0.0;
    } else if (avisMoyenne is int) {
      return avisMoyenne.toDouble();
    } else if (avisMoyenne is double) {
      return avisMoyenne;
    }
    return 0.0;
  }

  static int getNbAvis(Map<String, dynamic> produit) {
    final nbAvis = produit['nbAvis'];
    if (nbAvis == null) return 0;
    
    if (nbAvis is String) {
      return int.tryParse(nbAvis) ?? 0;
    } else if (nbAvis is int) {
      return nbAvis;
    } else if (nbAvis is double) {
      return nbAvis.toInt();
    }
    return 0;
  }

  static String getCategories(List<dynamic> categories) {
    if (categories.isEmpty) return 'Aucune catégorie';
    return categories.map<String>((cat) => cat['nom']?.toString() ?? '').where((name) => name.isNotEmpty).join(', ');
  }

  // Debug method to test admin permissions
  static Future<void> testAdminPermissions() async {
    try {
      final token = await _getToken();
      print("🧪 Test des permissions administrateur...");
      
      // Test simple GET to verify token works
      final testUrl = '$baseUrl/produits';
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print("🔍 Test permissions:");
      print("   - Status: ${response.statusCode}");
      print("   - Content-Type: ${response.headers['content-type']}");
      
      if (response.statusCode == 200) {
        print("✅ Token valide pour les requêtes GET");
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print("❌ Token invalide ou permissions insuffisantes");
      }
    } catch (e) {
      print("❌ Erreur test permissions: $e");
    }
  }

  // Méthode pour compresser les images si nécessaire
  static Future<List<XFile>> compressImagesIfNeeded(List<XFile> images) async {
    final List<XFile> compressedImages = [];
    
    for (final image in images) {
      final file = File(image.path);
      final fileSize = file.lengthSync();
      
      // Si l'image fait plus de 2MB, on la considère pour la compression
      if (fileSize > 2 * 1024 * 1024) {
        print("🔄 Compression de l'image: ${image.name} (${fileSize ~/ 1024}KB)");
        // Ici vous pourriez ajouter une logique de compression
        // Pour l'instant on garde l'original
        compressedImages.add(image);
      } else {
        compressedImages.add(image);
      }
    }
    
    return compressedImages;
  }

  static String _getMimeType(String filePath) {
  final extension = filePath.toLowerCase().split('.').last;
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'application/octet-stream';
  }
}
}