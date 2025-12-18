// lib/pages/avis_list_page.dart
import 'package:flutter/material.dart';
import '../fetch/avis_api.dart';

class AvisListPage extends StatefulWidget {
  final int userId;
  final int produitId;
  final String produitNom;
  final double noteMoyenne;
  final int totalAvis;
  final List<dynamic> avis;

  const AvisListPage({
    Key? key,
    required this.userId,
    required this.produitId,
    required this.produitNom,
    required this.noteMoyenne,
    required this.totalAvis,
    required this.avis,
  }) : super(key: key);

  @override
  State<AvisListPage> createState() => _AvisListPageState();
}

class _AvisListPageState extends State<AvisListPage> {
  late List<dynamic> _avisFiltres;
  String _filtreNote = 'Toutes';
  String _filtreTri = 'Plus récents';
  bool _showFilterPanel = false;

  // NOUVEAU: Pour gérer la modification et suppression
  bool _modificationEnCours = false;
  TextEditingController? _modificationAvisCtrl;
  int _noteModification = 5;
  
  // NOUVEAU: User ID (à adapter avec votre système d'auth)

  final Map<String, int> _filtresNotes = {
    'Toutes': 0,
    '5 étoiles': 5,
    '4 étoiles': 4,
    '3 étoiles': 3,
    '2 étoiles': 2,
    '1 étoile': 1,
  };

  final List<String> _optionsTri = [
    'Plus récents',
    'Plus anciens',
    'Meilleures notes',
    'Moins bonnes notes',
  ];

  @override
  void initState() {
    super.initState();
    _avisFiltres = List.from(widget.avis);
    _appliquerFiltres();
  }

  @override
  void dispose() {
    _modificationAvisCtrl?.dispose();
    super.dispose();
  }

  void _appliquerFiltres() {
    setState(() {
      _avisFiltres = List.from(widget.avis);

      // Filtrage par note
      if (_filtreNote != 'Toutes') {
        final noteFiltre = _filtresNotes[_filtreNote]!;
        _avisFiltres = _avisFiltres.where((avis) {
          final note = _getNote(avis);
          return note.floor() == noteFiltre;
        }).toList();
      }

      // Tri
      switch (_filtreTri) {
        case 'Plus récents':
          _avisFiltres.sort((a, b) => _getDate(b).compareTo(_getDate(a)));
          break;
        case 'Plus anciens':
          _avisFiltres.sort((a, b) => _getDate(a).compareTo(_getDate(b)));
          break;
        case 'Meilleures notes':
          _avisFiltres.sort((a, b) => _getNote(b).compareTo(_getNote(a)));
          break;
        case 'Moins bonnes notes':
          _avisFiltres.sort((a, b) => _getNote(a).compareTo(_getNote(b)));
          break;
      }
    });
  }

  double _getNote(dynamic avis) {
    return (avis['note'] ?? avis['rating'] ?? 0).toDouble();
  }

  DateTime _getDate(dynamic avis) {
    final dateString = avis['date_avis']?.toString() ?? 
                      avis['createdAt']?.toString() ?? 
                      avis['date']?.toString() ?? '';
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  // NOUVEAU: Vérifier si un avis appartient à l'utilisateur connecté
  bool _estMonAvis(Map<String, dynamic> avis) {
    final clientId = avis['client_id'];
    return clientId == widget.userId;
  }

  // NOUVEAU: Modifier un avis
  Future<void> _modifierAvis(Map<String, dynamic> avis) async {
    final avisId = avis['id'];
    
    // Initialiser le contrôleur de modification avec le texte existant
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
                // Sélecteur de note
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
                // Champ de commentaire
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

  // NOUVEAU: Confirmer la modification
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
        // Fermer le dialog
        if (context.mounted) Navigator.pop(context);
        
        // Recharger les données depuis le parent
        if (context.mounted) {
          Navigator.pop(context, true); // Retourner true pour indiquer une modification
        }
        
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

  // NOUVEAU: Supprimer un avis
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

  // NOUVEAU: Confirmer la suppression
  Future<void> _confirmerSuppression(int avisId) async {
    try {
      final result = await AvisAPI.supprimer(avisId);
      
      if (result['success'] == true) {
        // Fermer le dialog
        if (context.mounted) Navigator.pop(context);
        
        // Recharger les données depuis le parent
        if (context.mounted) {
          Navigator.pop(context, true); // Retourner true pour indiquer une suppression
        }
        
        _showSuccessSnackBar('Avis supprimé avec succès');
      } else {
        _showErrorSnackBar(result['message'] ?? 'Erreur lors de la suppression');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: ${e.toString()}');
    }
  }

  // NOUVEAU: Snackbars
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
      ),
    );
  }

