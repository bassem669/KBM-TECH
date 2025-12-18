// lib/pages/produit_detail_page.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import '../fetch/avis_api.dart';
import '../fetch/produit_api.dart';
import '../fetch/panier_api.dart';
import './../fetch/auth_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'avis_list_page.dart'; 
import './../fetch/liste_souhait_api.dart';
final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';

// Service de liste de souhaits

class ProduitDetailPage extends StatefulWidget {
  final Map<String, dynamic> produit;
  const ProduitDetailPage({super.key, required this.produit});

  @override
  State<ProduitDetailPage> createState() => _ProduitDetailPageState();
}

class _ProduitDetailPageState extends State<ProduitDetailPage> {
  final _avisCtrl = TextEditingController();
  final WishlistService _wishlistService = WishlistService();
  
  int _userId = 0;
  int _note = 5;
  int _quantite = 1;
  bool _loadingAvis = false;
  bool _loadingPanier = false;
  bool _loadingAvisList = false;
  List<dynamic> _avis = [];
  List<dynamic> _tousLesAvis = [];
  Map<String, dynamic>? _produitDetail;
  bool _loadingDetail = false;
  int _currentImageIndex = 0;

  // Pour gérer l'avis de l'utilisateur connecté
  Map<String, dynamic>? _monAvis;
  bool _loadingMonAvis = false;
  bool _modificationEnCours = false;
  TextEditingController? _modificationAvisCtrl;
  int _noteModification = 5;
  
  // Pour la liste de souhaits
  bool _isInWishlist = false;
  bool _loadingWishlist = false;

  @override
  void initState() {
    super.initState();
    _chargerDetailsProduit();
    _chargerAvisProduit();
    _checkWishlistStatus();
  }

  @override
  void dispose() {
    _avisCtrl.dispose();
    _modificationAvisCtrl?.dispose();
    super.dispose();
  }

