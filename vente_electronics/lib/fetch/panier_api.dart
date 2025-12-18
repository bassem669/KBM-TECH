import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartProvider with ChangeNotifier {
  List<Map<String, dynamic>> _items = [];
  static const String _cartKey = 'cart_items';

  List<Map<String, dynamic>> get items => List.from(_items);
  
  int getQuantiteProduits(int id) {
    final index = _items.indexWhere((item) => item['product']['id'] == id);

    if (index == -1) {
      return 0; // produit introuvable
    }

    return _items[index]['quantite'] ?? 0;
  }

  int get totalItems => _items.fold(0, (sum, item) => sum + (item['quantite'] as int));
  
  double get totalprix => _items.fold(0.0, (sum, item) {
    final product = item['product'] as Map<String, dynamic>;
    final prix = (product['prix'] is num ? product['prix'].toDouble() : 0.0);
    return sum + (prix * (item['quantite'] as int));
  });

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartData = prefs.getString(_cartKey);
      
      if (cartData != null && cartData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(cartData);
        _items = jsonList.map((item) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          // CORRECTION: Assurer la cohérence des clés
          if (itemMap.containsKey('quantité')) {
            itemMap['quantite'] = itemMap['quantité'];
            itemMap.remove('quantité');
          }
          itemMap['quantite'] = itemMap['quantite'] ?? 1;
          return itemMap;
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors du chargement du panier: $e');
      _items = [];
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(_items);
      await prefs.setString(_cartKey, jsonString);
    } catch (e) {
      print('Erreur lors de la sauvegarde du panier: $e');
    }
  }

  Future<void> addItem(Map<String, dynamic> product) async {
    try {
      final existingIndex = _items.indexWhere((item) => 
          item['product']['id'] == product['id']);
      
      if (existingIndex >= 0) {
        final currentQuantity = _items[existingIndex]['quantite'] as int;
        _items[existingIndex]['quantite'] = currentQuantity + 1;
      } else {
        
        _items.add({
          'product': product,
          'quantite': 1, 
        });
      }
      
      notifyListeners();
      await _saveCart();
      print('✅ Produit ajouté au panier: ${product['nom']}');
    } catch (e) {
      print('❌ Erreur addItem: $e');
      rethrow;
    }
  }

  Future<void> removeItem(dynamic productId) async {
    _items.removeWhere((item) => item['product']['id'] == productId);
    notifyListeners();
    await _saveCart();
  }

  Future<void> updateQuantity(dynamic productId, int newQuantity) async {
  if (newQuantity <= 0) {
    await removeItem(productId);
    return;
  }

  final existingIndex = _items.indexWhere((item) => item['product']['id'] == productId);
  if (existingIndex >= 0) {
    final product = _items[existingIndex]['product'] as Map<String, dynamic>;
    final quantiteDisponible = product['quantite'] as int? ?? 0;
    
    // Limiter la quantité à celle disponible
    final quantiteFinale = newQuantity > quantiteDisponible ? quantiteDisponible : newQuantity;
    
    _items[existingIndex]['quantite'] = quantiteFinale;
    notifyListeners();
    await _saveCart();
  }
}

  Future<void> clearCart() async {
    _items.clear();
    notifyListeners();
    await _saveCart();
  }

  bool isInCart(dynamic productId) {
    return _items.any((item) => item['product']['id'] == productId);
  }

  int getQuantity(dynamic productId) {
    try {
      final item = _items.firstWhere((item) => item['product']['id'] == productId);
      return item['quantite'] as int;
    } catch (e) {
      return 0;
    }
  }

  double getItemTotalPrice(dynamic productId) {
    try {
      final item = _items.firstWhere((item) => item['product']['id'] == productId);
      final product = item['product'] as Map<String, dynamic>;
      final prix = (product['prix'] is num ? product['prix'].toDouble() : 0.0);
      return prix * (item['quantite'] as int);
    } catch (e) {
      return 0.0;
    }
  }
}