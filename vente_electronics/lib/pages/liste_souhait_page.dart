// lib/pages/wishlist_page.dart
import 'package:flutter/material.dart';
import './../fetch/liste_souhait_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';

class WishlistPage extends StatefulWidget {
  const WishlistPage({Key? key}) : super(key: key);

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final WishlistService _wishlistService = WishlistService();
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
    });
    
    final items = await _wishlistService.getWishlist();
    setState(() {
      _wishlistItems = items;
      _isLoading = false;
    });
  }

  Future<void> _removeItem(dynamic productId) async { // Changé en dynamic
    await _wishlistService.removeFromWishlist(productId);
    await _loadWishlist();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Produit retiré de la liste de souhaits'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearWishlist() async {
    await _wishlistService.clearWishlist();
    await _loadWishlist();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Liste de souhaits vidée'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Vider la liste'),
          content: const Text('Êtes-vous sûr de vouloir vider toute votre liste de souhaits ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearWishlist();
              },
              child: const Text('Vider', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Méthodes pour la gestion des promotions
  Map<String, dynamic> _calculateProductPrice(Map<String, dynamic> product) {
    final double prixOriginal = _getPrixOriginal(product);
    final bool hasPromotion = _hasActivePromotion(product);
    final double prixPromo = _getPrixPromo(product, prixOriginal);
    final int promotionPercentage = _getPourcentagePromo(product);

    return {
      'prixOriginal': prixOriginal,
      'prixPromo': prixPromo,
      'hasPromotion': hasPromotion,
      'promotionPercentage': promotionPercentage,
    };
  }

  double _getPrixOriginal(Map<String, dynamic> product) {
    final prix = product['prix'];
    if (prix is num) return prix.toDouble();
    if (prix is String) return double.tryParse(prix) ?? 0.0;
    return 0.0;
  }

  bool _hasActivePromotion(Map<String, dynamic> product) {
    final promotions = product['promotions'] as List<dynamic>?;
    if (promotions == null || promotions.isEmpty) return false;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      
      if (dateDebut != null && dateFin != null && 
          now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        return true;
      }
    }
    return false;
  }

  double _getPrixPromo(Map<String, dynamic> product, double prixOriginal) {
    if (!_hasActivePromotion(product)) return prixOriginal;
    
    final promotions = product['promotions'] as List<dynamic>?;
    final now = DateTime.now();
    
    for (final promo in promotions ?? []) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      final pourcentage = promo['pourcentage'] is num ? promo['pourcentage'].toDouble() : 0.0;
      
      if (dateDebut != null && dateFin != null && 
          now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        return prixOriginal * (1 - pourcentage / 100);
      }
    }
    return prixOriginal;
  }

  int _getPourcentagePromo(Map<String, dynamic> product) {
    final promotions = product['promotions'] as List<dynamic>?;
    if (promotions == null || promotions.isEmpty) return 0;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      
      if (dateDebut != null && dateFin != null && 
          now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        return promo['pourcentage'] is num ? promo['pourcentage'].toInt() : 0;
      }
    }
    return 0;
  }

  // Calcul du total des économies dans la wishlist
  double _calculateTotalSavings() {
    double totalSavings = 0;
    for (final item in _wishlistItems) {
      final priceInfo = _calculateProductPrice(item);
      if (priceInfo['hasPromotion']) {
        totalSavings += priceInfo['prixOriginal'] - priceInfo['prixPromo'];
      }
    }
    return totalSavings;
  }

  // Compte le nombre de produits en promotion
  int _countPromotionItems() {
    return _wishlistItems.where((item) {
      return _hasActivePromotion(item);
    }).length;
  }

  Widget _buildWishlistItem(Map<String, dynamic> item) {
    final priceInfo = _calculateProductPrice(item);
    final double prixOriginal = priceInfo['prixOriginal'];
    final double prixPromo = priceInfo['prixPromo'];
    final bool hasPromotion = priceInfo['hasPromotion'];
    final int promotionPercentage = priceInfo['promotionPercentage'];
    final double economie = hasPromotion ? prixOriginal - prixPromo : 0;

    String imageUrl = '';
    if (item['images'] != null && item['images'] is List && item['images'].isNotEmpty) {
      final firstImage = item['images'][0];
      if (firstImage != null && firstImage['path'] != null) {
        imageUrl = '$baseUrl${firstImage['path']}';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/50',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      );
                    },
                  ),
                ),
                if (hasPromotion)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '-$promotionPercentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              item['nom'] ?? 'Produit sans nom',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((item['description'] ?? '').isNotEmpty)
                  Text(
                    item['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 6),
                
                // Affichage du prix avec promotion
                if (hasPromotion)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${prixOriginal.toStringAsFixed(2)} DNT',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),

                      Text(
                        '${prixPromo.toStringAsFixed(2)} DNT',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          'Économie: ${economie.toStringAsFixed(2)}DNT',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                      
                  )
                else
                  Text(
                    '${prixOriginal.toStringAsFixed(2)} DNT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                
                // Note du produit si disponible
                if (item['avisMoyenne'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${(item['avisMoyenne'] is String ? double.tryParse(item['avisMoyenne']) : item['avisMoyenne']?.toDouble())?.toStringAsFixed(1) ?? '0.0'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (item['nbAvis'] != null && item['nbAvis'] > 0)
                          Text(
                            ' (${item['nbAvis']})',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeItem(item['id']),
              tooltip: 'Retirer de la liste',
            ),
            onTap: () => _navigateToProductDetail(item),
          ),
          
          // Badge promotion en haut à droite
          if (hasPromotion)
            Positioned(
              top: 8,
              right: 45,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PROMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToProductDetail(Map<String, dynamic> produit) {
    Navigator.pushNamed(
      context, 
      '/produit',
      arguments: produit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSavings = _calculateTotalSavings();
    final promotionCount = _countPromotionItems();
    final hasPromotions = promotionCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Liste de Souhaits'),
        actions: [
          if (_wishlistItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _showClearConfirmationDialog,
              tooltip: 'Vider la liste',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wishlistItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Votre liste de souhaits est vide',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ajoutez des produits que vous aimez !',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // En-tête avec statistiques
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_wishlistItems.length} produit(s) dans votre liste',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromRGBO(21, 101, 192, 1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          if (hasPromotions)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_offer, color: Colors.green[700], size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$promotionCount produit(s) en promotion',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.savings, color: Colors.orange[700], size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Économie totale: ${totalSavings.toStringAsFixed(2)}DNT',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Aucune promotion active',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    // Badge économies si promotions
                    if (hasPromotions && totalSavings > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.green[50],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.celebration, color: Colors.green[700], size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Vous économisez ${totalSavings.toStringAsFixed(2)}DNT sur votre liste !',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: _wishlistItems.length,
                        itemBuilder: (context, index) {
                          final item = _wishlistItems[index];
                          return _buildWishlistItem(item);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}