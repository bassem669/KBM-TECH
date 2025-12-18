import 'package:flutter/material.dart';
import './pages/login_page.dart';
import './pages/register_page.dart';
import './pages/profil_page.dart';
import './pages/contact_page.dart';
import './pages/accueil_page.dart';
import './pages/produit_detail_page.dart';
import './pages/panier_page.dart';
import './pages/recherche_page.dart';
import './pages/mesCommande_page.dart';
import './pages/liste_souhait_page.dart';

// Pages admin
import './pages/adminDashbord.dart';
import './pages/admin/utilisateurs_page.dart';
import './pages/admin/destionCategories.dart';
import './pages/admin/gestinPromotion.dart';
import './pages/admin/admin_produit_page.dart';
import './pages/admin/contact_page.dart';
import './pages/admin/commande_page.dart';
import './pages/admin/notifications_page.dart';
import './pages/simple_selection_page.dart';
// Nouvelles pages pour la réinitialisation de mot de passe
import './pages/forgot_password_screen.dart';

class AppRoutes {
  // 🔹 Routes statiques de l'application
  static Map<String, WidgetBuilder> getAllRoutes() {
    return {
      // Routes utilisateur
      '/': (context) => const AccueilPage(),
      '/login': (context) => const LoginPage(),
      '/register': (context) => const RegisterPage(),
      '/profil': (context) => const UserProfilePage(),
      '/contact': (context) => const ContactPage(),
      '/panier': (context) => CartScreen(),
      '/recherche': (context) => const RecherchePage(),
      '/mesCommande': (context) => const MesCommandesPage(),
      '/listeSouhait': (context) => const WishlistPage(),
      '/forgot-password': (context) => const ForgotPasswordPage(),
      '/simple-selection': (context) => const DynamicSelectionPage(),
      // Routes admin
      '/admin': (context) => const AdminDashboard(),
      '/admin/users': (context) => const UtilisateursPage(),
      '/admin/categories': (context) => const CategoriesPage(),
      '/admin/promotions': (context) => const PromotionsPage(),
      '/admin/produits': (context) => AdminProduitPage(),
      '/admin/contact': (context) => const ContactsPage(),
      '/admin/commandes': (context) => const CommandesPage(),
      '/admin/notifications': (context) => const NotificationsPage(),
    };
  }

  // 🔹 Gestion dynamique des routes (ex: avec arguments)
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // Route pour les détails des produits
    if (settings.name == '/produit') {
      final produit = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => ProduitDetailPage(produit: produit),
      );
    }


    // 🔸 Route par défaut si non trouvée
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Page non trouvée')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Page non trouvée',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/'),
                child: const Text("Retour à l'accueil"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}