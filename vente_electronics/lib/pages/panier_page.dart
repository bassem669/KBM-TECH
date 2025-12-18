import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './../fetch/panier_api.dart';
import './../fetch/auth_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './../fetch/commande_api.dart';

final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';

class CartScreen extends StatelessWidget {

  Future<bool> isConnecter() async {
    final token = await AuthAPI.getToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mon Panier'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Votre panier est vide',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Calcul des totaux avec promotions
          final cartTotals = _calculateCartTotals(cart.items);
          final double sousTotal = cartTotals['sousTotal'];
          final double totalEconomies = cartTotals['totalEconomies'];
          final double totalAPayer = cartTotals['totalAPayer'];
          final bool hasPromotions = cartTotals['hasPromotions'];

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final product = item['product'] as Map<String, dynamic>;
                    final quantite = item['quantite'] as int;
                    
                    // Calcul du prix avec promotions
                    final productPriceInfo = _calculateProductPrice(product);
                    final double prixOriginal = productPriceInfo['prixOriginal'];
                    final double prixPromo = productPriceInfo['prixPromo'];
                    final bool hasPromotion = productPriceInfo['hasPromotion'];
                    final int promotionPercentage = productPriceInfo['promotionPercentage'];
                    final double totalLigne = prixPromo * quantite;
                    final double economieLigne = hasPromotion ? (prixOriginal - prixPromo) * quantite : 0;

                    // Gestion des images
                    String imageUrl = '';
                    if (product['images'] != null && product['images'].isNotEmpty) {
                      if (product['images'] is List) {
                        final firstImage = product['images'][0];
                        if (firstImage is Map && firstImage['path'] != null) {
                          imageUrl = firstImage['path'];
                        }
                      }
                    }

                    return Dismissible(
                      key: Key('${product['id']}-$index'),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        cart.removeItem(product['id']);
                      },
                      child: Card(
                        margin: EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Image du produit avec badge promotion
                              Stack(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[200],
                                    ),
                                    child: imageUrl.isNotEmpty 
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              "$baseUrl$imageUrl",
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(Icons.shopping_bag, color: Colors.grey[400]);
                                              },
                                            ),
                                          )
                                        : Icon(Icons.shopping_bag, color: Colors.grey[400]),
                                  ),
                                  if (hasPromotion)
                                    Positioned(
                                      top: -5,
                                      right: -5,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '-$promotionPercentage%',
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
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['nom']?.toString() ?? 'Produit sans nom',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    
                                    // Affichage du prix avec promotion
                                    if (hasPromotion)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${prixOriginal.toStringAsFixed(2)}DNT',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 14,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '${prixPromo.toStringAsFixed(2)}DNT',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        '${prixOriginal.toStringAsFixed(2)}DNT',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    
                                    // Économie sur la ligne
                                    if (economieLigne > 0)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Économie: ${economieLigne.toStringAsFixed(2)}DNT',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () {
                                          if (quantite > 1) {
                                            cart.updateQuantity(product['id'], quantite - 1);
                                          } else {
                                            cart.removeItem(product['id']);
                                          }
                                        },
                                      ),
                                      Container(
                                        width: 30,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$quantite',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add_circle, color: Colors.green),
                                        onPressed: () {
                                          cart.updateQuantity(product['id'], quantite + 1);
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${totalLigne.toStringAsFixed(2)}DNT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Section total avec promotions
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      offset: Offset(0, -2),
                      blurRadius: 4,
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Récapitulatif des prix
                      if (hasPromotions) ...[
                        _buildPriceRow('Sous-total', sousTotal.toStringAsFixed(2) + 'DNT'),
                        _buildPriceRow(
                          'Économies',
                          '-${totalEconomies.toStringAsFixed(2)}DNT',
                          isDiscount: true,
                        ),
                        Divider(),
                      ],
                      _buildPriceRow(
                        'Total',
                        totalAPayer.toStringAsFixed(2) + 'DNT',
                        isTotal: true,
                      ),
                      
                      // Badge économies totales
                      if (hasPromotions && totalEconomies > 0)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 12, top: 8),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.savings, color: Colors.green[700], size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Vous économisez ${totalEconomies.toStringAsFixed(2)}DNT',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _showClearCartDialog(context, cart);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Vider le panier',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final estConnecte = await isConnecter();

                                if (!estConnecte) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Veuillez vous connecter pour commander des produits."),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  Navigator.pushNamed(context, '/login');
                                  return;
                                }

                                _showOrderDialog(context, cart, totalAPayer);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Commander',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Méthode pour calculer les prix d'un produit avec promotions
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

  // Méthode pour calculer les totaux du panier
  Map<String, dynamic> _calculateCartTotals(List<dynamic> items) {
    double sousTotal = 0;
    double totalEconomies = 0;
    bool hasPromotions = false;

    for (final item in items) {
      final product = item['product'] as Map<String, dynamic>;
      final quantite = item['quantite'] as int;
      
      final priceInfo = _calculateProductPrice(product);
      final double prixOriginal = priceInfo['prixOriginal'];
      final double prixPromo = priceInfo['prixPromo'];
      final bool hasPromotion = priceInfo['hasPromotion'];
      
      sousTotal += prixOriginal * quantite;
      totalEconomies += (prixOriginal - prixPromo) * quantite;
      
      if (hasPromotion) {
        hasPromotions = true;
      }
    }

    final double totalAPayer = sousTotal - totalEconomies;

    return {
      'sousTotal': sousTotal,
      'totalEconomies': totalEconomies,
      'totalAPayer': totalAPayer,
      'hasPromotions': hasPromotions,
    };
  }

  // Méthodes utilitaires pour les promotions
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

  // Widget pour afficher une ligne de prix
  Widget _buildPriceRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.blue : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isDiscount ? Colors.green[700] : 
                     isTotal ? Colors.blue : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vider le panier'),
        content: Text('Êtes-vous sûr de vouloir vider votre panier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Panier vidé avec succès')),
              );
            },
            child: Text(
              'Vider',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDialog(BuildContext context, CartProvider cart, double totalAPayer) {
    final cartTotals = _calculateCartTotals(cart.items);
    final double sousTotal = cartTotals['sousTotal'];
    final double totalEconomies = cartTotals['totalEconomies'];
    final bool hasPromotions = cartTotals['hasPromotions'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Récapitulatif de votre commande:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            
            if (hasPromotions) ...[
              _buildOrderPriceRow('Sous-total:', '${sousTotal.toStringAsFixed(2)}DNT'),
              _buildOrderPriceRow('Économies:', '-${totalEconomies.toStringAsFixed(2)}DNT', isDiscount: true),
              SizedBox(height: 8),
            ],
            
            _buildOrderPriceRow(
              'Total à payer:', 
              '${totalAPayer.toStringAsFixed(2)}DNT', 
              isTotal: true
            ),
            
            if (hasPromotions && totalEconomies > 0)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🎉 Félicitations ! Vous économisez ${totalEconomies.toStringAsFixed(2)}DNT',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            SizedBox(height: 16),
            Text('Confirmez-vous cette commande ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Convertir les items du panier en format pour l'API
                final lignes = cart.items.map((item) {
                  return {
                    'produitId': item['product']['id'],
                    'quantite': item['quantite'],
                  };
                }).toList();

                // Appeler l'API pour créer la commande
                final result = await CommandeAPI.createCommande(lignes);
                
                // Vider le panier seulement si la commande est créée avec succès
                final itemsCount = cart.totalItems;
                cart.clearCart();
                
                Navigator.pop(context);

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Commande de $itemsCount articles pour ${totalAPayer.toStringAsFixed(2)}DNT passée avec succès!'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la commande: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPriceRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isDiscount ? Colors.green[700] : 
                     isTotal ? Colors.blue : null,
            ),
          ),
        ],
      ),
    );
  }
}