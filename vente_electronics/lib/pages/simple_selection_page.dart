// pages/dynamic_selection_page.dart
import 'package:flutter/material.dart';
import 'package:vente_electronics/fetch/categorie_api.dart';
import 'package:vente_electronics/fetch/produit_api.dart';
import 'simple_comparaison_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class DynamicSelectionPage extends StatefulWidget {
  const DynamicSelectionPage({Key? key}) : super(key: key);

  @override
  _DynamicSelectionPageState createState() => _DynamicSelectionPageState();
}

class _DynamicSelectionPageState extends State<DynamicSelectionPage> {
    static String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://192.168.1.54:5000/api/';

  List<dynamic> _categories = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  String _selectedCategory = 'Tous';
  final List<int> _selectedIds = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  String _error = '';
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  final int _limit = 10;
  int _totalResults = 0;
  int _totalPages = 1;
  bool _hasMore = true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        _hasMore &&
        !_loadingMore &&
        mounted) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadInitialData() async {
    _resetPagination();

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = '';
        });
      }

      // Charger les catégories
      final categories = await CategorieAPI.getAllCategories();
      
      // Corriger la structure des catégories
      List<dynamic> categoriesList = [];

      categoriesList = [categories];

      // Charger les produits
      final Map<String, dynamic> productsResult = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
      );

      final productsData = (productsResult['data'] as List<dynamic>?) ?? [];
      
      // Filtrer les produits avec IDs valides
      final validProducts = productsData.where((product) {
        if (product is! Map<String, dynamic>) return false;
        final productId = product['id'];
        return productId != null && productId is int;
      }).toList();

      if (mounted) {
        setState(() {
          _categories = categoriesList;
          _allProducts = validProducts;
          _filteredProducts = List.from(validProducts);
          _totalResults = (productsResult['total'] as int?) ?? 0;
          _totalPages = (productsResult['pages'] as int?) ?? 1;
          _hasMore = _currentPage < _totalPages;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Erreur loadInitialData: $e');
      if (mounted) {
        setState(() {
          _error = 'Erreur de chargement: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_loadingMore || !_hasMore || !mounted) return;

    setState(() {
      _loadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final Map<String, dynamic> productsResult = await ProduitAPI.fetchAllProduits(
        page: nextPage,
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categorie: _selectedCategory != 'Tous' ? _getCategoryId(_selectedCategory) : null,
      );

      if (!mounted) return;

      final newProducts = (productsResult['data'] as List<dynamic>?) ?? [];
      
      // Filtrer les nouveaux produits valides
      final validNewProducts = newProducts.where((p) {
        if (p is! Map<String, dynamic>) return false;
        return p['id'] != null && p['id'] is int;
      }).toList();

      // Éviter les doublons
      final existingIds = _filteredProducts.map((p) => p['id']).toSet();
      final uniqueNewProducts = validNewProducts.where((p) => !existingIds.contains(p['id'])).toList();

      if (mounted) {
        setState(() {
          _filteredProducts.addAll(uniqueNewProducts);
          _allProducts.addAll(uniqueNewProducts);
          _currentPage = nextPage;
          _totalResults = (productsResult['total'] as int?) ?? 0;
          _totalPages = (productsResult['pages'] as int?) ?? 1;
          _hasMore = nextPage < _totalPages && uniqueNewProducts.isNotEmpty;
          _loadingMore = false;
        });
      }
    } catch (e) {
      print('Erreur loadMoreProducts: $e');
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
        _showErrorSnackBar('Erreur de chargement des produits supplémentaires');
      }
    }
  }

  Future<void> _searchProducts() async {
    if (!mounted) return;
    
    _resetPagination();

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final Map<String, dynamic> productsResult = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categorie: _selectedCategory != 'Tous' ? _getCategoryId(_selectedCategory) : null,
      );

      if (!mounted) return;

      final productsData = (productsResult['data'] as List<dynamic>?) ?? [];

      setState(() {
        _filteredProducts = productsData;
        _totalResults = (productsResult['total'] as int?) ?? 0;
        _totalPages = (productsResult['pages'] as int?) ?? 1;
        _hasMore = _currentPage < _totalPages;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur searchProducts: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterByCategory(String category) async {
    if (!mounted) return;
    
    _resetPagination();

    setState(() {
      _selectedCategory = category;
      _isLoading = true;
      _error = '';
    });
    print('Filtrage par catégorie: $category');
    try {
      String? categorieFilter;
      if (category != 'Tous') {
        categorieFilter = _getCategoryId(category);
      }
      print('ID de la catégorie pour le filtrage: $categorieFilter');
      final Map<String, dynamic> productsResult = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categorie: categorieFilter,
      );

      if (!mounted) return;

      final productsData = (productsResult['data'] as List<dynamic>?) ?? [];

      setState(() {
        _filteredProducts = productsData;
        _totalResults = (productsResult['total'] as int?) ?? 0;
        _totalPages = (productsResult['pages'] as int?) ?? 1;
        _hasMore = _currentPage < _totalPages;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur filterByCategory: $e');
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du filtrage: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String? _getCategoryId(String categoryName) {
    try {
      if (_categories.isEmpty || categoryName == 'Tous') return null;

      // 👉 On récupère la liste interne des catégories
      final list = _categories.first; // car _categories contient UNE LISTE

      for (final cat in list) {
        print("Recherche de l'ID pour: $cat");

        if (_getCategoryName(cat) == categoryName) {
          final categoryId = cat['id']?.toString();
          return categoryId;
        }
      }

      return null;
    } catch (e) {
      print('Erreur _getCategoryId: $e');
      return null;
    }
  }


  void _resetPagination() {
    if (!mounted) return;
    
    setState(() {
      _currentPage = 1;
      _filteredProducts = [];
      _hasMore = true;
      _totalResults = 0;
      _totalPages = 1;
    });
  }

  void _toggleProduct(int productId) {
    if (!mounted || productId == 0) return;
    
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
      } else {
        if (_selectedIds.length < 2) { // Changé de 4 à 2
          _selectedIds.add(productId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous pouvez comparer seulement 2 produits maximum'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _clearSelection() {
    if (!mounted) return;
    
    setState(() {
      _selectedIds.clear();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    if (!mounted) return;
    
    setState(() {
      _searchQuery = '';
    });
    _loadInitialData();
  }

  void _compareProducts() {
    if (_selectedIds.length == 2) { // Changé pour exiger exactement 2 produits
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleComparisonPage(productIds: _selectedIds),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedIds.length < 2 
              ? 'Veuillez sélectionner 2 produits à comparer' 
              : 'Vous ne pouvez comparer que 2 produits',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<dynamic> _getSelectedProducts() {
    return _allProducts.where((product) {
      final productId = product['id'];
      return productId != null && 
             productId is int && 
             _selectedIds.contains(productId);
    }).toList();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getCategoryName(dynamic category) {
    if (category == null) return 'Inconnu';
    if (category is String) return category;
    if (category is Map) {
      return category['nom'];
    }
    return category.toString();
  }

  String _getProductName(dynamic product) {
    return product['nom'] ?? 'Produit sans nom';
  }

  double _getProductPrice(dynamic product) {
    final price = product['prix'] ?? product['price'];
    if (price is int) return price.toDouble();
    if (price is double) return price;
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  String? _getProductImage(dynamic product) {
    final images = product['images'] as List<dynamic>?;
    print('Images du produit ${product['id']}: $images');
    if (images != null && images.isNotEmpty) {
      final firstImage = images.first;
      if (firstImage is Map) {
        final imagePath = firstImage['path']?.toString();
        if (imagePath != null && imagePath.isNotEmpty) {
          print('Chemin de l\'image: $imagePath');
          return imagePath.startsWith('http') ? imagePath : '$baseUrl$imagePath';
        }
      } else if (firstImage is String) {
        return firstImage.startsWith('http') ? firstImage : '$baseUrl$firstImage';
      }
    }
    return null;
  }

  double _getProductRating(dynamic product) {
    final rating = product['avisMoyenne'] ?? product['rating'];
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0.0;
    return 0.0;
  }

  int _getProductReviewCount(dynamic product) {
    return product['nbAvis'] ?? product['reviewCount'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedProducts = _getSelectedProducts();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Comparer 2 Produits',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Tout désélectionner',
            ),
          IconButton(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),
          
          // Filtres par catégorie - AMÉLIORÉ
          _buildCategoryFilter(),
          
          // Info de sélection - AMÉLIORÉ
          _buildSelectionInfo(selectedProducts),
          
          // Liste des produits
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error.isNotEmpty
                    ? _buildErrorState()
                    : _buildProductsGrid(),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.length == 2 // Changé pour exactement 2
          ? FloatingActionButton.extended(
              onPressed: _compareProducts,
              icon: const Icon(Icons.compare_arrows, color: Colors.white),
              label: const Text(
                'Comparer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green[700],
              elevation: 4,
            )
          : _selectedIds.isNotEmpty
            ? FloatingActionButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sélectionnez un deuxième produit pour comparer'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                backgroundColor: Colors.orange[700],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_selectedIds.length}/2',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Icon(Icons.compare_arrows, color: Colors.white, size: 20),
                  ],
                ),
              )
            : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSubmitted: (value) {
                _searchProducts();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchProducts,
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
  final allCategories = [
    'Tous',
    ..._categories.expand((cat) {
      // Si cat est une liste => on retourne tous les noms
      if (cat is List) {
        return cat.map((c) => _getCategoryName(c));
      }

      // Sinon c’est un seul élément => on retourne 1 élément
      return [_getCategoryName(cat)];
    })
  ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégories:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allCategories.length,
              itemBuilder: (context, index) {
                final category = allCategories[index];
                final isSelected = category == _selectedCategory;
                print('Sélection de la catégorie: $category, sélectionnée: $isSelected');
                return Container(
                  margin: EdgeInsets.only(
                    right: index == allCategories.length - 1 ? 0 : 8,
                    left: index == 0 ? 0 : 0,
                  ),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _filterByCategory(allCategories[index]),
                    backgroundColor: Colors.white,
                    selectedColor: Colors.blue[700],
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionInfo(List<dynamic> selectedProducts) {
    if (_selectedIds.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _selectedIds.length == 2 ? Colors.green[50] : Colors.blue[50],
        border: Border(
          bottom: BorderSide(
            color: _selectedIds.length == 2 ? Colors.green[100]! : Colors.blue[100]!,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selectedIds.length == 2 ? Icons.check_circle : Icons.info,
                color: _selectedIds.length == 2 ? Colors.green[700] : Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedIds.length == 2 
                  ? 'Prêt à comparer !' 
                  : 'Produits sélectionnés (${_selectedIds.length}/2):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _selectedIds.length == 2 ? Colors.green[700] : Colors.blue[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedProducts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedProducts.map((product) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.grey[100],
                          ),
                          child: _getProductImage(product) != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    _getProductImage(product)!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.shopping_bag, color: Colors.grey[400]);
                                    },
                                  ),
                                )
                              : Icon(Icons.shopping_bag, color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getProductName(product),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_getProductPrice(product).toStringAsFixed(2)} TND',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final productId = product['id'];
                            if (productId != null && productId is int) {
                              _toggleProduct(productId);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chargement des produits...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 20),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Compteur de résultats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_totalResults} produit(s) trouvé(s)',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchQuery.isNotEmpty || _selectedCategory != 'Tous')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Recherche: "$_searchQuery"'
                        : 'Catégorie: $_selectedCategory',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Grid des produits
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemCount: _filteredProducts.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (!mounted) return const SizedBox.shrink();

              if (index >= _filteredProducts.length) {
                return _buildLoadingMoreIndicator();
              }
              
              final product = _filteredProducts[index];
              final productId = product['id'];
              
              if (productId == null || productId is! int) {
                return _buildErrorCard();
              }
              
              final isSelected = _selectedIds.contains(productId);
              final imageUrl = _getProductImage(product);
              final rating = _getProductRating(product);
              final reviewCount = _getProductReviewCount(product);

              return _buildProductCard(
                product, 
                productId, 
                isSelected, 
                imageUrl, 
                rating, 
                reviewCount
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              _selectedCategory == 'Tous' && _searchQuery.isEmpty
                  ? 'Aucun produit disponible'
                  : _searchQuery.isNotEmpty
                      ? 'Aucun résultat pour "$_searchQuery"'
                      : 'Aucun produit dans la catégorie "$_selectedCategory"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Essayez de changer de catégorie ou de recherche',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chargement...',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 40),
          const SizedBox(height: 8),
          const Text(
            'Produit\ninvalide',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    dynamic product, 
    int productId,
    bool isSelected, 
    String? imageUrl, 
    double rating,
    int reviewCount,
  ) {
    return GestureDetector(
      onTap: () => _toggleProduct(productId),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? Colors.green[700]! : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image du produit
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    color: Colors.grey[100],
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.shopping_bag,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        (loadingProgress.expectedTotalBytes ?? 1)
                                      : null,
                                  strokeWidth: 2,
                                  color: Colors.blue[700],
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.shopping_bag,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
                
                // Contenu texte
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom du produit
                      Text(
                        _getProductName(product),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Note et avis
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600], size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($reviewCount)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Prix
                      Text(
                        '${_getProductPrice(product).toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Badge de sélection
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Indicateur de sélection en bas
            if (isSelected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}