import 'package:flutter/material.dart';
import './../../fetch/notification_api.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _stats = {};

  int _currentPage = 1;
  final int _itemsPerPage = 20;
  bool _hasMore = true;
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadStats();
  }

  Future<void> _loadNotifications() async {
  try {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final response = await NotificationService.getNotifications(
      page: _currentPage,
      limit: _itemsPerPage,
      type: _currentFilter,
    );

    if (response['success'] == true) {
      final List<dynamic> newNotifications = response['data'];

      setState(() {
        if (_currentPage == 1) {
          _notifications = newNotifications;
        } else {
          _notifications.addAll(newNotifications);
        }
        
        _hasMore = newNotifications.length == _itemsPerPage;
        _isLoading = false;
      });
    } else {
      throw Exception('Erreur lors du chargement des notifications');
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = e.toString();
    });
  }
}

void _showDeleteConfirmationDialog(String notificationId, String notificationTitle) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Confirmer la suppression"),
      content: Text(
        "Voulez-vous vraiment supprimer la notification \"$notificationTitle\" ?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Fermer le dialogue de confirmation
            _deleteNotification(notificationId);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text("Supprimer"),
        ),
      ],
    ),
  );
}

  Future<void> _loadStats() async {
    try {
      final response = await NotificationService.getNotificationStats();
      if (response['success'] == true) {
        setState(() {
          _stats = response['data'];
        });
      }
    } catch (e) {
      print('Erreur chargement stats: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      
      // Mettre à jour localement
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'].toString() == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });

      // Recharger les stats
      _loadStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification marquée comme lue')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      
      // Mettre à jour toutes les notifications localement
      setState(() {
        for (var notification in _notifications) {
          notification['isRead'] = true;
        }
      });

      // Recharger les stats
      _loadStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toutes les notifications marquées comme lues')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await NotificationService.deleteNotification(notificationId);
      
      // Supprimer localement
      setState(() {
        _notifications.removeWhere((n) => n['id'].toString() == notificationId);
      });

      // Recharger les stats
      _loadStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification supprimée')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _loadMore() {
    if (!_isLoading && _hasMore) {
      setState(() {
        _currentPage++;
      });
      _loadNotifications();
    }
  }

  void _refresh() {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
    });
    _loadNotifications();
    _loadStats();
  }

  void _changeFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _currentPage = 1;
      _hasMore = true;
    });
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_stats.isNotEmpty && (_stats['unread'] ?? 0) > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Tout marquer comme lu',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filtres
        _buildFilterChips(),
        
        // Statistiques
        if (_stats.isNotEmpty) _buildStatsCard(),
        
        // Liste des notifications
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              itemCount: _notifications.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _notifications.length) {
                  return _buildLoadMoreIndicator();
                }
                
                final notification = _notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'all', 'label': 'Toutes'},
      {'value': 'low_stock', 'label': 'Stock faible'},
      {'value': 'new_order', 'label': 'Nouvelles commandes'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _currentFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (_) => _changeFilter(filter['value']!),
              backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', _stats['total']?.toString() ?? '0', Icons.notifications),
            _buildStatItem('Non lues', _stats['unread']?.toString() ?? '0', Icons.markunread),
            _buildStatItem('Stock faible', _stats['lowStockCount']?.toString() ?? '0', Icons.inventory_2),
            _buildStatItem('Commandes', _stats['newOrderCount']?.toString() ?? '0', Icons.shopping_cart),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final createdAt = notification['createdAt'] ?? '';
    final notificationId = notification['id'].toString();

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirmer la suppression"),
              content: const Text("Voulez-vous vraiment supprimer cette notification ?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Annuler"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Supprimer"),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteNotification(notificationId);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isRead ? Colors.white : Colors.blue[50],
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(NotificationHelpers.getColor(type)).withOpacity(0.2),
            child: Text(
              NotificationHelpers.getIcon(type),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 4),
              Text(
                '${NotificationHelpers.getTypeText(type)} • ${NotificationHelpers.formatDate(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          trailing: !isRead
              ? IconButton(
                  icon: const Icon(Icons.mark_email_read, color: Colors.blue),
                  onPressed: () => _markAsRead(notificationId),
                  tooltip: 'Marquer comme lu',
                )
              : null,
          onTap: () {
            if (!isRead) {
              _markAsRead(notificationId);
            }
            _showNotificationDetails(notification);
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _hasMore
                ? ElevatedButton(
                    onPressed: _loadMore,
                    child: const Text('Charger plus'),
                  )
                : const Text(
                    'Toutes les notifications sont chargées',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
      ),
    );
  }

 void _showNotificationDetails(Map<String, dynamic> notification) {
  final type = notification['type'] ?? '';
  final title = notification['title'] ?? '';
  final message = notification['message'] ?? '';
  final createdAt = notification['createdAt'] ?? '';
  final updatedAt = notification['updatedAt'] ?? '';
  final isRead = notification['isRead'] ?? false;
  final priority = notification['priority'] ?? 'medium';
  final notificationId = notification['id'].toString();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(title),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteConfirmationDialog(notificationId, title);
            },
            tooltip: 'Supprimer',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(NotificationHelpers.getColor(type)).withOpacity(0.2),
                  child: Text(
                    NotificationHelpers.getIcon(type),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  NotificationHelpers.getTypeText(type),
                  style: TextStyle(
                    color: Color(NotificationHelpers.getColor(type)),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Informations
            const Text(
              'Informations:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDetailItem('Statut', isRead ? 'Lu' : 'Non lu'),
            _buildDetailItem('Priorité', priority),
            _buildDetailItem('Créée le', NotificationHelpers.formatDate(createdAt)),
            _buildDetailItem('Modifiée le', NotificationHelpers.formatDate(updatedAt)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

