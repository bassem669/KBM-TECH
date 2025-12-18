// pages/admin_produit_form_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../fetch/admin_produit_service.dart';
import '../../fetch/categorie_api.dart';

final String baseUrl = dotenv.env['IMAGE_URL'] ?? 'http://10.74.118.163:5000';

class AdminProduitFormPage extends StatefulWidget {
  final Map<String, dynamic>? produit;
  final Function onSave;

  AdminProduitFormPage({this.produit, required this.onSave});

  @override
  _AdminProduitFormPageState createState() => _AdminProduitFormPageState();
}

class _AdminProduitFormPageState extends State<AdminProduitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prixController = TextEditingController();
  final _quantiteController = TextEditingController();
  
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isLoading = false;

  List<dynamic> _existingImages = []; 
  bool _loadingImages = false;

  // Gestion des catégories
  List<dynamic> _allCategories = [];
  List<int> _selectedCategoryIds = [];
  bool _loadingCategories = false;

  @override
  void initState() {
    super.initState();
    if (widget.produit != null) {
      _nomController.text = widget.produit!['nom'] ?? '';
      _descriptionController.text = widget.produit!['description'] ?? '';
      _prixController.text = (widget.produit!['prix']?.toString() ?? '0');
      _quantiteController.text = (widget.produit!['quantite']?.toString() ?? '0');
      
      // Initialiser les catégories sélectionnées
      final categories = widget.produit!['categories'] as List? ?? [];
      _selectedCategoryIds = categories.map<int>((cat) => cat['id'] as int).toList();
      
      _loadExistingImages();
    }
    _loadCategories();
  }

  // Charger toutes les catégories
  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
    });
    
    try {
      final categories = await CategorieAPI.getAllCategories();
      setState(() {
        _allCategories = categories;
      });
    } catch (e) {
      print('❌ Erreur chargement catégories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des catégories: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loadingCategories = false;
      });
    }
  }

  // Gérer la sélection/déselection des catégories
  void _toggleCategory(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  // Widget pour l'interface de sélection des catégories
  Widget _buildCategorySelection() {
    if (_loadingCategories) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Chargement des catégories...'),
          ],
        ),
      );
    }

    if (_allCategories.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.category, size: 48, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text(
              'Aucune catégorie disponible',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Les catégories seront disponibles après leur création',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catégories sélectionnées: ${_selectedCategoryIds.length}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allCategories.map((category) {
            final isSelected = _selectedCategoryIds.contains(category['id']);
            return FilterChip(
              label: Text(
                category['nom'] ?? 'Sans nom',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: isSelected,
              onSelected: (selected) => _toggleCategory(category['id']),
              backgroundColor: Colors.grey[100],
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        Text(
          'Cliquez sur les catégories pour les sélectionner/désélectionner',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (images != null && images.isNotEmpty) {
        // Vérifier le nombre total d'images
        final totalImages = _selectedImages.length + images.length;
        if (totalImages > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum 10 images autorisées. Vous avez déjà ${_selectedImages.length} images.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection des images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Vérifier le nombre total d'images
        if (_selectedImages.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum 10 images autorisées.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la prise de photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        if (widget.produit == null) {
          // Créer un nouveau produit avec images et catégories
          await AdminProduitService.createProduit(
            nom: _nomController.text,
            description: _descriptionController.text,
            prix: double.parse(_prixController.text),
            quantite: int.parse(_quantiteController.text),
            images: _selectedImages,
            categorieIds: _selectedCategoryIds,
          );
        } else {
          // Modifier un produit existant avec images et catégories
          await AdminProduitService.updateProduit(
            id: widget.produit!['id'],
            nom: _nomController.text,
            description: _descriptionController.text,
            prix: double.parse(_prixController.text),
            quantite: int.parse(_quantiteController.text),
            images: _selectedImages,
            categorieIds: _selectedCategoryIds,
          );
        }

        widget.onSave();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.produit == null ? 'Produit créé avec succès !' : 'Produit modifié avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _loadExistingImages() async {
    if (widget.produit == null) return;
    
    setState(() {
      _loadingImages = true;
    });
    
    try {
      final images = await AdminProduitService.getProductImages(widget.produit!['id']);
      setState(() {
        _existingImages = images;
      });
    } catch (e) {
      print('❌ Erreur chargement images existantes: $e');
    } finally {
      setState(() {
        _loadingImages = false;
      });
    }
  }

  // Supprimer une image existante
  Future<void> _deleteExistingImage(int imageId, int index) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer cette image ?'),
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

    if (confirm == true) {
      try {
        await AdminProduitService.deleteProductImage(widget.produit!['id'], imageId);
        
        // Mettre à jour la liste locale
        setState(() {
          _existingImages.removeAt(index);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Widget pour afficher les images existantes
  Widget _buildExistingImages() {
    if (_loadingImages) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_existingImages.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Images existantes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _existingImages.length,
          itemBuilder: (context, index) {
            final image = _existingImages[index];
            final imageUrl = '$baseUrl${image['path']}';
            
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
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
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.broken_image, color: Colors.grey[400]),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _deleteExistingImage(image['id'], index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: 8),
        Text(
          '${_existingImages.length} image(s) existante(s) - Cliquez sur 🗑️ pour supprimer',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImages.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.photo_library, size: 48, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text(
              'Aucune image sélectionnée',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Ajoutez des images pour présenter votre produit',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_selectedImages[index].path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.error, color: Colors.red),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.produit == null ? 'Nouveau Produit' : 'Modifier Produit'),
        backgroundColor: Colors.blueGrey[800], 
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Enregistrement en cours...',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Section Images
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.photo_library, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Images du produit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            if (widget.produit != null) _buildExistingImages(),
                            
                            // Boutons d'ajout d'images
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickImages,
                                    icon: Icon(Icons.photo_library, size: 20),
                                    label: Text('Galerie'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: BorderSide(color: Colors.blue),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _takePhoto,
                                    icon: Icon(Icons.camera_alt, size: 20),
                                    label: Text('Caméra'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: BorderSide(color: Colors.green),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 16),
                            
                            // Aperçu des images
                            _buildImagePreview(),
                            
                            SizedBox(height: 8),
                            
                            // Information sur les images
                            Text(
                              '${_selectedImages.length} image(s) sélectionnée(s) - Maximum 10 images',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Section Catégories
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.category, color: Colors.purple),
                                SizedBox(width: 8),
                                Text(
                                  'Catégories du produit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildCategorySelection(),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Section Informations de base
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nomController,
                              decoration: InputDecoration(
                                labelText: 'Nom du produit *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.shopping_bag, color: Colors.blue),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Le nom est requis';
                                if (value.length < 2) return 'Le nom doit contenir au moins 2 caractères';
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Description *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description, color: Colors.blue),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'La description est requise';
                                if (value.length < 10) return 'La description doit contenir au moins 10 caractères';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Section Prix et Stock
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _prixController,
                              decoration: InputDecoration(
                                labelText: 'Prix (DNT) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.euro, color: Colors.blue),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Le prix est requis';
                                if (double.tryParse(value) == null) return 'Prix invalide';
                                if (double.parse(value) <= 0) return 'Le prix doit être supérieur à 0';
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _quantiteController,
                              decoration: InputDecoration(
                                labelText: 'Quantité en stock *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.inventory, color: Colors.blue),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'La quantité est requise';
                                if (int.tryParse(value) == null) return 'Quantité invalide';
                                if (int.parse(value) < 0) return 'La quantité ne peut pas être négative';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Annuler',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    widget.produit == null ? 'Créer le produit' : 'Modifier le produit',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Information
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Les champs marqués d\'un * sont obligatoires.',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Vous pouvez ajouter jusqu\'à 10 images et sélectionner plusieurs catégories pour votre produit.',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    _quantiteController.dispose();
    super.dispose();
  }
}