  Future<bool> isConnecter() async {
    final token = await AuthAPI.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _checkWishlistStatus() async {
    final isInWishlist = await _wishlistService.isInWishlist(widget.produit['id']);
    setState(() {
      _isInWishlist = isInWishlist;
    });
  }

  Future<void> _toggleWishlist() async {
    if (_loadingWishlist) return;
    
    setState(() {
      _loadingWishlist = true;
    });

    try {
      final produit = _produitDetail ?? widget.produit;
      
      if (_isInWishlist) {
        await _wishlistService.removeFromWishlist(produit['id']);
        setState(() {
          _isInWishlist = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite_border, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Retiré de la liste de souhaits'),
              ],
            ),
            backgroundColor: Colors.grey[600],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await _wishlistService.addToWishlist(produit);
        setState(() {
          _isInWishlist = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Ajouté à la liste de souhaits !'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loadingWishlist = false;
      });
    }
  }

  Future<void> _chargerDetailsProduit() async {
    setState(() {
      _loadingDetail = true;
    });

    try {
      final produitId = widget.produit['id'];
      final details = await ProduitAPI.fetchProdDetails(produitId);

      
      if (details.isNotEmpty && details['erreur'] == null) {
        setState(() {
          _produitDetail = details;
        });
      } else {
        _showErrorSnackBar('Erreur lors du chargement des détails du produit');
      }
    } catch (e) {
      print("Erreur chargement détail: $e");
      _showErrorSnackBar('Erreur de connexion lors du chargement des détails');
    } finally {
      setState(() {
        _loadingDetail = false;
      });
    }
  }

  Future<void> _chargerAvisProduit() async {
    setState(() {
      _loadingAvisList = true;
      _loadingMonAvis = true;
    });

    try {
      final produitId = widget.produit['id'];
      final user = await AuthAPI.getUser();
      _userId = user?["id"] ?? 0;

      final avisData = await AvisAPI.fetchAvisParProduit(produitId);
      final monAvisData = await AvisAPI.getMonAvisPourProduit(produitId);
      
      if (avisData['success'] == true) {
        setState(() {
          _tousLesAvis = avisData['data'] ?? [];
          _avis = _tousLesAvis.take(3).toList();
        });
      } else {
        _showErrorSnackBar('Erreur lors du chargement des avis');
      }
      
      if (monAvisData['success'] == true) {
        setState(() {
          _monAvis = monAvisData['data'];
        });
      }
      
    } catch (e) {
      print("Erreur chargement avis: $e");
      _showErrorSnackBar('Erreur de connexion lors du chargement des avis');
    } finally {
      setState(() {
        _loadingAvisList = false;
        _loadingMonAvis = false;
      });
    }
  }

  Future<void> _ajouterPanier() async {
    if (_loadingPanier) return;
    
    setState(() {
      _loadingPanier = true;
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final produit = _produitDetail ?? widget.produit;
      int stock = cartProvider.getQuantiteProduits(produit["id"]);

      if (stock == 0) {
        await cartProvider.addItem(produit);
      } else {
        await cartProvider.updateQuantity(produit["id"], _quantite);
      }
      
      _showSuccessSnackBar('$_quantite produit(s) ajouté(s) au panier');
    } catch (e) {
      _showErrorSnackBar('Erreur: ${e.toString()}');
    } finally {
      setState(() {
        _loadingPanier = false;
      });
    }
  }

  Future<void> _envoyerAvis() async {
    if (_loadingAvis || _avisCtrl.text.trim().isEmpty) return;

    setState(() {
      _loadingAvis = true;
    });

    try {
      final produitId = widget.produit['id'];
      final result = await AvisAPI.ajouter(
        produitId, 
        _avisCtrl.text.trim(), 
        _note
      );
      
      if (result['success'] == true) {
        await _chargerAvisProduit();
        _avisCtrl.clear();
        setState(() {
          _note = 5;
        });
        _showSuccessSnackBar('Avis envoyé avec succès');
      } else {
        throw Exception(result['message'] ?? 'Erreur lors de l\'envoi de l\'avis');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: ${e.toString()}');
    } finally {
      setState(() {
        _loadingAvis = false;
      });
    }
  }

  bool _estMonAvis(Map<String, dynamic> avis) {
    final clientId = avis['client_id'];
    return clientId == _userId;
  }

  Future<void> _modifierAvis(Map<String, dynamic> avis) async {
    final avisId = avis['id'];
    
    _modificationAvisCtrl = TextEditingController(text: avis['message'] ?? '');
    _noteModification = avis['note'] ?? 5;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier mon avis'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Note",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _noteModification ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _noteModification = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_noteModification/5 étoiles',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _modificationAvisCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: "Modifiez votre commentaire...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _modificationEnCours ? null : () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _modificationEnCours ? null : () => _confirmerModification(avisId),
              child: _modificationEnCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerModification(int avisId) async {
    if (_modificationAvisCtrl == null || _modificationAvisCtrl!.text.trim().isEmpty) {
      _showErrorSnackBar('Veuillez saisir un commentaire');
      return;
    }

    setState(() => _modificationEnCours = true);
    
    try {
      final result = await AvisAPI.modifier(
        avisId, 
        _modificationAvisCtrl!.text.trim(), 
        _noteModification
      );
      
      if (result['success'] == true) {
        if (context.mounted) Navigator.pop(context);
        await _chargerAvisProduit();
        _showSuccessSnackBar('Avis modifié avec succès');
      } else {
        _showErrorSnackBar(result['message'] ?? 'Erreur lors de la modification');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: ${e.toString()}');
    } finally {
      setState(() => _modificationEnCours = false);
    }
  }

  Future<void> _supprimerAvis(Map<String, dynamic> avis) async {
    final avisId = avis['id'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'avis'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet avis ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _confirmerSuppression(avisId),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerSuppression(int avisId) async {
    try {
      final result = await AvisAPI.supprimer(avisId);
      
      if (result['success'] == true) {
        if (context.mounted) Navigator.pop(context);
        await _chargerAvisProduit();
        _showSuccessSnackBar('Avis supprimé avec succès');
      } else {
        _showErrorSnackBar(result['message'] ?? 'Erreur lors de la suppression');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: ${e.toString()}');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Méthodes utilitaires
  double _getAvisMoyenne() {
    if (_tousLesAvis.isNotEmpty) {
      final totalNotes = _tousLesAvis.fold(0.0, (sum, avis) {
        final note = (avis['note'] ?? avis['rating'] ?? 0).toDouble();
        return sum + note;
      });
      return totalNotes / _tousLesAvis.length;
    }
    
    final produit = _produitDetail ?? widget.produit;
    final avisMoyenne = produit['avisMoyenne'];
    if (avisMoyenne is String) {
      return double.tryParse(avisMoyenne) ?? 0.0;
    } else if (avisMoyenne is num) {
      return avisMoyenne.toDouble();
    }
    return 0.0;
  }

  int _getNbAvis() {
    if (_tousLesAvis.isNotEmpty) {
      return _tousLesAvis.length;
    }
    
    final produit = _produitDetail ?? widget.produit;
    return produit['nbAvis'] ?? 0;
  }

  bool _hasPromotion() {
    final produit = _produitDetail ?? widget.produit;
    final promotions = produit['promotions'] as List<dynamic>?;
    if (promotions == null || promotions.isEmpty) return false;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      
      if (dateDebut != null && dateFin != null) {
        if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
          return true;
        }
      }
    }
    return false;
  }

  double _getPrixPromo() {
    final produit = _produitDetail ?? widget.produit;
    final prixOriginal = _getPrixOriginal();
    final promotions = produit['promotions'] as List<dynamic>?;
    
    if (promotions == null || promotions.isEmpty) return prixOriginal;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      final pourcentage = promo['pourcentage'] is num ? promo['pourcentage'].toDouble() : 0.0;
      
      if (dateDebut != null && dateFin != null) {
        if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
          return prixOriginal * (1 - pourcentage / 100);
        }
      }
    }
    return prixOriginal;
  }

  int _getPourcentagePromo() {
    final produit = _produitDetail ?? widget.produit;
    final promotions = produit['promotions'] as List<dynamic>?;
    if (promotions == null || promotions.isEmpty) return 0;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      
      if (dateDebut != null && dateFin != null) {
        if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
          return promo['pourcentage'] is num ? promo['pourcentage'].toInt() : 0;
        }
      }
    }
    return 0;
  }

  List<dynamic> _getImages() {
    final produit = _produitDetail ?? widget.produit;
    return produit['images'] as List? ?? [];
  }

  String _getDescription() {
    final produit = _produitDetail ?? widget.produit;
    return produit['description']?.toString() ?? 'Aucune description disponible.';
  }

  int _getStock() {
    final produit = _produitDetail ?? widget.produit;
    return produit['quantite'] ?? 0;
  }

  String _getNom() {
    final produit = _produitDetail ?? widget.produit;
    return produit['nom']?.toString() ?? 'Produit sans nom';
  }

  String _getCategorie() {
    final produit = _produitDetail ?? widget.produit;
    final categories = produit['categories'] as List?;
    if (categories != null && categories.isNotEmpty) {
      return categories.first['nom']?.toString() ?? '';
    }
    return '';
  }

  double _getPrixOriginal() {
    final produit = _produitDetail ?? widget.produit;
    return (produit['prix'] is num ? produit['prix'].toDouble() : double.tryParse(produit['prix'].toString()) ?? 0.0);
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star_rounded : 
          (index == rating.floor() && rating % 1 >= 0.5) ? Icons.star_half_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Widget _buildImageCarousel() {
    final images = _getImages();
    
    if (images.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Icon(Icons.shopping_bag_rounded, size: 80, color: Colors.grey[400]),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: CarouselSlider(
            items: images.map((image) {
              final imageUrl = image['path'] ?? '';
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Image.network(
                  imageUrl.isNotEmpty ? "$baseUrl$imageUrl" : "https://via.placeholder.com/400",
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              );
            }).toList(),
            options: CarouselOptions(
              height: 400,
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: 1.0,
              aspectRatio: 1.0,
              autoPlayInterval: const Duration(seconds: 4),
              onPageChanged: (index, reason) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
            ),
          ),
        ),
        if (images.length > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: images.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == entry.key
                        ? const Color(0xFF0066FF)
                        : Colors.grey[300],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildProductHeader() {
    final hasPromotion = _hasPromotion();
    final prixOriginal = _getPrixOriginal();
    final prixPromo = _getPrixPromo();
    final avisMoyenne = _getAvisMoyenne();
    final nbAvis = _getNbAvis();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getNom(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              if (_getCategorie().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getCategorie(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0066FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasPromotion)
                  Text(
                    '${prixOriginal.toStringAsFixed(2)}DNT',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  hasPromotion ? '${prixPromo.toStringAsFixed(2)}DNT' : '${prixOriginal.toStringAsFixed(2)}DNT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: hasPromotion ? const Color(0xFFFF6B6B) : Color(0xFF0066FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    avisMoyenne.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[800],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($nbAvis)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockStatus() {
    final stock = _getStock();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stock > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stock > 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            stock > 0 ? Icons.check_circle_rounded : Icons.error_rounded,
            color: stock > 0 ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stock > 0 
                ? 'En stock - $stock disponibles'
                : 'Rupture de stock',
              style: TextStyle(
                fontSize: 16,
                color: stock > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityAndCart() {
    final stock = _getStock();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Quantité",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      onPressed: _quantite > 1
                          ? () => setState(() => _quantite--)
                          : null,
                      style: IconButton.styleFrom(
                        foregroundColor: _quantite > 1 ? const Color(0xFF0066FF) : Colors.grey,
                      ),
                    ),
                    Container(
                      width: 40,
                      child: Text(
                        '$_quantite',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      onPressed: _quantite < stock
                          ? () => setState(() => _quantite++)
                          : null,
                      style: IconButton.styleFrom(
                        foregroundColor: _quantite < stock ? const Color(0xFF0066FF) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // BOUTONS CÔTE À CÔTE
          Row(
            children: [
              // BOUTON COEUR - LISTE DE SOUHAITS
              Expanded(
                flex: 1,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isInWishlist ? Colors.red.withOpacity(0.3) : Colors.grey[300]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: _loadingWishlist
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : Icon(
                            _isInWishlist ? Icons.favorite : Icons.favorite_border,
                            color: _isInWishlist ? Colors.red : Colors.grey[700],
                            size: 24,
                          ),
                    onPressed: _toggleWishlist,
                    tooltip: _isInWishlist ? 'Retirer des souhaits' : 'Ajouter aux souhaits',
                  ),
                ),
              ),
              
              const SizedBox(width: 2),
              
              // BOUTON AJOUTER AU PANIER
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: stock > 0 && !_loadingPanier ? _ajouterPanier : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF0066FF).withOpacity(0.3),
                    ),
                    child: _loadingPanier
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                stock > 0 ? "Ajouter au panier" : "Rupture de stock",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final avisMoyenne = _getAvisMoyenne();
    final nbAvis = _getNbAvis();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Avis clients",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (nbAvis > 0)
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AvisListPage(
                        userId: _userId,
                        produitId: widget.produit['id'],
                        produitNom: _getNom(),
                        noteMoyenne: avisMoyenne,
                        totalAvis: nbAvis,
                        avis: _tousLesAvis,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  'Voir tous ($nbAvis)',
                  style: const TextStyle(
                    color: Color(0xFF0066FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (_loadingAvisList)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0066FF),
              ),
            ),
          )
        else if (_avis.isNotEmpty)
          Column(
            children: [
              ..._avis.map((avis) => _AvisCard(
                avis: avis,
                isCurrentUser: _estMonAvis(avis),
                onModifier: _estMonAvis(avis) ? _modifierAvis : null,
                onSupprimer: _estMonAvis(avis) ? _supprimerAvis : null,
              )).toList(),
              
              if (_tousLesAvis.length > 3)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AvisListPage(
                            userId: _userId,
                            produitId: widget.produit['id'],
                            produitNom: _getNom(),
                            noteMoyenne: avisMoyenne,
                            totalAvis: nbAvis,
                            avis: _tousLesAvis,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0066FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Voir les ${_tousLesAvis.length - 3} autres avis',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.reviews_rounded, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Aucun avis pour le moment",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Soyez le premier à donner votre avis !",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvisForm() {
    if (_monAvis != null) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Vous avez déjà donné votre avis",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Vous pouvez le modifier ou le supprimer en utilisant les options sur votre avis.",
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Donner votre avis",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Note",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _note ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _note = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$_note/5 étoiles',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Votre commentaire",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _avisCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Partagez votre expérience avec ce produit...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0066FF)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loadingAvis
                ? null
                : () async {
                    final estConnecte = await isConnecter();

                    if (!estConnecte) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Veuillez vous connecter pour envoyer un avis."),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );

                      Navigator.pushNamed(context, '/login');
                      return;
                    }

                    _envoyerAvis();
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loadingAvis
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      "Envoyer mon avis",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPromotion = _hasPromotion();
    final pourcentagePromo = _getPourcentagePromo();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              // BOUTON COEUR DANS L'APP BAR
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _loadingWishlist
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : Icon(
                          _isInWishlist ? Icons.favorite : Icons.favorite_border,
                          color: _isInWishlist ? Colors.red : Colors.black87,
                        ),
                  onPressed: _toggleWishlist,
                  tooltip: _isInWishlist ? 'Retirer des souhaits' : 'Ajouter aux souhaits',
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.black87),
                  onPressed: () {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  _buildImageCarousel(),
                  
                  if (hasPromotion)
                    Positioned(
                      top: 70,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          '-$pourcentagePromo%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _loadingDetail
                ? Container(
                    height: 200,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.only(top: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProductHeader(),
                          const SizedBox(height: 24),
                          _buildStockStatus(),
                          const SizedBox(height: 24),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Description",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _getDescription(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                          _buildQuantityAndCart(),
                          const SizedBox(height: 32),
                          _buildReviewsSection(),
                          _buildAvisForm(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AvisCard extends StatelessWidget {
  final Map<String, dynamic> avis;
  final Function(Map<String, dynamic>)? onModifier;
  final Function(Map<String, dynamic>)? onSupprimer;
  final bool isCurrentUser;

  const _AvisCard({
    required this.avis,
    this.onModifier,
    this.onSupprimer,
    required this.isCurrentUser,
  });

  double _getNote() {
    return (avis['note'] ?? avis['rating'] ?? 0).toDouble();
  }

  String _getCommentaire() {
    return avis['message']?.toString() ?? 
           avis['commentaire']?.toString() ?? 
           avis['comment']?.toString() ?? 
           '';
  }

  Map<String, dynamic>? _getUtilisateur() {
    return avis['utilisateur'] ?? avis['client'] ?? avis['user'];
  }

  String _getDateCreation() {
    return avis['date_avis']?.toString() ?? 
           avis['createdAt']?.toString() ?? 
           avis['date']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final note = _getNote();
    final commentaire = _getCommentaire();
    final utilisateur = _getUtilisateur();
    final nomUtilisateur = utilisateur?['nom']?.toString() ?? 'Utilisateur';
    final prenomUtilisateur = utilisateur?['prenom']?.toString() ?? 'Utilisateur';
    final dateCreation = _getDateCreation();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isCurrentUser 
                    ? const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF0099FF)])
                    : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${prenomUtilisateur.isNotEmpty ? prenomUtilisateur[0].toUpperCase() : 'U'}${nomUtilisateur.isNotEmpty ? nomUtilisateur[0].toUpperCase() : 'U'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '$prenomUtilisateur $nomUtilisateur',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              if (dateCreation.isNotEmpty)
                                Text(
                                  _formatDate(dateCreation),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    note.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isCurrentUser && onModifier != null && onSupprimer != null)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                                onSelected: (value) {
                                  if (value == 'modifier') onModifier!(avis);
                                  if (value == 'supprimer') onSupprimer!(avis);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'modifier',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Modifier'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'supprimer',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      commentaire,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return "Aujourd'hui";
      } else if (difference.inDays == 1) {
        return "Hier";
      } else if (difference.inDays < 7) {
        return "Il y a ${difference.inDays} jours";
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}