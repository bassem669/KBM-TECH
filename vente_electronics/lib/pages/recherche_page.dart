// lib/pages/recherche_page.dart
import 'package:flutter/material.dart';
import '../fetch/produit_api.dart';
import '../fetch/categorie_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './../fetch/panier_api.dart';
import 'package:provider/provider.dart';
import 'dart:async';

final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';
final Color _accentColor = const Color(0xFFFF6B6B);
final Color _successColor = const Color(0xFF34C759);

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});
  
  @override 
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final _searchCtrl = TextEditingController();
  List<dynamic> resultats = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 10;
  int _totalResults = 0;
  int _totalPages = 1;
  Timer? _searchDebounce;
  
  // Nouveaux états pour les filtres
  String? _selectedCategory;
  int? _selectedCategoryId; // Stocker l'ID de la catégorie
  List<Map<String, dynamic>> _categories = []; // Stocker id et nom
  bool _showFilters = false;
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
    _loadCategoriesFromAPI();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Charger les catégories depuis votre API dédiée
  Future<void> _loadCategoriesFromAPI() async {
    try {
      print('🔄 Chargement des catégories depuis l\'API...');
      
      final categoriesData = await CategorieAPI.getAllCategories();
      
      setState(() {
        _categories = categoriesData.map((category) => {
          'id': category['id'],
          'nom': category['nom']
        }).toList();
        _categoriesLoaded = true;
        print('✅ ${_categories.length} catégories chargées depuis API');
        
        // Réinitialiser la sélection
        _selectedCategory = null;
        _selectedCategoryId = null;
      });
    } catch (e) {
      print('❌ Erreur chargement catégories depuis API: $e');
      _loadCategoriesFromProducts();
    }
  }

  // Fallback: Charger les catégories depuis les produits existants
  Future<void> _loadCategoriesFromProducts() async {
    try {
      print('🔄 Chargement des catégories depuis les produits...');
      
      final response = await ProduitAPI.fetchAllProduits(limit: 100);
      final produits = response['data'] ?? [];
      
      Set<Map<String, dynamic>> categoriesSet = {};
      
      for (var produit in produits) {
        final categories = produit['categories'] as List<dynamic>?;
        if (categories != null && categories.isNotEmpty) {
          for (var categorie in categories) {
            if (categorie is Map<String, dynamic>) {
              final categoryId = categorie['id'];
              final categoryName = categorie['nom']?.toString();
              if (categoryId != null && categoryName != null && categoryName.isNotEmpty) {
                categoriesSet.add({
                  'id': categoryId,
                  'nom': categoryName
                });
              }
            }
          }
        }
      }
      
      final categoriesList = categoriesSet.toList();
      
      setState(() {
        _categories = categoriesList;
        _categoriesLoaded = true;
        print('✅ Catégories chargées depuis produits: ${_categories.length}');
      });
    } catch (e) {
      print('❌ Erreur chargement catégories depuis produits: $e');
      setState(() {
        _categories = [
          {'id': 1, 'nom': 'Phones'},
          {'id': 2, 'nom': 'Laptops'},
          {'id': 3, 'nom': 'Tablettes'},
          {'id': 4, 'nom': 'Accessoires'},
        ];
        _categoriesLoaded = true;
      });
    }
  }

  Future<void> _addToCart(Map<String, dynamic> produit) async {
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final stock = produit['quantite'] ?? 0;
      if (stock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit en rupture de stock'),
            backgroundColor: _accentColor,
          ),
        );
        return;
      }

      if (stock <= cart.getQuantiteProduits(produit["id"])) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tu atteinds le quantite de stock'),
            backgroundColor: _accentColor,
          ),
        );
        return;
      }
      
      await cart.addItem(produit);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${produit['nom']} ajouté au panier'),
          backgroundColor: _successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erreur lors de l\'ajout au panier: $e');
    }
  }

  void _loadInitialProducts() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      resultats = [];
    });
    
    try {
      print('🔄 Chargement produits - Page: $_currentPage, Catégorie ID: $_selectedCategoryId, Nom: "$_selectedCategory", Recherche: "${_searchCtrl.text}"');
      
      final response = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
        search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
        categorie: _selectedCategoryId?.toString(), // Envoyer l'ID plutôt que le nom
      );
      
      setState(() {
        resultats = response['data'] ?? [];
        _totalResults = response['total'] ?? 0;
        _totalPages = response['pages'] ?? 1;
        _hasMore = _currentPage < _totalPages;
        print('✅ Produits chargés: ${resultats.length}');
        print('✅ Total: $_totalResults, Pages: $_totalPages');
        
        // Debug: Afficher les catégories des produits chargés
        for (var produit in resultats.take(3)) {
          final categories = produit['categories'] as List<dynamic>?;
          final categoryNames = categories?.map((c) => c['nom']).toList() ?? [];
          print('📦 Produit: ${produit['nom']}, Catégories: $categoryNames');
        }
      });
    } catch (e) {
      print('❌ Erreur chargement initial: $e');
      _showErrorSnackbar('Erreur lors du chargement des produits');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadPage(int page) async {
    if (page < 1 || page > _totalPages || _isLoading) return;
    
    setState(() {
      _isLoading = true;
      _currentPage = page;
    });
    
    try {
      print('🔄 Chargement page $page - Catégorie ID: $_selectedCategoryId, Recherche: "${_searchCtrl.text}"');
      
      final response = await ProduitAPI.fetchAllProduits(
        page: page,
        limit: _limit,
        search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
        categorie: _selectedCategoryId?.toString(), // Envoyer l'ID
      );
      
      setState(() {
        resultats = response['data'] ?? [];
        _totalResults = response['total'] ?? 0;
        _totalPages = response['pages'] ?? 1;
        _hasMore = _currentPage < _totalPages;
      });
    } catch (e) {
      print('❌ Erreur chargement page $page: $e');
      _showErrorSnackbar('Erreur lors du chargement de la page $page');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _rechercher() async {
    if (_searchCtrl.text.isEmpty) {
      _loadInitialProducts();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });
    
    try {
      final response = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
        search: _searchCtrl.text,
        categorie: _selectedCategoryId?.toString(), // Envoyer l'ID
      );
      
      setState(() {
        resultats = response['data'] ?? [];
        _totalResults = response['total'] ?? 0;
        _totalPages = response['pages'] ?? 1;
        _hasMore = _currentPage < _totalPages;
      });
    } catch (e) {
      print('Erreur recherche: $e');
      _showErrorSnackbar('Erreur lors de la recherche');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (value == _searchCtrl.text) {
        _rechercher();
      }
    });
  }

  void _applyFilters() {
    setState(() {
      _showFilters = false;
      _currentPage = 1;
    });
    _loadInitialProducts();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedCategoryId = null;
      _showFilters = false;
      _currentPage = 1;
    });
    
    _loadInitialProducts();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _resetFilters();
  }

  Widget _buildFiltersPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showFilters ? 180 : 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCategoryFilter(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                    ),
                    child: const Text('Appliquer', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    if (!_categoriesLoaded) {
      return const Column(
        children: [
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 8),
          Text('Chargement des catégories...', style: TextStyle(fontSize: 12)),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Toutes les catégories'),
        ),
        ..._categories.map((category) {
          return DropdownMenuItem<String>(
            value: category['nom'],
            child: Text(category['nom']),
          );
        }).toList(),
      ],
      onChanged: (String? newValue) {
        print('🎯 Catégorie sélectionnée: $newValue');
        
        // Trouver l'ID correspondant au nom sélectionné
        final selectedCat = _categories.firstWhere(
          (cat) => cat['nom'] == newValue,
          orElse: () => {},
        );
        
        setState(() {
          _selectedCategory = newValue;
          _selectedCategoryId = selectedCat.isNotEmpty ? selectedCat['id'] : null;
          print('🔍 ID de catégorie correspondant: $_selectedCategoryId');
        });
      },
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            onPressed: _currentPage > 1 ? () => _loadPage(_currentPage - 1) : null,
            tooltip: 'Page précédente',
          ),
          Row(
            children: _buildPageNumbers(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: _currentPage < _totalPages ? () => _loadPage(_currentPage + 1) : null,
            tooltip: 'Page suivante',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    
    int start = _currentPage - 2;
    int end = _currentPage + 2;
    
    if (start < 1) {
      end += 1 - start;
      start = 1;
    }
    
    if (end > _totalPages) {
      start -= end - _totalPages;
      end = _totalPages;
      if (start < 1) start = 1;
    }
    
    if (start > 1) {
      pages.add(_buildPageNumber(1));
      if (start > 2) {
        pages.add(Text('...', style: TextStyle(color: Colors.grey[500])));
      }
    }
    
    for (int i = start; i <= end; i++) {
      pages.add(_buildPageNumber(i));
    }
    
    if (end < _totalPages) {
      if (end < _totalPages - 1) {
        pages.add(Text('...', style: TextStyle(color: Colors.grey[500])));
      }
      pages.add(_buildPageNumber(_totalPages));
    }
    
    return pages;
  }

  Widget _buildPageNumber(int page) {
    bool isCurrentPage = page == _currentPage;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isCurrentPage ? _accentColor : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => _loadPage(page),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              '$page',
              style: TextStyle(
                color: isCurrentPage ? Colors.white : Colors.grey[700],
                fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override 
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recherche"),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: 'Filtres',
              ),
              if (_selectedCategory != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: 'Effacer la recherche',
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: "Rechercher un produit...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _rechercher(),
          ),
        ),

        _buildFiltersPanel(),

        if (resultats.isNotEmpty || _isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalResults produit${_totalResults > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_totalPages > 1)
                  Text(
                    'Page $_currentPage/$_totalPages',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                if (_selectedCategory != null)
                  Chip(
                    label: Text(
                      'Catégorie: $_selectedCategory',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _accentColor.withOpacity(0.1),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 4),

        Expanded(
          child: _buildResults(cart),
        ),

        _buildPagination(),
      ]),
    );
  }

  Widget _buildResults(CartProvider cart) {
    if (_isLoading && resultats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Chargement des produits...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    if (_searchCtrl.text.isEmpty && resultats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Recherchez un produit',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Ou parcourez nos produits populaires',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }
    
    if (resultats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat${_selectedCategory != null ? ' dans la catégorie "$_selectedCategory"' : ''}${_searchCtrl.text.isNotEmpty ? ' pour "${_searchCtrl.text}"' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres termes ou modifiez les filtres',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _resetFilters,
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.6,
      ),
      itemCount: resultats.length,
      itemBuilder: (ctx, i) {
        return _ProductCard(
          produit: resultats[i], 
          onTap: () => Navigator.pushNamed(context, '/produit', arguments: resultats[i]),
          onAddToCart: () => _addToCart(resultats[i]),
          primaryColor: Colors.blue,
          accentColor: Colors.red,
        );
      },
    );
  }
}

