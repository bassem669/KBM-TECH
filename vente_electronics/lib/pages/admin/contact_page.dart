// lib/pages/admin/contacts_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../fetch/contact_api.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _etatFilter = 'Tous';

  final List<String> _etats = ['Tous', 'nouveau', 'en cours', 'resolu', 'ferme'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final contacts = await ContactService.getAllContacts();
      if (!mounted) return;
      
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _contacts = [];
      });
    }
  }

  List<dynamic> get _filteredContacts {
    var filtered = _contacts;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((contact) {
        final titre = (contact['titre'] ?? '').toString().toLowerCase();
        final message = (contact['message'] ?? '').toString().toLowerCase();
        final clientNom = contact['client'] != null 
            ? '${contact['client']['prenom']} ${contact['client']['nom']}'.toLowerCase()
            : '';
        final clientEmail = contact['client'] != null 
            ? (contact['client']['email'] ?? '').toString().toLowerCase()
            : '';
        
        return titre.contains(_searchQuery.toLowerCase()) ||
            message.contains(_searchQuery.toLowerCase()) ||
            clientNom.contains(_searchQuery.toLowerCase()) ||
            clientEmail.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filtre par état
    if (_etatFilter != 'Tous') {
      filtered = filtered.where((contact) => contact['etat'] == _etatFilter).toList();
    }

    return filtered;
  }

  Color _getEtatColor(String? etat) {
    switch (etat) {
      case 'nouveau':
        return Colors.blue;
      case 'en cours':
        return Colors.orange;
      case 'resolu':
        return Colors.green;
      case 'ferme':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  IconData _getEtatIcon(String? etat) {
    switch (etat) {
      case 'nouveau':
        return Icons.markunread;
      case 'en cours':
        return Icons.hourglass_empty;
      case 'resolu':
        return Icons.check_circle;
      case 'ferme':
        return Icons.archive;
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

    Future<void> _updateContactEtat(int contactId, String currentEtat) async {
    String? selectedEtat = currentEtat;

    final newEtat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier l\'état'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Nouveau'),
                    value: 'nouveau',
                    groupValue: selectedEtat,
                    onChanged: (value) {
                      setState(() {
                        selectedEtat = value;
                      });
                    },
                    secondary: const Icon(Icons.markunread, color: Colors.blue),
                  ),
                  RadioListTile<String>(
                    title: const Text('En cours'),
                    value: 'en cours',
                    groupValue: selectedEtat,
                    onChanged: (value) {
                      setState(() {
                        selectedEtat = value;
                      });
                    },
                    secondary: const Icon(Icons.hourglass_empty, color: Colors.orange),
                  ),
                  RadioListTile<String>(
                    title: const Text('Résolu'),
                    value: 'resolu',
                    groupValue: selectedEtat,
                    onChanged: (value) {
                      setState(() {
                        selectedEtat = value;
                      });
                    },
                    secondary: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  RadioListTile<String>(
                    title: const Text('Fermé'),
                    value: 'ferme',
                    groupValue: selectedEtat,
                    onChanged: (value) {
                      setState(() {
                        selectedEtat = value;
                      });
                    },
                    secondary: const Icon(Icons.archive, color: Colors.grey),
                  ),
                ],
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
      },
    );

    if (newEtat != null && newEtat != currentEtat) {
      try {
        await ContactService.updateContact(contactId, {'etat': newEtat});
        await Future.delayed(const Duration(milliseconds: 500));
        _loadContacts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('État mis à jour: $newEtat'),
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


  Future<void> _showContactDetails(dynamic contact) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final client = contact['client'];
        final clientNom = client != null ? '${client['prenom']} ${client['nom']}' : 'Inconnu';
        final clientEmail = client != null ? client['email'] : 'Non renseigné';
        
        return AlertDialog(
          title: Text(contact['titre'] ?? 'Sans titre'),
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
                Text('📧 $clientEmail'),
                const SizedBox(height: 16),
                
                // Message
                const Text(
                  'Message:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  contact['message'] ?? 'Aucun message',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                
                // Métadonnées
                const Text(
                  'Informations:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('📅 Date: ${_formatDate(contact['date_contact'])}'),
                Text('🏷️ État: ${contact['etat'] ?? 'Non défini'}'),
                if (contact['createdAt'] != null)
                  Text('🕒 Créé le: ${_formatDate(contact['createdAt'])}'),
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

  Future<void> _deleteContact(int contactId, String titre) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer le contact "$titre" ?'),
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
      try {
        await ContactService.deleteContact(contactId);
        await Future.delayed(const Duration(milliseconds: 500));
        _loadContacts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact "$titre" supprimé'),
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

  Widget _buildContactCard(dynamic contact) {
    final etat = contact['etat'] ?? 'nouveau';
    final etatColor = _getEtatColor(etat);
    final client = contact['client'];
    final clientNom = client != null ? '${client['prenom']} ${client['nom']}' : 'Client inconnu';
    final clientEmail = client != null ? client['email'] : 'Email non disponible';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: () => _showContactDetails(contact),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec titre et état
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contact['titre'] ?? 'Sans titre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                          etat.toUpperCase(),
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
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      clientEmail,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Message (extrait)
              Text(
                contact['message'] ?? 'Aucun message',
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Date et actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(contact['date_contact']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _updateContactEtat(contact['id'], etat),
                        tooltip: 'Modifier l\'état',
                        color: Colors.blue,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () => _deleteContact(contact['id'], contact['titre'] ?? 'Sans titre'),
                        tooltip: 'Supprimer',
                        color: Colors.red,
                      ),
                    ],
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
              labelText: 'Rechercher un contact...',
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
                    label: Text(etat),
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
    final totalContacts = _contacts.length;
    final nouveaux = _contacts.where((c) => c['etat'] == 'nouveau').length;
    final enCours = _contacts.where((c) => c['etat'] == 'en cours').length;
    final resolus = _contacts.where((c) => c['etat'] == 'resolu').length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Row(
        children: [
          _buildStatCard('Total', totalContacts, Icons.contact_mail, Colors.blue),
          const SizedBox(width: 8),
          _buildStatCard('Nouveaux', nouveaux, Icons.markunread, Colors.blue),
          const SizedBox(width: 8),
          _buildStatCard('En cours', enCours, Icons.hourglass_empty, Colors.orange),
          const SizedBox(width: 8),
          _buildStatCard('Résolus', resolus, Icons.check_circle, Colors.green),
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
        title: const Text('Gestion des Contacts'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
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
              '${_filteredContacts.length} contact${_filteredContacts.length > 1 ? 's' : ''} trouvé${_filteredContacts.length > 1 ? 's' : ''}',
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
                              onPressed: _loadContacts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _filteredContacts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.contact_mail_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucun contact trouvé',
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
                            onRefresh: _loadContacts,
                            child: ListView.builder(
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                return _buildContactCard(_filteredContacts[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}