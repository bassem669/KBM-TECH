// lib/pages/accueil_page.dart
import 'package:flutter/material.dart';
import './../fetch/produit_api.dart';
import './../fetch/categorie_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './../fetch/panier_api.dart';
import 'package:provider/provider.dart';
import './../fetch/auth_api.dart';
import './../fetch/liste_souhait_api.dart';

final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';

// Enum pour la gestion d'état
enum LoadingState {
  initial,
  loading,
  loaded,
  loadingMore,
  error
}

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  List<dynamic> _categories = [];
  List<dynamic> _produitsFiltres = [];
  List<dynamic> _allProduits = [];
  List<dynamic> _produitsPopulaires = [];
  List<dynamic> _produitsNotes = [];
  Map<String, dynamic>? _selectedCategory;
  
  // État de chargement simplifié
  LoadingState _loadingState = LoadingState.initial;
  bool _isUserConnected = false;

  // Pagination
  int _currentPage = 1;
  final int _limit = 10;
  int _totalResults = 0;
  int _totalPages = 1;
  bool _hasMore = true;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _wishlistCountNotifier = ValueNotifier<int>(0);

  // Couleurs modernes
  final Color _primaryColor = const Color(0xFF0066FF);
  final Color _secondaryColor = const Color(0xFF00C4FF);
  final Color _accentColor = const Color(0xFFFF6B6B);
  final Color _backgroundColor = const Color(0xFFF8FAFD);
  final Color _surfaceColor = Colors.white;
  final Color _textSecondary = const Color(0xFF6F767E);
  final Color _successColor = const Color(0xFF34C759);

  late WishlistService _wishlistService;


   void updateWishlistCount(int change) {
    if (mounted) {
      _wishlistCountNotifier.value += change;
    }
  }
  
  @override
  void initState() {
    super.initState();
    _wishlistService = WishlistService(); 
    _loadInitialData();
    _isConnecter();
    _scrollController.addListener(_scrollListener);
    _loadWishlistCount();
  }

  @override
  void dispose() {
    _wishlistCountNotifier.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchir le compteur quand on revient sur la page
    _refreshWishlistOnReturn();
  }

  void _refreshWishlistOnReturn() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        // MODIFIER cette ligne :
        await _wishlistService.refresh();
      }
    });
  }

  void _isConnecter() async {
    final token = await AuthAPI.getToken();
    if (token != 0) {
      _isUserConnected = true;
    }
  }

  Future<void> refreshWishlistCount() async {
    try {
      final count = await _wishlistService.getWishlistCount();
      if (mounted) {
        _wishlistCountNotifier.value = count;
      }
    } catch (e) {
      print('Erreur rafraîchissement compteur: $e');
      if (mounted) {
        _wishlistCountNotifier.value = 0;
      }
    }
  }

  Future<void> _loadWishlistCount() async {
    try {
      final count = await _wishlistService.getWishlistCount();
      _wishlistCountNotifier.value = count;
    } catch (e) {
      print('Erreur lors du chargement du compteur de souhaits: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        _hasMore &&
        _loadingState == LoadingState.loaded) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadInitialData() async {
    _resetPagination();

    try {
      setState(() {
        _loadingState = LoadingState.loading;
      });

      final categories = await CategorieAPI.getAllCategories();
      final produitsPop = await ProduitAPI.fetchProdPlusPop();
      final produitsNotes = await ProduitAPI.fetchProdPlusNotes();
      
      final produitsResult = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _categories = categories;
          _allProduits = produitsResult['data'] ?? [];
          _produitsFiltres = _allProduits;
          _produitsPopulaires = produitsPop;
          _produitsNotes = produitsNotes;
          _totalResults = produitsResult['total'] ?? 0;
          _totalPages = produitsResult['pages'] ?? 1;
          _hasMore = _currentPage < _totalPages;
          _loadingState = LoadingState.loaded;
          _selectedCategory = null;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement initial: $e');
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.error;
        });
        _showErrorSnackBar('Erreur de chargement des données');
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_loadingState == LoadingState.loadingMore || 
        _loadingState == LoadingState.loading || 
        !_hasMore) {
      return;
    }

    setState(() {
      _loadingState = LoadingState.loadingMore;
    });

    try {
      final nextPage = _currentPage + 1;
      final produitsResult = await ProduitAPI.fetchAllProduits(
        page: nextPage,
        limit: _limit,
        categorie: _selectedCategory?['id']?.toString(),
      );

      final newProducts = produitsResult['data'] ?? [];
      
      final existingIds = _produitsFiltres.map((p) => p['id']).toSet();
      final uniqueNewProducts = newProducts.where((p) => !existingIds.contains(p['id'])).toList();

      if (mounted) {
        setState(() {
          _produitsFiltres.addAll(uniqueNewProducts);
          
          if (_selectedCategory == null) {
            final allExistingIds = _allProduits.map((p) => p['id']).toSet();
            final uniqueForAll = newProducts.where((p) => !allExistingIds.contains(p['id'])).toList();
            _allProduits.addAll(uniqueForAll);
          }
          
          _currentPage = nextPage;
          _totalResults = produitsResult['total'] ?? 0;
          _totalPages = produitsResult['pages'] ?? 1;
          _hasMore = nextPage < _totalPages && uniqueNewProducts.isNotEmpty;
          _loadingState = LoadingState.loaded;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement supplémentaire: $e');
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.loaded;
        });
        _showErrorSnackBar('Erreur de chargement des produits supplémentaires');
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> produit) async {
    try {
      final cart = context.read<CartProvider>();
      final stock = produit['quantite'] ?? 0;
      
      if (stock <= 0) {
        _showErrorSnackBar('Produit en rupture de stock');
        return;
      }

      if (stock <= cart.getQuantiteProduits(produit["id"])) {
        _showErrorSnackBar('Quantité maximale en stock atteinte');
        return;
      }
      
      await cart.addItem(produit);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${produit['nom']} ajouté au panier'),
          backgroundColor: _successColor,
          duration: const Duration(seconds: 2),
        ),
      );

      if (mounted){
        setState(() {});
      }
    } catch (e) {
      print('Erreur lors de l\'ajout au panier: $e');
      _showErrorSnackBar('Erreur lors de l\'ajout au panier');
    }
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 1;
      _produitsFiltres = [];
      _allProduits = [];
      _hasMore = true;
      _totalResults = 0;
      _totalPages = 1;
      _loadingState = LoadingState.initial;
    });
  }

  Future<void> _loadProductsForCategory(Map<String, dynamic> category) async {
    final categoryId = category['id'];

    _resetPagination();
    
    setState(() {
      _selectedCategory = category;
      _loadingState = LoadingState.loading;
      _currentPage = 1;
      _produitsFiltres = [];
      _hasMore = true;
    });

    try {
      final produitsResult = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
        categorie: categoryId?.toString(),
      );
      
      if (mounted) {
        setState(() {
          _produitsFiltres = produitsResult['data'] ?? [];
          _totalResults = produitsResult['total'] ?? 0;
          _totalPages = produitsResult['pages'] ?? 1;
          _hasMore = _currentPage < _totalPages;
          _loadingState = LoadingState.loaded;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des produits: $e');
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.error;
          _produitsFiltres = [];
        });
        _showErrorSnackBar('Erreur de chargement des produits');
      }
    }
  }

  void _handleCategorySelect(Map<String, dynamic> category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadProductsForCategory(category);
  }

  void _showAllProducts() async {
    _resetPagination();
    setState(() {
      _selectedCategory = null;
      _currentPage = 1;
      _loadingState = LoadingState.loading;
      _produitsFiltres = [];
      _allProduits = [];
      _hasMore = true;
    });

    try {
      final produitsResult = await ProduitAPI.fetchAllProduits(
        page: 1,
        limit: _limit,
      );
      
      if (mounted) {
        setState(() {
          _produitsFiltres = produitsResult['data'] ?? [];
          _allProduits = _produitsFiltres;
          _totalResults = produitsResult['total'] ?? 0;
          _totalPages = produitsResult['pages'] ?? 1;
          _hasMore = _currentPage < _totalPages;
          _loadingState = LoadingState.loaded;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de tous les produits: $e');
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.error;
        });
      }
    }
  }

  void _navigateToProductDetail(Map<String, dynamic> produit) {
    Navigator.pushNamed(
      context, 
      '/produit',
      arguments: produit,
    );
  }

  void _navigateToProfile() {
    if (_isUserConnected) {
      Navigator.pushNamed(context, '/profil');
    } else {
      Navigator.pushNamed(context, '/login');
    }
  }

  void _navigateToWishlist() {
    Navigator.pushNamed(context, '/listeSouhait');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          _resetPagination();
          await _loadInitialData();
          
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        color: _primaryColor,
        backgroundColor: _surfaceColor,
        displacement: 40,
        triggerMode: RefreshIndicatorTriggerMode.onEdge,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeaderSection(),
            
            if (_produitsPopulaires.isNotEmpty)
              _buildProductSection(
                title: "Produits populaires",
                produits: _produitsPopulaires,
                gradientColors: [_primaryColor, _secondaryColor],
              ),

            if (_produitsNotes.isNotEmpty)
              _buildProductSection(
                title: "Produits plus notés",
                produits: _produitsNotes,
                gradientColors: [_accentColor, const Color(0xFFFFA726)],
              ),

            if (_categories.isNotEmpty)
              _buildCategoriesSection(),

            _buildProductsGridSection(),

            _buildLoadingMoreIndicator(),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    if (_loadingState != LoadingState.loadingMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.05)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "KBM TECH",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Votre boutique tech premium",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: IconButton(
                      onPressed: _navigateToProfile,
                      icon: Stack(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          if (_isUserConnected)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _successColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/recherche');
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.8)),
                      const SizedBox(width: 12),
                      Text(
                        "Rechercher des produits...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSection({required String title, required List<dynamic> produits, required List<Color> gradientColors}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: _buildProductCarousel(produits),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCarousel(List<dynamic> produits) {
    if (_loadingState == LoadingState.loading) {
      return Center(
        child: Container(
          width: 40,
          height: 30,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surfaceColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: CircularProgressIndicator(
            color: _primaryColor,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (produits.isEmpty) {
      return _EmptyState(
        icon: Icons.inventory_2_outlined,
        message: "Aucun produit",
        color: _textSecondary,
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: produits.length,
      itemBuilder: (context, index) {
        final produit = produits[index] as Map<String, dynamic>;
        return Padding(
          padding: EdgeInsets.only(
            right: index == produits.length - 1 ? 0 : 20,
            left: index == 0 ? 0 : 0,
          ),
          child: _HorizontalProductCard(
            produit: produit,
            onTap: () => _navigateToProductDetail(produit),
            onAddToCart: () => _addToCart(produit),
            primaryColor: _primaryColor,
            accentColor: _accentColor,
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Catégories",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 110,
              child: _buildCategoriesList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (_loadingState == LoadingState.loading) {
      return Center(
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surfaceColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: CircularProgressIndicator(
            color: _primaryColor,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return _EmptyState(
        icon: Icons.category_outlined,
        message: "Aucune catégorie",
        color: _textSecondary,
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CategoryCard(
              category: "Tous",
              isSelected: _selectedCategory == null,
              onTap: _showAllProducts,
              primaryColor: _primaryColor,
            ),
          );
        }
        
        final category = _categories[index - 1] as Map<String, dynamic>;
        return Padding(
          padding: EdgeInsets.only(
            right: index == _categories.length ? 0 : 16,
          ),
          child: _CategoryCard(
            category: category["nom"]?.toString() ?? 'Catégorie',
            isSelected: _selectedCategory?['id'] == category['id'],
            onTap: () => _handleCategorySelect(category),
            primaryColor: _primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildProductsGridSection() {
    if (_loadingState == LoadingState.loading && _produitsFiltres.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF0066FF),
            ),
          ),
        ),
      );
    }

    if (_loadingState == LoadingState.error && _produitsFiltres.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              _EmptyState(
                icon: Icons.error_outline,
                message: "Erreur de chargement",
                color: _accentColor,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    if (_produitsFiltres.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: _EmptyState(
            icon: Icons.inventory_2_outlined,
            message: _selectedCategory == null 
                ? "Aucun produit disponible"
                : "Aucun produit dans cette catégorie",
            color: _textSecondary,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.55,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _produitsFiltres.length) {
              return _buildGridLoadingIndicator();
            }
            
            final produit = _produitsFiltres[index] as Map<String, dynamic>;
            return _ProductCard(
              produit: produit,
              onTap: () => _navigateToProductDetail(produit),
              onAddToCart: () => _addToCart(produit),
              primaryColor: _primaryColor,
              accentColor: _accentColor,
            );
          },
          childCount: _produitsFiltres.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildGridLoadingIndicator() {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chargement...',
            style: TextStyle(
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: "Accueil",
                isActive: true,
                onTap: () {},
                primaryColor: _primaryColor,
              ),
              _BottomNavItem(
                icon: Icons.compare_arrows_rounded,
                label: "Comparer",
                isActive: false,
                onTap: () {
                  Navigator.pushNamed(context, '/simple-selection');

                },
                primaryColor: _primaryColor,
              ),
              _BottomNavItem(
                icon: Icons.shopping_cart_outlined,
                label: "Panier",
                isActive: false,
                badgeCount: context.watch<CartProvider>().totalItems,
                onTap: () {
                  Navigator.pushNamed(context, '/panier');
                },
                primaryColor: _primaryColor,
              ),
              Consumer<WishlistService>(
              builder: (context, wishlistService, child) {
                return _BottomNavItem(
                  icon: Icons.favorite_outline_rounded,
                  label: "Souhaits",
                  isActive: false,
                  badgeCount: wishlistService.count,
                  onTap: _navigateToWishlist,
                  primaryColor: _primaryColor,
                );
              },
            ),
            _BottomNavItem(
              icon: Icons.contact_page,
              label: "Contact",
              isActive: false,
              onTap: () {
                  Navigator.pushNamed(context, '/contact');
                },
              primaryColor: _primaryColor,
            )
            ],
          ),
        ),
      ),
    );
  }
}

// Classes utilitaires
class ProductDisplayInfo {
  final String nom;
  final List<dynamic> images;
  final double note;
  final int nbAvis;
  final double prixOriginal;
  final double prixPromo;
  final bool hasPromotion;
  final int promotionPercentage;
  final String categoryName;
  final int stock;

  ProductDisplayInfo({
    required this.nom,
    required this.images,
    required this.note,
    required this.nbAvis,
    required this.prixOriginal,
    required this.prixPromo,
    required this.hasPromotion,
    required this.promotionPercentage,
    required this.categoryName,
    required this.stock,
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
    String name = first is Map ? first['nom']?.toString() ?? 'Général' : first.toString();
    return name.length > 8 ? '${name.substring(0, 7)}...' : name;
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
                      produit: produit,
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

class _HorizontalProductCard extends StatelessWidget {
  final Map<String, dynamic> produit;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final Color primaryColor;
  final Color accentColor;

  const _HorizontalProductCard({
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
        width: 180,
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
              height: 140,
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
                          height: 1.3
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
                      produit: produit,
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

class _ProductFooter extends StatefulWidget {
  final int stock;
  final Color primaryColor;
  final VoidCallback onAddToCart;
  final Map<String, dynamic> produit;

  const _ProductFooter({
    required this.stock,
    required this.primaryColor,
    required this.onAddToCart,
    required this.produit,
  });

  @override
  State<_ProductFooter> createState() => _ProductFooterState();
}

class _ProductFooterState extends State<_ProductFooter> {
  final WishlistService _wishlistService = WishlistService();
  bool _isInWishlist = false;
  bool _loadingWishlist = false;

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
    WishlistService().addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    // Nettoyer le listener
    WishlistService().removeListener(_onWishlistChanged);
    super.dispose();
  }

   void _onWishlistChanged() {
    // Rafraîchir l'état quand la wishlist change
    if (mounted) {
      _checkWishlistStatus();
    }
  }

  Future<void> _checkWishlistStatus() async {
    final productId = widget.produit['id'];
    final isInWishlist = await _wishlistService.isInWishlist(productId);
    if (mounted) {
      setState(() {
        _isInWishlist = isInWishlist;
      });
    }
  }

  Future<void> _toggleWishlist() async {
    if (_loadingWishlist) return;
    
    setState(() {
      _loadingWishlist = true;
    });

    try {
      final productId = widget.produit['id']?.toString() ?? '';
      
      if (_isInWishlist) {
        await WishlistService().removeFromWishlist(productId);
      } else {
        await WishlistService().addToWishlist(widget.produit);
      }
      
      // Pas besoin de mettre à jour _isInWishlist ici car le listener le fera automatiquement
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                !_isInWishlist ? Icons.favorite : Icons.favorite_border,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                !_isInWishlist ? 'Ajouté à la liste de souhaits !' : 'Retiré de la liste de souhaits',
              ),
            ],
          ),
          backgroundColor: !_isInWishlist ? Colors.red : Colors.grey[600],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Erreur wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingWishlist = false;
        });
      }
    }
  }


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
              color: widget.stock > 0 ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.stock > 0 ? 'Stock: ${widget.stock}' : 'Rupture',
              style: TextStyle(
                fontSize: 10, 
                color: widget.stock > 0 ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isInWishlist ? Colors.red.withOpacity(0.3) : Colors.grey[300]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _toggleWishlist,
                icon: _loadingWishlist
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : Icon(
                        _isInWishlist ? Icons.favorite : Icons.favorite_border,
                        color: _isInWishlist ? Colors.red : Colors.grey[600],
                        size: 14,
                      ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            
            const SizedBox(width: 6),
            
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: widget.stock > 0 
                    ? LinearGradient(
                        colors: [widget.primaryColor, Color(0xFF00C4FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.grey, Colors.grey[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: widget.stock > 0 
                    ? [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                onPressed: widget.stock > 0 ? widget.onAddToCart : null,
                icon: Icon(
                  Icons.add_rounded, 
                  color: Colors.white, 
                  size: 14
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: isSelected 
                    ? LinearGradient(
                        colors: [primaryColor, Color(0xFF00C4FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.white, Colors.grey[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                        ? primaryColor.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 30,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.replaceAll("'", ""),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? primaryColor : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cleanCategory = category.toLowerCase().replaceAll("'", "");
    switch (cleanCategory) {
      case 'tous':
        return Icons.all_inclusive_rounded;
      case 'phones':
      case 'téléphones':
        return Icons.phone_iphone_rounded;
      case 'electronic':
      case 'électronique':
        return Icons.electrical_services_rounded;
      case 'informatique':
        return Icons.computer_rounded;
      case 'audio':
        return Icons.headphones_rounded;
      case 'gaming':
      case 'jeux':
        return Icons.sports_esports_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color primaryColor;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isActive 
                      ? LinearGradient(
                          colors: [primaryColor, Color(0xFF00C4FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  size: 22,
                ),
              ),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      badgeCount! > 9 ? '9+' : badgeCount!.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? primaryColor : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  
}