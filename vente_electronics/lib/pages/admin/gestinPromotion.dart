// lib/pages/admin/promotions_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../fetch/promotion_api.dart';
import '../../fetch/produit_api.dart';
import '../../fetch/categorie_api.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  List<dynamic> _promotions = [];
  List<dynamic> _activePromotions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  void _showPromotionDetails(dynamic promotion) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PromotionDetailsDialog(
          promotion: promotion,
          onDeletePromotion: _deletePromotion,
          onProductRemoved: _loadPromotions,
        );
      },
    ).then((_) {
      _loadPromotions();
    });
  }


  void _deletePromotion(dynamic promotion) async {
    try {
      await PromotionAPI.deletePromotion(promotion['id']);
      await Future.delayed(const Duration(milliseconds: 500));
      _loadPromotions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotion "${promotion['description']}" supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  


  Future<void> _loadPromotions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final [allPromotions, activePromotions] = await Future.wait([
        PromotionAPI.getAllPromotions(),
        PromotionAPI.getActivePromotions(),
      ]);

      if (!mounted) return;

      setState(() {
        _promotions = allPromotions;
        _activePromotions = activePromotions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  bool _isPromotionActive(dynamic promotion) {
    try {
      final now = DateTime.now();
      final dateDebutStr = promotion['dateDebut']?.toString() ?? '';
      final dateFinStr = promotion['dateFin']?.toString() ?? '';
      
      if (dateDebutStr.isEmpty || dateFinStr.isEmpty) return false;

      final dateDebut = DateTime.parse(dateDebutStr);
      final dateFin = DateTime.parse(dateFinStr);
      
      return dateDebut.isBefore(now) && dateFin.isAfter(now);
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Date inconnue';
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(dynamic promotion) {
    if (_isPromotionActive(promotion)) {
      return Colors.green;
    }
    
    try {
      final dateFinStr = promotion['dateFin']?.toString() ?? '';
      if (dateFinStr.isEmpty) return Colors.grey;
      
      final dateFin = DateTime.parse(dateFinStr);
      if (dateFin.isBefore(DateTime.now())) {
        return Colors.red;
      }
      return Colors.orange;
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getStatusText(dynamic promotion) {
    if (_isPromotionActive(promotion)) {
      return 'Active';
    }
    
    try {
      final dateFinStr = promotion['dateFin']?.toString() ?? '';
      if (dateFinStr.isEmpty) return 'Inconnu';
      
      final dateFin = DateTime.parse(dateFinStr);
      if (dateFin.isBefore(DateTime.now())) {
        return 'Expirée';
      }
      return 'À venir';
    } catch (e) {
      return 'Inconnu';
    }
  }

  Widget _buildPromotionCard(dynamic promotion) {
    final statusColor = _getStatusColor(promotion);
    final statusText = _getStatusText(promotion);
    final produits = promotion['produits'] ?? [];
    final categories = promotion['categories'] ?? [];
    final pourcentage = promotion['pourcentage']?.toString() ?? '0';
    final description = promotion['description'] ?? 'Sans description';
    final dateDebut = promotion['dateDebut']?.toString() ?? '';
    final dateFin = promotion['dateFin']?.toString() ?? '';
    final scopeType = promotion['scopeType'] ?? 'produits';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => _showPromotionDetails(promotion),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec description et statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Badge type de portée
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getScopeTypeColor(scopeType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getScopeTypeColor(scopeType)),
                          ),
                          child: Text(
                            _getScopeTypeText(scopeType),
                            style: TextStyle(
                              color: _getScopeTypeColor(scopeType),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Informations promotion
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Text(
                      '-$pourcentage%',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Afficher le nombre selon le type de portée
                  if (scopeType == 'produits' && produits.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple),
                      ),
                      child: Text(
                        '${produits.length} produit${produits.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (scopeType == 'categories' && categories.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        '${categories.length} catégorie${categories.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (scopeType == 'all')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'Tous les produits',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Dates
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Du ${_formatDate(dateDebut)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Au ${_formatDate(dateFin)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Contenu selon le type de portée
              if (scopeType == 'produits' && produits.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Produits concernés:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: produits.take(3).map<Widget>((produit) {
                    return Chip(
                      label: Text(
                        produit['nom']?.toString() ?? 'Sans nom',
                        style: const TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.grey[100],
                    );
                  }).toList(),
                ),
                if (produits.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${produits.length - 3} autre${produits.length - 3 > 1 ? 's' : ''}...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
              
              if (scopeType == 'categories' && categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Catégories concernées:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: categories.take(3).map<Widget>((categorie) {
                    return Chip(
                      label: Text(
                        categorie['nom']?.toString() ?? 'Sans nom',
                        style: const TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.green[50],
                    );
                  }).toList(),
                ),
                if (categories.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${categories.length - 3} autre${categories.length - 3 > 1 ? 's' : ''}...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
              
              // Actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    onPressed: () => _showPromotionDetails(promotion),
                    tooltip: 'Voir les détails',
                    color: Colors.blue,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editPromotion(promotion),
                    tooltip: 'Modifier',
                    color: Colors.orange,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deletePromotion(promotion),
                    tooltip: 'Supprimer',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Méthodes pour gérer les types de portée
  Color _getScopeTypeColor(String scopeType) {
    switch (scopeType) {
      case 'produits':
        return Colors.purple;
      case 'categories':
        return Colors.green;
      case 'all':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getScopeTypeText(String scopeType) {
    switch (scopeType) {
      case 'produits':
        return 'Produits spécifiques';
      case 'categories':
        return 'Par catégories';
      case 'all':
        return 'Tous les produits';
      default:
        return 'Inconnu';
    }
  }

  void _editPromotion(dynamic promotion) {
    _showPromotionForm(promotion: promotion);
  }

  void _showPromotionForm({dynamic promotion}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PromotionFormDialog(
          promotion: promotion,
          onSave: _loadPromotions,
        );
      },
    );
  }

  Widget _buildStats() {
    final totalPromotions = _promotions.length;
    final promotionsActives = _promotions.where(_isPromotionActive).length;
    final promotionsExpirees = _promotions.where((p) => _getStatusText(p) == 'Expirée').length;
    final promotionsAVenir = _promotions.where((p) => _getStatusText(p) == 'À venir').length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Row(
        children: [
          _buildStatCard('Total', totalPromotions, Icons.local_offer, Colors.blue),
          const SizedBox(width: 8),
          _buildStatCard('Actives', promotionsActives, Icons.flash_on, Colors.green),
          const SizedBox(width: 8),
          _buildStatCard('À venir', promotionsAVenir, Icons.schedule, Colors.orange),
          const SizedBox(width: 8),
          _buildStatCard('Expirées', promotionsExpirees, Icons.timer_off, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Promotions'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPromotions,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStats(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _selectedTab = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTab == 0 ? Colors.blue : Colors.grey[300],
                      foregroundColor: _selectedTab == 0 ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Toutes les Promotions'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _selectedTab = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTab == 1 ? Colors.green : Colors.grey[300],
                      foregroundColor: _selectedTab == 1 ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Promotions Actives'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, color: Colors.red),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadPromotions,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _buildPromotionsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPromotionForm(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPromotionsList() {
    final List<dynamic> displayedPromotions = _selectedTab == 0 
        ? _promotions 
        : _activePromotions;

    if (displayedPromotions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
    onRefresh: _loadPromotions,
    child: ListView.separated(
            itemCount: displayedPromotions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildPromotionCard(displayedPromotions[index]);
            },
          ),
  );
  }

  Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _selectedTab == 0 ? Icons.local_offer : Icons.flash_on,
          size: 64,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          _selectedTab == 0 
              ? 'Aucune promotion trouvée'
              : 'Aucune promotion active',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _showPromotionForm(),
          child: const Text('Créer une promotion'),
        ),
      ],
    ),
  );
}
}

class PromotionFormDialog extends StatefulWidget {
  final dynamic promotion;
  final VoidCallback onSave;

  const PromotionFormDialog({
    super.key,
    this.promotion,
    required this.onSave,
  });

  @override
  State<PromotionFormDialog> createState() => _PromotionFormDialogState();
}

class _PromotionFormDialogState extends State<PromotionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _pourcentageController = TextEditingController();
  DateTime? _dateDebut;
  DateTime? _dateFin;
  
  // Variables pour la sélection du type de portée
  String _selectedScopeType = 'produits';
  
  // Variables pour la sélection des produits
  List<dynamic> _categories = [];
  List<dynamic> _produits = [];
  Map<String, dynamic>? _selectedCategory;
  List<int> _selectedProduits = [];
  List<int> _selectedCategories = [];
  bool _loadingProduits = false;
  bool _loadingCategories = false;
  bool _mounted = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mounted = true;
    if (widget.promotion != null) {
      _descriptionController.text = widget.promotion['description'] ?? '';
      _pourcentageController.text = widget.promotion['pourcentage']?.toString() ?? '';
      
      final dateDebutStr = widget.promotion['dateDebut']?.toString();
      final dateFinStr = widget.promotion['dateFin']?.toString();
      
      if (dateDebutStr != null && dateDebutStr.isNotEmpty) {
        _dateDebut = DateTime.parse(dateDebutStr);
      }
      if (dateFinStr != null && dateFinStr.isNotEmpty) {
        _dateFin = DateTime.parse(dateFinStr);
      }
      
      // Récupérer le type de portée
      _selectedScopeType = widget.promotion['scopeType'] ?? 'produits';
      
      // Récupérer les IDs des produits/catégories sélectionnés selon le type
      if (_selectedScopeType == 'produits') {
        final produits = widget.promotion['produits'] ?? [];
        _selectedProduits = produits.map<int>((p) => p['id'] as int).toList();
      } else if (_selectedScopeType == 'categories') {
        final categories = widget.promotion['categories'] ?? [];
        _selectedCategories = categories.map<int>((c) => c['id'] as int).toList();
      }
    }
    
    // Charger les catégories au démarrage
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
    });

    try {
      final categories = await CategorieAPI.getAllCategories();
      
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _loadingCategories = false;
      });
      print('Erreur chargement catégories: $e');
    }
  }

  Future<void> _loadProduitsForCategory(String? categoryId) async {
    if (categoryId == null) return;

    setState(() {
      _loadingProduits = true;
      _produits = [];
    });

    try {
      final produitsResult = await ProduitAPI.fetchAllProduits(categorie: categoryId);
      final produits = produitsResult['data'] ?? [];
      
      setState(() {
        _produits = produits;
        _loadingProduits = false;
      });
    } catch (e) {
      setState(() {
        _loadingProduits = false;
      });
      print('Erreur chargement produits: $e');
    }
  }

  Future<void> _createPromotion(Map<String, dynamic> data) async {
    try {
      if (data["scopeType"] == "categories") {
        await PromotionAPI.applyPromotionToCategory(data);
      } else if (data["scopeType"] == "all") {
        await PromotionAPI.applyPromotionToAllProducts(data);
      } else {
        await PromotionAPI.createPromotion(data);
      }
      
      // ✅ Ajouter le feedback de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promotion créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Erreur lors de la création de la promotion : $e");
      // ✅ Propager l'erreur pour la gestion dans _savePromotion
      rethrow;
    }
  }

  void _onScopeTypeChanged(String? newScopeType) {
    if (newScopeType != null) {
      setState(() {
        _selectedScopeType = newScopeType;
        // Réinitialiser les sélections quand on change de type
        _selectedProduits.clear();
        _selectedCategories.clear();
        _selectedCategory = null;
        _produits = [];
      });
    }
  }

  void _onCategoryChanged(Map<String, dynamic>? category) {
    setState(() {
      _selectedCategory = category;
      _selectedProduits.clear(); // Réinitialiser la sélection quand on change de catégorie
    });
    
    if (category != null) {
      _loadProduitsForCategory(category['id']?.toString());
    }
  }

  void _onProductSelected(int productId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProduits.add(productId);
      } else {
        _selectedProduits.remove(productId);
      }
    });
  }

  void _onCategorySelected(int categoryId, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories.add(categoryId);
      } else {
        _selectedCategories.remove(categoryId);
      }
    });
  }

  bool _isProductSelected(int productId) {
    return _selectedProduits.contains(productId);
  }

  bool _isCategorySelected(int categoryId) {
    return _selectedCategories.contains(categoryId);
  }

  @override
  void dispose() {
    _mounted = false;
    _descriptionController.dispose();
    _pourcentageController.dispose();
    super.dispose();
  }

  Future<void> _selectDateDebut() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _dateDebut = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectDateFin() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateFin ?? (_dateDebut ?? DateTime.now()).add(const Duration(days: 7)),
      firstDate: _dateDebut ?? DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _dateFin = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _savePromotion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateDebut == null || _dateFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les dates de début et de fin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dateFin!.isBefore(_dateDebut!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de fin doit être après la date de début'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation selon le type de portée
    if (_selectedScopeType == 'produits' && _selectedProduits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un produit'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedScopeType == 'categories' && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins une catégorie'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'description': _descriptionController.text.trim(),
        'pourcentage': int.parse(_pourcentageController.text),
        'dateDebut': _dateDebut!.toIso8601String(),
        'dateFin': _dateFin!.toIso8601String(),
        'scopeType': _selectedScopeType,
      };

      // Ajouter les IDs selon le type de portée
      if (_selectedScopeType == 'produits') {
        data['produitIds'] = _selectedProduits;
      } else if (_selectedScopeType == 'categories') {
        data['categorieIds'] = _selectedCategories;
      }
      // Pour 'all', pas besoin d'ajouter d'IDs

      if (widget.promotion == null) {
        // Création
        await _createPromotion(data);
      } else {
        // Modification
        if (data["scopeType"] == "categories") {
          await PromotionAPI.updatePromotionForCategories(widget.promotion['id'], data);
        } else if (data["scopeType"] == "all") {
          await PromotionAPI.updatePromotionForAllProducts(widget.promotion['id'], data);
        } else {
          await PromotionAPI.updatePromotion(widget.promotion['id'], data);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promotion modifiée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  // Widget pour la sélection du type de portée
  Widget _buildScopeTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de promotion *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: _selectedScopeType,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 'produits',
                child: Text('Produits spécifiques'),
              ),
              DropdownMenuItem(
                value: 'categories',
                child: Text('Par catégories'),
              ),
              DropdownMenuItem(
                value: 'all',
                child: Text('Tous les produits'),
              ),
            ],
            onChanged: _onScopeTypeChanged,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _getScopeTypeDescription(_selectedScopeType),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  String _getScopeTypeDescription(String scopeType) {
    switch (scopeType) {
      case 'produits':
        return 'Sélectionnez des produits spécifiques à mettre en promotion';
      case 'categories':
        return 'Tous les produits des catégories sélectionnées seront en promotion';
      case 'all':
        return 'Tous les produits du site seront en promotion';
      default:
        return '';
    }
  }

  // Widget pour la sélection des produits
  Widget _buildProductsSelection() {
    if (_selectedScopeType != 'produits') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildCategoryDropdown(),
        const SizedBox(height: 16),
        _buildProductsList(),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catégorie (pour filtrer)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<Map<String, dynamic>>(
            value: _selectedCategory,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('Sélectionnez une catégorie'),
            items: _categories.map<DropdownMenuItem<Map<String, dynamic>>>((category) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: category,
                child: Text(category['nom']?.toString() ?? 'Sans nom'),
              );
            }).toList(),
            onChanged: _onCategoryChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList() {
    if (_selectedCategory == null) {
      return const Card(
        color: Color.fromRGBO(250, 250, 250, 1),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Veuillez sélectionner une catégorie pour voir les produits',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_loadingProduits) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_produits.isEmpty) {
      return Card(
        color: const Color.fromRGBO(250, 250, 250, 1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucun produit trouvé dans la catégorie "${_selectedCategory?['nom']}"',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Produits disponibles',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${_selectedProduits.length} sélectionné(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cochez les produits à inclure dans la promotion:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: _produits.length,
                itemBuilder: (context, index) {
                  final produit = _produits[index];
                  final productId = produit['id'] as int;
                  final productName = produit['nom']?.toString() ?? 'Sans nom';
                  final productPrice = produit['prix']?.toString() ?? '0';
                  final isSelected = _isProductSelected(productId);

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              if (value != null) {
                                _onProductSelected(productId, value);
                              }
                            },
                          ),
                          const Icon(Icons.shopping_bag, size: 20, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${productPrice}DNT',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour la sélection des catégories
  Widget _buildCategoriesSelection() {
    if (_selectedScopeType != 'categories') {
      return const SizedBox.shrink();
    }

    if (_loadingCategories) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Card(
        color: const Color.fromRGBO(250, 250, 250, 1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucune catégorie disponible',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Catégories disponibles',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${_selectedCategories.length} sélectionnée(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cochez les catégories à inclure dans la promotion:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final categorie = _categories[index];
                  final categoryId = categorie['id'] as int;
                  final categoryName = categorie['nom']?.toString() ?? 'Sans nom';
                  final isSelected = _isCategorySelected(categoryId);

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              if (value != null) {
                                _onCategorySelected(categoryId, value);
                              }
                            },
                          ),
                          const Icon(Icons.category, size: 20, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour l'option "Tous les produits"
  Widget _buildAllProductsInfo() {
    if (_selectedScopeType != 'all') {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cette promotion s\'appliquera à TOUS les produits du site.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.promotion == null ? 'Créer une promotion' : 'Modifier la promotion',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          hintText: 'Description de la promotion',
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer une description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Pourcentage
                      TextFormField(
                        controller: _pourcentageController,
                        decoration: const InputDecoration(
                          labelText: 'Pourcentage de réduction *',
                          border: OutlineInputBorder(),
                          hintText: '10, 20, 30...',
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un pourcentage';
                          }
                          final percentage = int.tryParse(value);
                          if (percentage == null || percentage <= 0 || percentage > 100) {
                            return 'Veuillez entrer un pourcentage valide (1-100)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Type de portée
                      _buildScopeTypeSelector(),
                      const SizedBox(height: 16),

                      // Sélection selon le type
                      _buildProductsSelection(),
                      _buildCategoriesSelection(),
                      _buildAllProductsInfo(),

                      const SizedBox(height: 16),

                      // Date de début
                      InkWell(
                        onTap: _selectDateDebut,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de début *',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateDebut != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(_dateDebut!)
                                    : 'Sélectionner une date',
                                style: TextStyle(
                                  color: _dateDebut != null ? Colors.black : Colors.grey,
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date de fin
                      InkWell(
                        onTap: _selectDateFin,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de fin *',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateFin != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(_dateFin!)
                                    : 'Sélectionner une date',
                                style: TextStyle(
                                  color: _dateFin != null ? Colors.black : Colors.grey,
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _savePromotion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(widget.promotion == null ? 'Créer' : 'Modifier'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PromotionDetailsDialog extends StatelessWidget {
  final dynamic promotion;
 final Function(dynamic) onDeletePromotion; // ✅ Accepter un paramètre
  final VoidCallback onProductRemoved;

  const PromotionDetailsDialog({
    super.key,
    required this.promotion,
    required this.onDeletePromotion,
    required this.onProductRemoved,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Date inconnue';
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(dynamic promotion) {
    try {
      final now = DateTime.now();
      final dateDebutStr = promotion['dateDebut']?.toString() ?? '';
      final dateFinStr = promotion['dateFin']?.toString() ?? '';
      
      if (dateDebutStr.isEmpty || dateFinStr.isEmpty) return Colors.grey;

      final dateDebut = DateTime.parse(dateDebutStr);
      final dateFin = DateTime.parse(dateFinStr);
      
      if (dateDebut.isBefore(now) && dateFin.isAfter(now)) {
        return Colors.green;
      }
      
      if (dateFin.isBefore(DateTime.now())) {
        return Colors.red;
      }
      return Colors.orange;
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getStatusText(dynamic promotion) {
    try {
      final now = DateTime.now();
      final dateDebutStr = promotion['dateDebut']?.toString() ?? '';
      final dateFinStr = promotion['dateFin']?.toString() ?? '';
      
      if (dateDebutStr.isEmpty || dateFinStr.isEmpty) return 'Inconnu';

      final dateDebut = DateTime.parse(dateDebutStr);
      final dateFin = DateTime.parse(dateFinStr);
      
      if (dateDebut.isBefore(now) && dateFin.isAfter(now)) {
        return 'Active';
      }
      
      if (dateFin.isBefore(DateTime.now())) {
        return 'Expirée';
      }
      return 'À venir';
    } catch (e) {
      return 'Inconnu';
    }
  }

  // Fonction pour supprimer un produit de la promotion
  Future<void> _removeProductFromPromotion(BuildContext context, dynamic produit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Retirer le produit'),
          content: Text('Êtes-vous sûr de vouloir retirer le produit "${produit['nom']}" de cette promotion ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Retirer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await PromotionAPI.removeProductFromPromotion(promotion['id'], produit['id']);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produit "${produit['nom']}" retiré de la promotion'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Appeler le callback pour rafraîchir les données
          onProductRemoved();
          
          // Fermer le dialogue des détails du produit si ouvert
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Fonction pour supprimer plusieurs produits
  Future<void> _removeMultipleProducts(BuildContext context, List<dynamic> produits) async {
    final produitIds = produits.map((p) => p['id'] as int).toList();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Retirer les produits'),
          content: Text('Êtes-vous sûr de vouloir retirer ${produits.length} produit${produits.length > 1 ? 's' : ''} de cette promotion ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Retirer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await PromotionAPI.removeProductsFromPromotion(promotion['id'], produitIds);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${produits.length} produit${produits.length > 1 ? 's' : ''} retiré${produits.length > 1 ? 's' : ''} de la promotion'),
              backgroundColor: Colors.green,
            ),
          );
          
          onProductRemoved();
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(promotion);
    final statusText = _getStatusText(promotion);
    final produits = promotion['produits'] ?? [];
    final pourcentage = promotion['pourcentage']?.toString() ?? '0';
    final description = promotion['description'] ?? 'Sans description';
    final dateDebut = promotion['dateDebut']?.toString() ?? '';
    final dateFin = promotion['dateFin']?.toString() ?? '';

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: const Icon(
                      Icons.local_offer,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu avec onglets
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Informations'),
                        Tab(text: 'Produits'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Onglet Informations
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.percent, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Pourcentage:',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue),
                                              ),
                                              child: Text(
                                                '-$pourcentage%',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDateInfo('Date de début', _formatDate(dateDebut), Icons.play_arrow),
                                        const SizedBox(height: 8),
                                        _buildDateInfo('Date de fin', _formatDate(dateFin), Icons.stop),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Statistiques:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildStatChip('Produits', '${produits.length}', Icons.shopping_bag),
                                            const SizedBox(width: 8),
                                            _buildStatChip('Statut', statusText, Icons.info, statusColor),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Onglet Produits AVEC FONCTIONNALITÉ DE SUPPRESSION
                          produits.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'Aucun produit associé à cette promotion',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    // En-tête avec actions
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${produits.length} produit${produits.length > 1 ? 's' : ''}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (produits.isNotEmpty)
                                            ElevatedButton.icon(
                                              onPressed: () => _removeMultipleProducts(context, produits),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                foregroundColor: Colors.white,
                                              ),
                                              icon: const Icon(Icons.remove_shopping_cart, size: 16),
                                              label: const Text('Tout retirer'),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: produits.length,
                                        itemBuilder: (context, index) {
                                          final produit = produits[index];
                                          return _buildProductItem(produit, context);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {

                          _showEditPromotion(context, promotion);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Modifier'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showDeleteConfirmation(context, promotion),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour afficher un produit avec option de suppression
  Widget _buildProductItem(dynamic produit, BuildContext context) {
    final productName = produit['nom']?.toString() ?? 'Sans nom';
    final productPrice = produit['prix']?.toString() ?? '0';
    final productStock = produit['quantite']?.toString() ?? '0';
    final productImage = produit['imageUrl']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: productImage != null && productImage.isNotEmpty
            ? CircleAvatar(
                backgroundImage: NetworkImage(productImage),
                radius: 20,
              )
            : CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                radius: 20,
                child: const Icon(Icons.shopping_bag, color: Colors.blue),
              ),
        title: Text(
          productName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${productPrice}DNT'),
            Text(
              'Stock: $productStock unités',
              style: TextStyle(
                color: (int.tryParse(productStock) ?? 0) > 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
          onPressed: () => _removeProductFromPromotion(context, produit),
          tooltip: 'Retirer de la promotion',
        ),
        onTap: () {
          _showProductDetails(context, produit);
        },
      ),
    );
  }

  Widget _buildDateInfo(String title, String date, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$title:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            date,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, [Color? color]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color ?? Colors.blue),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.blue),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blue,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: (color ?? Colors.blue).withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails(BuildContext context, dynamic produit) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(produit['nom']?.toString() ?? 'Détails du produit'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (produit['imageUrl'] != null && produit['imageUrl'].toString().isNotEmpty)
                  Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(produit['imageUrl'].toString()),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                _buildProductDetail('Prix', '${produit['prix']?.toString() ?? '0'}DNT'),
                _buildProductDetail('Stock', '${produit['quantite']?.toString() ?? '0'} unités'),
                if (produit['description'] != null && produit['description'].toString().isNotEmpty)
                  _buildProductDetail('Description', produit['description'].toString()),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _removeProductFromPromotion(context, produit),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Retirer de la promotion'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductDetail(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPromotion(BuildContext context, dynamic promotion) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PromotionFormDialog(
          promotion: promotion,
          onSave: () {
            Navigator.pop(context);
            onProductRemoved();
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, dynamic promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer la promotion "${promotion['description']}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onDeletePromotion(promotion);
      onProductRemoved();
      Navigator.pop(context);
    }
  }

}


