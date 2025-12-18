// pages/admin_produit_page.dart
import 'package:flutter/material.dart';
import '../../fetch/produit_api.dart';
import '../../fetch/admin_produit_service.dart';
import 'admin_produit_form_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';

class AdminProduitPage extends StatefulWidget {
  @override
  _AdminProduitPageState createState() => _AdminProduitPageState();
}

class _AdminProduitPageState extends State<AdminProduitPage> {
  // Variables de pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalProducts = 0;
  int _itemsPerPage = 10;
  
  List<dynamic> _allProduits = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _showSearch = false;
  bool _hasMore = true;

  Map<String, dynamic>? _currentProductForBuild;

  // Controller pour la pagination infinie
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProduits(reset: true);
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == 
          _scrollController.position.maxScrollExtent) {
        _loadMoreProduits();
      }
    });
  }

  Future<void> _loadProduits({bool reset = false, int page = 1}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _allProduits = [];
        _isLoading = true;
      });
    }

    try {
      final result = await ProduitAPI.fetchAllProduits(
        page: page,
        limit: _itemsPerPage,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _allProduits = List.from(result['data'] ?? []);
          } else {
            _allProduits.addAll(result['data'] ?? []);
          }
          
          _totalProducts = result['total'] ?? 0;
          _totalPages = result['pages'] ?? 1;
          _currentPage = page;
          _hasMore = page < _totalPages;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('❌ Erreur chargement produits: $error');
    }
  }

  Future<void> _loadMoreProduits() async {
    if (_isLoading || !_hasMore) return;

    final nextPage = _currentPage + 1;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ProduitAPI.fetchAllProduits(
        page: nextPage,
        limit: _itemsPerPage,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _allProduits.addAll(result['data'] ?? []);
          _currentPage = nextPage;
          _hasMore = nextPage < _totalPages;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('❌ Erreur chargement produits supplémentaires: $error');
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    
    // Débounce la recherche pour éviter trop d'appels API
    Future.delayed(Duration(milliseconds: 500), () {
      if (_searchQuery == query) {
        _loadProduits(reset: true);
      }
    });
  }

  void _handleAuthError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session expirée. Veuillez vous reconnecter.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Se connecter',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
    );
  }

  bool _hasActivePromotion(Map<String, dynamic> produit) {
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

  double _getCurrentPrice(Map<String, dynamic> produit) {
    final hasPromo = _hasActivePromotion(produit);
    final originalPrice = _safeParseDouble(produit['prix']);
    
    if (!hasPromo) return originalPrice;
    
    final promotions = produit['promotions'] as List? ?? [];
    for (var promo in promotions) {
      final dateDebut = DateTime.parse(promo['dateDebut']);
      final dateFin = DateTime.parse(promo['dateFin']);
      final now = DateTime.now();
      
      if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        final discountType = promo['typeRemise']?.toString() ?? 'pourcentage';
        final discountValue = _safeParseDouble(promo['pourcentage']);
        
        if (discountType == 'pourcentage') {
          return originalPrice * (1 - discountValue / 100);
        } else if (discountType == 'fixe') {
          return (originalPrice - discountValue).clamp(0, double.infinity);
        }
      }
    }
    
    return originalPrice;
  }

  double _getDiscountPercentage(Map<String, dynamic> produit) {
    final hasPromo = _hasActivePromotion(produit);
    if (!hasPromo) return 0.0;
    
    final originalPrice = _safeParseDouble(produit['prix']);
    final currentPrice = _getCurrentPrice(produit);
    
    if (originalPrice <= 0) return 0.0;
    
    return ((originalPrice - currentPrice) / originalPrice * 100);
  }

  String _getFirstImageUrl(Map<String, dynamic> produit) {
    try {
      final images = produit['images'] as List? ?? [];
      
      if (images.isEmpty) {
        return '';
      }

      final firstImage = images.first;
      
      // Use the same logic that works in accueil_page
      return _extractImageUrl(firstImage);
    } catch (e) {
      print('Error getting image URL: $e');
      return '';
    }
  }

  String _extractImageUrl(dynamic imageData) {
    try {
      if (imageData == null) return '';
      
      // If imageData is already a URL string
      if (imageData is String) {
        return imageData.startsWith('http') ? imageData : '$baseUrl$imageData';
      }
      
      // If imageData is a Map, try different field names
      if (imageData is Map) {
        // Try all possible field names for image path/URL

          final value = imageData["path"];
          if (value is String && value.isNotEmpty) {
            // Ensure proper URL construction - same as accueil_page
            return '$baseUrl$value';
          }
      }
      
      return '';
    } catch (e) {
      print('Error extracting image URL: $e');
      return '';
    }
  }

  double _getAvisMoyenne(Map<String, dynamic> produit) {
    final avisMoyenne = produit['avisMoyenne'];
    if (avisMoyenne == null) return 0.0;
    
    if (avisMoyenne is String) {
      return double.tryParse(avisMoyenne) ?? 0.0;
    } else if (avisMoyenne is int) {
      return avisMoyenne.toDouble();
    } else if (avisMoyenne is double) {
      return avisMoyenne;
    }
    return 0.0;
  }

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }
    return 0.0;
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    } else if (value is int) {
      return value;
    } else if (value is double) {
      return value.toInt();
    }
    return 0;
  }

  Future<void> _deleteProduit(int id, String nom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer "$nom" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() { _isLoading = true; });

      try {
        await AdminProduitService.deleteProduit(id);
        _loadProduits(reset: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (e.toString().contains('Token non disponible') || 
            e.toString().contains('Non autorisé') || 
            e.toString().contains('Accès refusé')) {
          _handleAuthError();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  Widget _buildProductImage(String imageUrl, bool isActive) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: imageUrl.isNotEmpty 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print('Admin image error: $error');
                  print('Failed URL: $imageUrl');
                  return _buildPlaceholderIcon(isActive);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  );
                },
              ),
            )
          : _buildPlaceholderIcon(isActive),
    );
  }

  Widget _buildPlaceholderIcon(bool isActive) {
    return Icon(
      Icons.shopping_bag, 
      color: isActive ? Colors.grey : Colors.grey[400],
      size: 30,
    );
  }

  Widget _buildPriceDisplay(double originalPrice, double currentPrice, bool hasPromo) {
    if (!hasPromo) {
      return Text(
        '${originalPrice.toStringAsFixed(2)} DNT',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original price with strikethrough
        Text(
          '${originalPrice.toStringAsFixed(2)} DNT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        SizedBox(height: 2),
        // Current price with discount
        Row(
          children: [
            Text(
              '${currentPrice.toStringAsFixed(2)} DNT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '-${_getDiscountPercentage(_currentProductForBuild!).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> produit) {
    _currentProductForBuild = produit;
    
    final hasPromo = _hasActivePromotion(produit);
    final imageUrl = _getFirstImageUrl(produit);
    final rating = _getAvisMoyenne(produit);
    final stock = _safeParseInt(produit['quantite']);
    final originalPrice = _safeParseDouble(produit['prix']);
    final currentPrice = _getCurrentPrice(produit);
    final isActive = produit['estActive'] ?? true;
    final discountPercent = _getDiscountPercentage(produit);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () => _showProductOptions(produit),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with image and basic info
              Row(
                children: [
                  // Product image
                  _buildProductImage(imageUrl, isActive),
                  SizedBox(width: 12),
                  
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                produit['nom']?.toString() ?? 'Sans nom',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isActive ? Colors.black : Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isActive)
                              Icon(Icons.visibility_off, size: 16, color: Colors.grey),
                          ],
                        ),
                        SizedBox(height: 4),
                        
                        // PRICE DISPLAY
                        _buildPriceDisplay(originalPrice, currentPrice, hasPromo),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Stats row
              Row(
                children: [
                  // Rating
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  
                  // Stock
                  Row(
                    children: [
                      Icon(
                        stock > 0 ? Icons.inventory : Icons.inventory_2,
                        color: stock > 0 ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        stock.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: stock > 0 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  
                  Spacer(),
                  
                  // Promotion badge with discount percentage
                  if (hasPromo)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PROMO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '-${discountPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit,
                      text: 'Modifier',
                      color: Colors.blue,
                      onTap: () => _navigateToEdit(produit),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete,
                      text: 'Supprimer',
                      color: Colors.red,
                      onTap: () => _deleteProduit(
                        _safeParseInt(produit['id']),
                        produit['nom']?.toString() ?? 'Sans nom',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductOptions(Map<String, dynamic> produit) {
    final hasPromo = _hasActivePromotion(produit);
    final originalPrice = _safeParseDouble(produit['prix']);
    final currentPrice = _getCurrentPrice(produit);
    final discountPercent = _getDiscountPercentage(produit);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.info, color: Colors.blue),
                title: Text('Détails du produit'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(produit['nom']?.toString() ?? 'Sans nom'),
                    SizedBox(height: 4),
                    // Price details in options
                    if (hasPromo) ...[
                      Text(
                        'Prix original: ${originalPrice.toStringAsFixed(2)} DNT',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        'Prix actuel: ${currentPrice.toStringAsFixed(2)} DNT (-${discountPercent.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Prix: ${originalPrice.toStringAsFixed(2)} DNT',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEdit(produit);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Supprimer'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProduit(
                    _safeParseInt(produit['id']),
                    produit['nom']?.toString() ?? 'Sans nom',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _managePromotions(Map<String, dynamic> produit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gestion des promotions pour ${produit['nom']}'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _navigateToEdit(Map<String, dynamic> produit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminProduitFormPage(
          produit: produit,
          onSave: () => _loadProduits(reset: true),
        ),
      ),
    );
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminProduitFormPage(
          onSave: () => _loadProduits(reset: true),
        ),
      ),
    );
  }

  Widget _buildPaginationInfo() {
    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    final endIndex = startIndex + _allProduits.length - 1;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Produits ${startIndex}-${endIndex} sur $_totalProducts',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (_totalPages > 1)
            Text(
              'Page $_currentPage/$_totalPages',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _allProduits.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Tous les produits sont chargés',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (_isLoading && _allProduits.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 8),
              Text(
                'Chargement...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildItemsPerPageSelector() {
    return PopupMenuButton<int>(
      icon: Icon(Icons.tune, color: Colors.white),
      onSelected: (value) {
        setState(() {
          _itemsPerPage = value;
        });
        _loadProduits(reset: true);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 10, child: Text('10 produits par page')),
        PopupMenuItem(value: 20, child: Text('20 produits par page')),
        PopupMenuItem(value: 50, child: Text('50 produits par page')),
      ],
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_searchQuery.isNotEmpty) {
      message = 'Aucun produit correspondant à "$_searchQuery"';
    } else {
      message = 'Aucun produit trouvé';
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            if (!_searchQuery.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: Icon(Icons.add),
                label: Text('Ajouter un produit'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            if (_searchQuery.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _loadProduits(reset: true);
                },
                icon: Icon(Icons.clear),
                label: Text('Effacer la recherche'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
              )
            : Text('Gestion des Produits ($_totalProducts)'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          if (!_showSearch) ...[
            _buildItemsPerPageSelector(),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = true;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () => _loadProduits(reset: true),
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _showSearch = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
                _loadProduits(reset: true);
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_isLoading && _allProduits.isEmpty) 
            LinearProgressIndicator(),
          
          if (_allProduits.isNotEmpty)
            _buildPaginationInfo(),
          
          Expanded(
            child: _allProduits.isEmpty && !_isLoading
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async => _loadProduits(reset: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: _allProduits.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _allProduits.length) {
                          return _buildLoadMoreIndicator();
                        }
                        
                        final produit = _allProduits[index];
                        return _buildProductCard(produit);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAdd,
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}