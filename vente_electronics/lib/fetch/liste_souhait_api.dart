// lib/services/wishlist_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WishlistService extends ChangeNotifier {
  // Singleton pattern
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  // Clés de stockage
  static const String _wishlistKey = 'wishlist_items';
  
  // État interne
  int _count = 0;
  bool _initialized = false;

  // Getters
  int get count => _count;

  // Initialisation
  Future<void> initialize() async {
    if (!_initialized) {
      await _refreshCount();
      _initialized = true;
    }
  }

  // Méthodes principales
  Future<void> addToWishlist(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final wishlist = await _getWishlist();
    
    // Convertir l'ID en String pour la cohérence
    final productId = product['id']?.toString() ?? '';
    final existingIndex = wishlist.indexWhere((item) => item['id']?.toString() == productId);
    
    if (existingIndex == -1) {
      // S'assurer que le produit a un ID string
      final productToAdd = Map<String, dynamic>.from(product);
      productToAdd['id'] = productId;
      
      wishlist.add(productToAdd);
      await prefs.setString(_wishlistKey, json.encode(wishlist));
      await _refreshCount();
    }
  }

  Future<void> removeFromWishlist(dynamic productId) async {
    final prefs = await SharedPreferences.getInstance();
    final wishlist = await _getWishlist();
    
    // Convertir l'ID en String pour la comparaison
    final idToRemove = productId?.toString() ?? '';
    wishlist.removeWhere((item) => item['id']?.toString() == idToRemove);
    
    await prefs.setString(_wishlistKey, json.encode(wishlist));
    await _refreshCount();
  }

  Future<bool> isInWishlist(dynamic productId) async {
    final wishlist = await _getWishlist();
    final idToCheck = productId?.toString() ?? '';
    return wishlist.any((item) => item['id']?.toString() == idToCheck);
  }

  Future<List<Map<String, dynamic>>> getWishlist() async {
    return await _getWishlist();
  }

  Future<int> getWishlistCount() async {
    final wishlist = await _getWishlist();
    return wishlist.length;
  }

  Future<void> clearWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wishlistKey);
    await _refreshCount();
  }

  Future<void> refresh() async {
    await _refreshCount();
  }

  // Méthodes privées
  Future<List<Map<String, dynamic>>> _getWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlistJson = prefs.getString(_wishlistKey);
    
    if (wishlistJson != null) {
      try {
        final List<dynamic> decoded = json.decode(wishlistJson);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Erreur de décodage de la liste de souhaits: $e');
        return [];
      }
    }
    
    return [];
  }

  Future<void> _refreshCount() async {
    final newCount = await getWishlistCount();
    if (_count != newCount) {
      _count = newCount;
      notifyListeners();
    }
  }
}