// ... [LES AUTRES CLASSES RESTENT IDENTIQUES - ProductDisplayInfo, _ProductCard, etc.]

class ProductDisplayInfo {
  final String nom;
  final List<dynamic> images;
  final double note;
  final int nbAvis;
  final double prixOriginal;
  final double prixPromo;
  final bool hasPromotion;
  final int promotionPercentage;
  final int stock;
  final String categoryName;

  ProductDisplayInfo({
    required this.nom,
    required this.images,
    required this.note,
    required this.nbAvis,
    required this.prixOriginal,
    required this.prixPromo,
    required this.hasPromotion,
    required this.promotionPercentage,
    required this.stock,
    required this.categoryName,
  });

  factory ProductDisplayInfo.fromProduit(Map<String, dynamic> produit) {
    final images = produit['images'] as List<dynamic>? ?? [];
    final avisMoyenne = produit['avisMoyenne'];
    final note = avisMoyenne is String ? double.tryParse(avisMoyenne) ?? 0.0 :
                avisMoyenne is num ? avisMoyenne.toDouble() : 0.0;
    
    final prixOriginal = _getPrixOriginal(produit);
    final hasPromotion = _hasActivePromotion(produit);
    final prixPromo = _getPrixPromo(produit);
    final promotionPercentage = _getPourcentagePromo(produit);
    final categoryName = _getCategoryText(produit);
    final stock = produit['quantite'] ?? 0;

    return ProductDisplayInfo(
      nom: produit['nom']?.toString() ?? 'Produit sans nom',
      images: images,
      note: note,
      nbAvis: produit['nbAvis'] ?? 0,
      prixOriginal: prixOriginal,
      prixPromo: prixPromo,
      hasPromotion: hasPromotion,
      promotionPercentage: promotionPercentage,
      categoryName: categoryName,
      stock: stock,
    );
  }

