// lib/pages/admin/utilisateurs_page.dart
import 'package:flutter/material.dart';
import '../../fetch/user_api.dart'; // ← Import corrigé

class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key});

  @override
  State<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends State<UtilisateursPage> {
  List<dynamic> _utilisateurs = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _roleFilter = 'Tous';

  final List<String> _roles = ['Tous', 'admin', 'client'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUtilisateurs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUtilisateurs() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await UtilisateurService.getAllUtilisateurs();
      if (!mounted) return;
      
      setState(() {
        _utilisateurs = data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _utilisateurs = [];
      });
    }
  }

  List<dynamic> get _filteredUtilisateurs {
    var filtered = _utilisateurs;

    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final nomComplet = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.toLowerCase();
        final email = (user['email']?.toString().toLowerCase() ?? '');
        return nomComplet.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filtre par rôle
    if (_roleFilter != 'Tous') {
      filtered = filtered.where((user) => user['role'] == _roleFilter).toList();
    }

    return filtered;
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'client':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.security;
      case 'client':
        return Icons.person;
      default:
        return Icons.help;
    }
  }

  Future<void> _updateUserRole(int userId, String currentRole) async {
  String? newRole = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _RoleSelectionDialog(currentRole: currentRole);
    },
  );

  if (newRole != null && newRole != currentRole) {
    try {
      await UtilisateurService.updateUserRole(userId, newRole);
      await Future.delayed(const Duration(milliseconds: 500));
      _loadUtilisateurs();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rôle mis à jour: $newRole'),
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

  Future<void> _deleteUser(int userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer l\'utilisateur "$userName" ?'),
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
        await UtilisateurService.deleteUtilisateur(userId);
        // Recharger après un court délai
        await Future.delayed(const Duration(milliseconds: 500));
        _loadUtilisateurs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Utilisateur "$userName" supprimé'),
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

  Widget _buildUserCard(dynamic user) {
    final userRole = user['role'] ?? 'client';
    final roleColor = _getRoleColor(userRole);
    final nbCommandes = user['nb_commande'] ?? 0;
    final prenom = user['prenom'] ?? '';
    final nom = user['nom'] ?? '';
    final email = user['email'] ?? 'Aucun email';
    final tel = user['tel'];
    final adresse = user['adresse'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Icon(
                    _getRoleIcon(userRole),
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$prenom $nom'.trim(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roleColor),
                  ),
                  child: Text(
                    userRole.toUpperCase(),
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (tel != null && tel.toString().isNotEmpty)
                  _buildInfoChip(Icons.phone, tel.toString()),
                _buildInfoChip(
                  Icons.shopping_cart, 
                  '$nbCommandes commande${nbCommandes > 1 ? 's' : ''}'
                ),
                if (adresse.isNotEmpty)
                  _buildInfoChip(Icons.location_on, 'Adresse'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _updateUserRole(user['id'], userRole),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier rôle'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _deleteUser(user['id'], '$prenom $nom'.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
      avatar: Icon(icon, size: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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
              labelText: 'Rechercher un utilisateur...',
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
              children: _roles.map((role) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(role),
                    selected: _roleFilter == role,
                    onSelected: (selected) => setState(() => _roleFilter = role),
                    selectedColor: Colors.blue.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _roleFilter == role ? Colors.blue : Colors.black87,
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
    final totalUsers = _utilisateurs.length;
    final admins = _utilisateurs.where((u) => u['role'] == 'admin').length;
    final clients = _utilisateurs.where((u) => u['role'] == 'client').length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Row(
        children: [
          _buildStatCard('Total', totalUsers, Icons.people, Colors.blue),
          const SizedBox(width: 8),
          _buildStatCard('Admins', admins, Icons.security, Colors.red),
          const SizedBox(width: 8),
          _buildStatCard('Clients', clients, Icons.person, Colors.green),
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
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
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
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUtilisateurs,
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
              '${_filteredUtilisateurs.length} utilisateur${_filteredUtilisateurs.length > 1 ? 's' : ''} trouvé${_filteredUtilisateurs.length > 1 ? 's' : ''}',
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
                              onPressed: _loadUtilisateurs,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUtilisateurs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucun utilisateur trouvé',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                if (_searchQuery.isNotEmpty || _roleFilter != 'Tous')
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _roleFilter = 'Tous';
                                      });
                                    },
                                    child: const Text('Réinitialiser les filtres'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUtilisateurs,
                            child: ListView.builder(
                              itemCount: _filteredUtilisateurs.length,
                              itemBuilder: (context, index) {
                                return _buildUserCard(_filteredUtilisateurs[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _RoleSelectionDialog extends StatefulWidget {
  final String currentRole;

  const _RoleSelectionDialog({required this.currentRole});

  @override
  State<_RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<_RoleSelectionDialog> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le rôle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoleRadio('admin', 'Administrateur'),
          _buildRoleRadio('client', 'Client'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedRole),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }

  Widget _buildRoleRadio(String role, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: role,
      groupValue: _selectedRole,
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
        });
      },
      secondary: Icon(
        _getRoleIcon(role), 
        color: _getRoleColor(role),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'client':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.security;
      case 'client':
        return Icons.person;
      default:
        return Icons.help;
    }
  }
}