// lib/pages/admin/commandes_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../fetch/commande_api.dart';

class CommandesPage extends StatefulWidget {
  const CommandesPage({super.key});

  @override
  State<CommandesPage> createState() => _CommandesPageState();
}

class _CommandesPageState extends State<CommandesPage> {
  List<dynamic> _commandes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _etatFilter = 'Tous';

  final List<String> _etats = ['Tous', 'en_attente', 'confirmee', 'expediee', 'livree'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCommandes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommandes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final commandes = await CommandeAPI.getAllCommandes();
      if (!mounted) return;
      
      setState(() {
        _commandes = commandes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _commandes = [];
      });
    }
  }

  List<dynamic> get _filteredCommandes {
    var filtered = _commandes;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((commande) {
        final clientNom = commande['client'] != null 
            ? '${commande['client']['prenom']} ${commande['client']['nom']}'.toLowerCase()
            : '';
        final commandeId = commande['id']?.toString() ?? '';
        
        return clientNom.contains(_searchQuery.toLowerCase()) ||
            commandeId.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filtre par état
    if (_etatFilter != 'Tous') {
      filtered = filtered.where((commande) {
        final etat = commande['etat'] ?? '';
        // Gérer le cas où l'état est "En attente" au lieu de "en_attente"
        if (etat == 'En attente') return _etatFilter == 'en_attente';
        return etat == _etatFilter;
      }).toList();
    }

    return filtered;
  }

  Color _getEtatColor(String? etat) {
    final normalizedEtat = _normalizeEtat(etat);
    switch (normalizedEtat) {
      case 'en_attente':
        return Colors.orange;
      case 'confirmee':
        return Colors.blue;
      case 'expediee':
        return Colors.purple;
      case 'livree':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getEtatText(String? etat) {
    final normalizedEtat = _normalizeEtat(etat);
    switch (normalizedEtat) {
      case 'en_attente':
        return 'En attente';
      case 'confirmee':
        return 'Confirmée';
      case 'expediee':
        return 'Expédiée';
      case 'livree':
        return 'Livrée';
      default:
        return etat ?? 'Inconnu';
    }
  }

  String _normalizeEtat(String? etat) {
    if (etat == 'En attente') return 'en_attente';
    return etat ?? 'en_attente';
  }

  IconData _getEtatIcon(String? etat) {
    final normalizedEtat = _normalizeEtat(etat);
    switch (normalizedEtat) {
      case 'en_attente':
        return Icons.access_time;
      case 'confirmee':
        return Icons.check_circle_outline;
      case 'expediee':
        return Icons.local_shipping;
      case 'livree':
        return Icons.assignment_turned_in;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  double _calculerTotalCommande(dynamic commande) {
    try {
      if (commande['lignes'] != null && commande['lignes'] is List) {
        final lignes = commande['lignes'] as List;
        double total = 0;
        for (var ligne in lignes) {
          final quantite = ligne['quantite'] ?? 0;
          final produit = ligne['produit'];
          final prix = produit != null ? (produit['prix'] ?? 0).toDouble() : 0;
          total += quantite * prix;
        }
        return total;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  int _calculerTotalArticles(dynamic commande) {
    try {
      final lignes = (commande['lignes'] as List?) ?? [];
      return lignes.fold<int>(0, (sum, l) => sum + ((l['quantite'] ?? 0) as int));
    } catch (_) {
      return 0;
    }
  }

  Future<void> _updateCommandeEtat(int commandeId, String currentEtat) async {
    final normalizedCurrentEtat = _normalizeEtat(currentEtat);
    
    final newEtat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String selectedEtat = normalizedCurrentEtat;
        
        return AlertDialog(
          title: const Text('Modifier l\'état de la commande'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEtatRadio('en_attente', 'En attente', selectedEtat, (value) {
                      setState(() {
                        selectedEtat = value!;
                      });
                    }),
                    _buildEtatRadio('confirmee', 'Confirmée', selectedEtat, (value) {
                      setState(() {
                        selectedEtat = value!;
                      });
                    }),
                    _buildEtatRadio('expediee', 'Expédiée', selectedEtat, (value) {
                      setState(() {
                        selectedEtat = value!;
                      });
                    }),
                    _buildEtatRadio('livree', 'Livrée', selectedEtat, (value) {
                      setState(() {
                        selectedEtat = value!;
                      });
                    }),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedEtat),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (newEtat != null && newEtat != normalizedCurrentEtat) {
      try {
        await CommandeAPI.updateCommande(commandeId, newEtat);
        await Future.delayed(const Duration(milliseconds: 500));
        _loadCommandes();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commande mise à jour: ${_getEtatText(newEtat)}'),
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
  }

  Widget _buildEtatRadio(String etat, String label, String selectedEtat, ValueChanged<String?> onChanged) {
    return RadioListTile<String>(
      title: Text(label),
      value: etat,
      groupValue: selectedEtat,
      onChanged: onChanged,
      secondary: Icon(_getEtatIcon(etat), color: _getEtatColor(etat)),
    );
  }

  Future<void> _showCommandeDetails(dynamic commande) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final client = commande['client'];
        final clientNom = client != null ? '${client['prenom']} ${client['nom']}' : 'Client inconnu';
        final lignes = commande['lignes'] ?? [];
        final total = _calculerTotalCommande(commande);
        final totalArticles = _calculerTotalArticles(commande);

        return AlertDialog(
          title: Text('Commande #${commande['id']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Informations client
                const Text(
                  'Informations client:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('👤 $clientNom'),
                const SizedBox(height: 16),
                
                // Résumé commande
                const Text(
                  'Résumé de la commande:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('📦 $totalArticles article${totalArticles > 1 ? 's' : ''}'),
                Text('💰 Total: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'DNT').format(total)}'),
                const SizedBox(height: 16),
                
                // Détails des articles
                const Text(
                  'Articles commandés:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...lignes.map<Widget>((ligne) {
                  final produit = ligne['produit'];
                  final nomProduit = produit != null ? produit['nom'] : 'Produit inconnu';
                  final prix = produit != null ? (produit['prix'] ?? 0).toDouble() : 0;
                  final quantite = ligne['quantite'] ?? 0;
                  final sousTotal = prix * quantite;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shopping_bag, size: 20),
                    title: Text(nomProduit),
                    subtitle: Text('$quantite x ${NumberFormat.currency(locale: 'fr_FR', symbol: 'DNT').format(prix)}'),
                    trailing: Text(
                      NumberFormat.currency(locale: 'fr_FR', symbol: 'DNT').format(sousTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                
                // Métadonnées
                const Text(
                  'Informations:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('📅 Date: ${_formatDate(commande['date_commande'])}'),
                Text('🏷️ État: ${_getEtatText(commande['etat'])}'),
                if (commande['administrateurId'] != null)
                  Text('👨‍💼 Gérée par admin #${commande['administrateurId']}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommandeCard(dynamic commande) {
    final etat = commande['etat'] ?? 'en_attente';
    final etatColor = _getEtatColor(etat);
    final client = commande['client'];
    final clientNom = client != null ? '${client['prenom']} ${client['nom']}' : 'Client inconnu';
    final total = _calculerTotalCommande(commande);
    final totalArticles = _calculerTotalArticles(commande);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => _showCommandeDetails(commande),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec numéro de commande et état
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commande #${commande['id']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: etatColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: etatColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getEtatIcon(etat), size: 14, color: etatColor),
                        const SizedBox(width: 4),
                        Text(
                          _getEtatText(etat).toUpperCase(),
                          style: TextStyle(
                            color: etatColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Informations client
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      clientNom,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Résumé commande
              Row(
                children: [
                  const Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '$totalArticles article${totalArticles > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormat.currency(locale: 'fr_FR', symbol: 'DNT').format(total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Date et actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(commande['date_commande']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _updateCommandeEtat(commande['id'], etat),
                    tooltip: 'Modifier l\'état',
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Rechercher une commande...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _etats.map((etat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_getEtatText(etat)),
                    selected: _etatFilter == etat,
                    onSelected: (selected) => setState(() => _etatFilter = etat),
                    selectedColor: _getEtatColor(etat).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _etatFilter == etat ? _getEtatColor(etat) : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final totalCommandes = _commandes.length;
    final enAttente = _commandes.where((c) => _normalizeEtat(c['etat']) == 'en_attente').length;
    final confirmees = _commandes.where((c) => _normalizeEtat(c['etat']) == 'confirmee').length;
    final livrees = _commandes.where((c) => _normalizeEtat(c['etat']) == 'livree').length;

    // Calcul du chiffre d'affaires total
    double chiffreAffaires = 0;
    for (var commande in _commandes) {
      chiffreAffaires += _calculerTotalCommande(commande);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard('Total', totalCommandes, Icons.shopping_cart, Colors.blue),
              const SizedBox(width: 8),
              _buildStatCard('En attente', enAttente, Icons.access_time, Colors.orange),
              const SizedBox(width: 8),
              _buildStatCard('Confirmées', confirmees, Icons.check_circle, Colors.blue),
              const SizedBox(width: 8),
              _buildStatCard('Livrées', livrees, Icons.assignment_turned_in, Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Chiffre d\'affaires:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormat.currency(locale: 'fr_FR', symbol: 'DNT').format(chiffreAffaires),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        title: const Text('Gestion des Commandes'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCommandes,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStats(),
          _buildFilters(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_filteredCommandes.length} commande${_filteredCommandes.length > 1 ? 's' : ''} trouvée${_filteredCommandes.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                              onPressed: _loadCommandes,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _filteredCommandes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucune commande trouvée',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                if (_searchQuery.isNotEmpty || _etatFilter != 'Tous')
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _etatFilter = 'Tous';
                                      });
                                    },
                                    child: const Text('Réinitialiser les filtres'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCommandes,
                            child: ListView.builder(
                              itemCount: _filteredCommandes.length,
                              itemBuilder: (context, index) {
                                return _buildCommandeCard(_filteredCommandes[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}