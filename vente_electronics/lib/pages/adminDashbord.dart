// lib/pages/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import './../fetch/auth_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './../../fetch/notification_api.dart';

final String baseUrl = dotenv.env['STATS_URL'] ?? 'http://192.168.1.54:5000/api/stats';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> stats = {
    'nb_utilisateurs': 0,
    'nb_commandes': 0,
    'nb_promotions': 0,
  };
  
  bool isLoading = true;
  String errorMessage = '';
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    setState(() {
      unreadCount = count;
    });
  }

  Future<void> _fetchStats() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final token = await AuthAPI.getToken();

      if (token == null) {
        setState(() {
          errorMessage = "Token non trouvé. Veuillez vous reconnecter.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          setState(() {
            stats = {
              'nb_utilisateurs': data['data']['nb_utilisateurs'] ?? 0,
              'nb_commandes': data['data']['nb_commandes'] ?? 0,
              'nb_promotions': data['data']['nb_promotions'] ?? 0,
            };
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "Format des données incorrect.";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Erreur serveur (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Erreur de connexion : $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrateur'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Bouton de notifications avec badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/notifications');
                },
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchStats();
              _loadUnreadCount(); // Recharger aussi le compteur de notifications
            },
            tooltip: 'Actualiser les statistiques',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statistiques
            _buildHeader(context),
            
            // Message d'erreur
            if (errorMessage.isNotEmpty) _buildErrorWidget(),
            
            // Grille des fonctionnalités
            _buildDashboardGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue, Administrateur',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gérez votre plateforme e-commerce',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de notifications dans l'en-tête (optionnel)
            ],
          ),
          const SizedBox(height: 16),
          // Statistiques rapides - version dynamique
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    if (isLoading) {
      return _buildLoadingStats();
    }

    return Row(
        children: [
          _buildStatItem(
            Icons.people, 
            'Utilisateurs', 
            stats['nb_utilisateurs'].toString(), 
            Colors.blue
          ),
          const SizedBox(width: 10),
          _buildStatItem(
            Icons.shopping_cart, 
            'Commandes', 
            stats['nb_commandes'].toString(), 
            Colors.green
          ),
          const SizedBox(width: 10),
          _buildStatItem(
            Icons.local_offer, 
            'Promotions', 
            stats['nb_promotions'].toString(), 
            Colors.orange
          )
        ],
      );
  }

  Widget _buildLoadingStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatItem(Icons.people, 'Utilisateurs', '...', Colors.blue),
          const SizedBox(width: 16),
          _buildStatItem(Icons.shopping_cart, 'Commandes', '...', Colors.green),
          const SizedBox(width: 16),
          _buildStatItem(Icons.local_offer, 'Promotions', '...', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.red[700]),
              onPressed: () {
                _fetchStats();
                _loadUnreadCount();
              },
              tooltip: 'Réessayer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String value, Color color) {
    return Container(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDashboardGrid(BuildContext context) {
    final List<DashboardItem> items = [
      DashboardItem(
        title: 'Gestion des Utilisateurs',
        icon: Icons.people,
        color: Colors.purple,
        route: '/admin/users',
        description: 'Gérer les comptes utilisateurs et les rôles',
      ),
      DashboardItem(
        title: 'Gestion des Produits',
        icon: Icons.shopping_bag,
        color: Colors.green,
        route: '/admin/produits',
        description: 'Ajouter, modifier et supprimer des produits',
      ),
      DashboardItem(
        title: 'Gestion des Catégories',
        icon: Icons.category,
        color: Colors.blue,
        route: '/admin/categories',
        description: 'Organiser les catégories de produits',
      ),
      DashboardItem(
        title: 'Gestion des Promotions',
        icon: Icons.local_offer,
        color: Colors.orange,
        route: '/admin/promotions',
        description: 'Créer et gérer les promotions',
      ),
      DashboardItem(
        title: 'Gestion des Commandes',
        icon: Icons.list_alt,
        color: Colors.red,
        route: '/admin/commandes',
        description: 'Suivre et traiter les commandes',
      ),
      DashboardItem(
        title: 'Messages Contact',
        icon: Icons.contact_mail,
        color: Colors.teal,
        route: '/admin/contact',
        description: 'Suivre et traiter les contacts',
      )
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildDashboardCard(context, items[index]);
        },
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, DashboardItem item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, item.route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.color.withOpacity(0.1),
                item.color.withOpacity(0.05),
              ],
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      item.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Badge pour les notifications non lues
              if (item.badgeCount != null && item.badgeCount! > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      item.badgeCount! > 9 ? '9+' : item.badgeCount!.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String description;
  final int? badgeCount;

  DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    required this.description,
    this.badgeCount,
  });
}