  Map<String, int> _getStatsNotes() {
    final Map<String, int> stats = {
      '5': 0,
      '4': 0,
      '3': 0,
      '2': 0,
      '1': 0,
    };
    
    for (final avis in widget.avis) {
      final note = _getNote(avis).floor();
      final noteKey = note.toString();
      if (stats.containsKey(noteKey)) {
        stats[noteKey] = stats[noteKey]! + 1;
      }
    }
    return stats;
  }

  Widget _buildHeader(BuildContext context) {
    final statsNotes = _getStatsNotes();

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Avis clients",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilterPanel ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                  color: Colors.blue[700],
                ),
                onPressed: () {
                  setState(() {
                    _showFilterPanel = !_showFilterPanel;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      widget.noteMoyenne.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    _buildRatingStars(widget.noteMoyenne),
                    SizedBox(height: 4),
                    Text(
                      '${widget.totalAvis} avis',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.produitNom,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      ..._buildProgressBars(statsNotes),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showFilterPanel) _buildFilterPanel(),
        ],
      ),
    );
  }

  List<Widget> _buildProgressBars(Map<String, int> stats) {
    // Trier les notes de 5 à 1 pour l'affichage
    final sortedEntries = stats.entries.toList()
      ..sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));

    return sortedEntries.map((entry) {
      final note = entry.key;
      final count = entry.value;
      final percentage = widget.totalAvis > 0 ? count / widget.totalAvis : 0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                note,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.star_rounded, size: 16, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage.toDouble(),
                  child: Container( 
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 20,
              child: Text(
                '$count',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildFilterPanel() {
    return Column(
      children: [
        SizedBox(height: 16),
        Divider(),
        SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Filtrer par note:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _filtresNotes.entries.map((entry) {
            final isSelected = _filtreNote == entry.key;
            return FilterChip(
              selected: isSelected,
              label: Text(entry.key),
              onSelected: (selected) {
                setState(() {
                  _filtreNote = selected ? entry.key : 'Toutes';
                  _appliquerFiltres();
                });
              },
              backgroundColor: Colors.grey[100],
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[700],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Trier par:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _optionsTri.map((option) {
            final isSelected = _filtreTri == option;
            return FilterChip(
              selected: isSelected,
              label: Text(option),
              onSelected: (selected) {
                setState(() {
                  _filtreTri = option;
                  _appliquerFiltres();
                });
              },
              backgroundColor: Colors.grey[100],
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[700],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filtreNote = 'Toutes';
                  _filtreTri = 'Plus récents';
                  _appliquerFiltres();
                });
              },
              child: Text(
                'Réinitialiser',
                style: TextStyle(color: Colors.blue[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvisList() {
    if (_avisFiltres.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "Aucun avis trouvé",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Essayez de modifier vos filtres",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filtreNote = 'Toutes';
                    _filtreTri = 'Plus récents';
                    _appliquerFiltres();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Réinitialiser les filtres'),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_avisFiltres.length} avis${_filtreNote != 'Toutes' ? ' ($_filtreNote)' : ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                if (_filtreNote != 'Toutes' || _filtreTri != 'Plus récents')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFilterPanel = true;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: Colors.blue[700]),
                        SizedBox(width: 4),
                        Text(
                          'Filtres actifs',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _avisFiltres.length,
              itemBuilder: (context, index) {
                final avis = _avisFiltres[index];
                return _AvisCard(
                  avis: avis,
                  isCurrentUser: _estMonAvis(avis),
                  onModifier: _estMonAvis(avis) ? _modifierAvis : null,
                  onSupprimer: _estMonAvis(avis) ? _supprimerAvis : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating, {double size = 20}) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star_rounded : 
          (index == rating.floor() && rating % 1 >= 0.5) ? Icons.star_half_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(context),
          SizedBox(height: 16),
          _buildAvisList(),
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
           'Aucun commentaire';
  }

  Map<String, dynamic>? _getUtilisateur() {
    return avis['utilisateur'] ?? avis['client'] ?? avis['user'];
  }

  String _getDateCreation() {
    return avis['date_avis']?.toString() ?? 
           avis['createdAt']?.toString() ?? 
           avis['date']?.toString() ?? '';
  }

  Widget _buildRatingStars(double rating, {double size = 16}) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star_rounded : 
          (index == rating.floor() && rating % 1 >= 0.5) ? Icons.star_half_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: size,
        );
      }),
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

  @override
  Widget build(BuildContext context) {
    final note = _getNote();
    final commentaire = _getCommentaire();
    final utilisateur = _getUtilisateur();
    final nomUtilisateur = utilisateur?['nom']?.toString() ?? 'Utilisateur';
    final prenomUtilisateur = utilisateur?['prenom']?.toString() ?? 'Utilisateur';
    final dateCreation = _getDateCreation();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
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
                                    style: TextStyle(
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
                        // NOTE ET ACTIONS
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  SizedBox(width: 4),
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
                    SizedBox(height: 12),
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
}