  static double _getPrixOriginal(Map<String, dynamic> produit) {
    final prix = produit['prix'];
    if (prix is num) return prix.toDouble();
    if (prix is String) return double.tryParse(prix) ?? 0.0;
    return 0.0;
  }

  static bool _hasActivePromotion(Map<String, dynamic> produit) {
    final promotions = produit['promotions'] as List<dynamic>?;
    if (promotions == null || promotions.isEmpty) return false;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      
      if (dateDebut != null && dateFin != null && now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        return true;
      }
    }
    return false;
  }

  static double _getPrixPromo(Map<String, dynamic> produit) {
    final prixOriginal = _getPrixOriginal(produit);
    final promotions = produit['promotions'] as List<dynamic>?;
    
    if (promotions == null || promotions.isEmpty) return prixOriginal;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      final pourcentage = promo['pourcentage'] is num ? promo['pourcentage'].toDouble() : 0.0;
      
      if (dateDebut != null && dateFin != null && now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        return prixOriginal * (1 - pourcentage / 100);
      }
    }
    return prixOriginal;
  }

  static int _getPourcentagePromo(Map<String, dynamic> produit) {
    final promotions = produit['promotions'] as List<dynamic>?;
    if (promotions == null || promotions.isEmpty) return 0;
    
    final now = DateTime.now();
    for (final promo in promotions) {
      final dateDebut = DateTime.tryParse(promo['dateDebut']?.toString() ?? '');
      final dateFin = DateTime.tryParse(promo['dateFin']?.toString() ?? '');
      
      if (dateDebut != null && dateFin != null && now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        return promo['pourcentage'] is num ? promo['pourcentage'].toInt() : 0;
      }
    }
    return 0;
  }

  static String _getCategoryText(Map<String, dynamic> produit) {
    final categories = produit['categories'] as List<dynamic>?;
    if (categories == null || categories.isEmpty) return 'Général';
    
    final first = categories.first;
    if (first is Map<String, dynamic>) {
      String name = first['nom']?.toString() ?? 'Général';
      return name.length > 8 ? '${name.substring(0, 7)}...' : name;
    }
    
    return first.toString();
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> produit;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final Color primaryColor;
  final Color accentColor;

  const _ProductCard({
    required this.produit,
    required this.onTap,
    required this.onAddToCart,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ProductDisplayInfo info = ProductDisplayInfo.fromProduit(produit);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 120,
              child: _ProductImageSection(
                images: info.images,
                hasPromotion: info.hasPromotion,
                promotionPercentage: info.promotionPercentage,
                categoryName: info.categoryName,
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        info.nom,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProductRating(
                          note: info.note,
                          nbAvis: info.nbAvis,
                        ),
                        const SizedBox(height: 4),
                        _ProductPrice(
                          prixOriginal: info.prixOriginal,
                          prixPromo: info.prixPromo,
                          hasPromotion: info.hasPromotion,
                          primaryColor: primaryColor,
                          accentColor: accentColor,
                        ),
                      ],
                    ),
                    _ProductFooter(
                      stock: info.stock,
                      primaryColor: primaryColor,
                      onAddToCart: onAddToCart,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImageSection extends StatelessWidget {
  final List<dynamic> images;
  final bool hasPromotion;
  final int promotionPercentage;
  final String categoryName;
  final Color primaryColor;
  final Color accentColor;

  const _ProductImageSection({
    required this.images,
    required this.hasPromotion,
    required this.promotionPercentage,
    required this.categoryName,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[50]!, Colors.grey[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: _buildImageContent(),
        ),
        if (categoryName.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: _Badge(
              text: categoryName,
              color: primaryColor,
            ),
          ),
        if (hasPromotion)
          Positioned(
            top: 8,
            left: 8,
            child: _Badge(
              text: '-$promotionPercentage%',
              color: accentColor,
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent() {
    if (images.isEmpty) {
      return Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          size: 40,
          color: Colors.grey[400],
        ),
      );
    }

    final firstImage = images.first;
    final String imageUrl = firstImage['path'] ?? '';
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Image.network(
        imageUrl.isNotEmpty ? "$baseUrl$imageUrl" : "https://via.placeholder.com/150",
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey[400],
              size: 40,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductRating extends StatelessWidget {
  final double note;
  final int nbAvis;

  const _ProductRating({
    required this.note,
    required this.nbAvis,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded, color: Colors.amber[600], size: 14),
        const SizedBox(width: 4),
        Text(
          note.toStringAsFixed(1), 
          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)
        ),
        const SizedBox(width: 4),
        Text(
          '($nbAvis)', 
          style: TextStyle(fontSize: 11, color: Colors.grey[500])
        ),
      ],
    );
  }
}

class _ProductPrice extends StatelessWidget {
  final double prixOriginal;
  final double prixPromo;
  final bool hasPromotion;
  final Color primaryColor;
  final Color accentColor;

  const _ProductPrice({
    required this.prixOriginal,
    required this.prixPromo,
    required this.hasPromotion,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (hasPromotion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${prixOriginal.toStringAsFixed(2)}DNT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${prixPromo.toStringAsFixed(2)}DNT',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w800, 
              color: accentColor
            ),
          ),
        ],
      );
    }

    return Text(
      '${prixOriginal.toStringAsFixed(2)}DNT',
      style: TextStyle(
        fontSize: 16, 
        fontWeight: FontWeight.w800, 
        color: primaryColor
      ),
    );
  }
}

class _ProductFooter extends StatelessWidget {
  final int stock;
  final Color primaryColor;
  final VoidCallback onAddToCart;

  const _ProductFooter({
    required this.stock,
    required this.primaryColor,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: stock > 0 ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stock > 0 ? 'Stock: $stock' : 'Rupture',
              style: TextStyle(
                fontSize: 10, 
                color: stock > 0 ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: stock > 0 
                ? LinearGradient(
                    colors: [primaryColor, const Color(0xFF00C4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey, Colors.grey[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: stock > 0 
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            onPressed: stock > 0 ? onAddToCart : null,
            icon: const Icon(
              Icons.add_rounded, 
              color: Colors.white, 
              size: 16
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.alphaBlend(color.withOpacity(0.7), color)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}