import 'package:flutter/material.dart';
import '../fetch/auth_api.dart'; // Import de votre API d'authentification
import 'mesCommande_page.dart'; // Import de votre page MesCommandesPage

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  String? firstName;
  String? lastName;
  String? email;
  String? phone;
  String? address;
  String? role;
  int? nbCommandes;
  String? memberSince;

  bool isEditing = false;
  bool isLoading = true;
  bool isChangingPassword = false;

  // Variables pour la visibilité des mots de passe
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Contrôleurs pour les informations personnelles
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController addressController = TextEditingController();

  // Contrôleurs pour le changement de mot de passe
  TextEditingController currentPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _goToMesCommandes() {
    Navigator.pushNamed(
      context,
      "/mesCommande"
    );
  }

  /// 🟢 Charger le profil de l'utilisateur connecté
  Future<void> _loadUserProfile() async {
    final token = await AuthAPI.getToken();

    print("🟢 Token lu depuis AuthAPI: $token");

    if (token == null || token.isEmpty) {
      // ⚠️ Si pas de token → retour à la page de connexion
      if (mounted) {
        Future.delayed(Duration.zero, () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
      return;
    }

    try {
      final userData = await AuthAPI.fetchUserProfile(token);
      if (userData != null) {
        setState(() {
          firstName = userData['prenom'];
          lastName = userData['nom'];
          email = userData['email'];
          phone = userData['tel'] ?? '';
          address = userData['adresse'] ?? '';
          role = userData['role'] ?? 'client';
          nbCommandes = userData['nb_commande'] ?? 0;
          memberSince = _getMemberSince(userData['createdAt'] ?? '2025');
          
          firstNameController.text = firstName ?? '';
          lastNameController.text = lastName ?? '';
          emailController.text = email ?? '';
          phoneController.text = phone ?? '';
          addressController.text = address ?? '';
          isLoading = false;
        });
      } else {
        throw Exception('Erreur de chargement du profil');
      }
    } catch (e) {
      print("❌ Erreur: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement du profil ❌')),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// 🔵 Mettre à jour le profil
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await AuthAPI.getToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expirée, veuillez vous reconnecter ❌')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final updateData = {
        'prenom': firstNameController.text,
        'nom': lastNameController.text,
        'email': emailController.text,
        'tel': phoneController.text,
        'adresse': addressController.text,
      };

      final erreur = await AuthAPI.updateUserProfile(updateData, token);

      if (erreur.isEmpty) {
        setState(() {
          isEditing = false;
          firstName = firstNameController.text;
          lastName = lastNameController.text;
          email = emailController.text;
          phone = phoneController.text;
          address = addressController.text;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès ✅')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erreur)),
        );
      }
    } catch (e) {
      print("❌ Erreur mise à jour: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la mise à jour ❌')),
      );
    }
  }

  /// 🔐 Mettre à jour le mot de passe
  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final token = await AuthAPI.getToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expirée, veuillez vous reconnecter ❌')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final passwordData = {
        'currentPassword': currentPasswordController.text,
        'newPassword': newPasswordController.text,
        'confirmPassword': confirmPasswordController.text,
      };

      // Appel à l'API pour mettre à jour le mot de passe
      final result = await AuthAPI.updatePassword(passwordData, token);

      if (result['success']) {
        // Réinitialiser les champs
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();
        
        setState(() {
          isChangingPassword = false;
          // Réinitialiser aussi la visibilité
          _showCurrentPassword = false;
          _showNewPassword = false;
          _showConfirmPassword = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour avec succès ✅')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur lors de la mise à jour du mot de passe')),
        );
      }
    } catch (e) {
      print("❌ Erreur mise à jour mot de passe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la mise à jour du mot de passe ❌')),
      );
    }
  }

  /// 🟠 Déconnexion
  Future<void> _logout() async {
    await AuthAPI.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  /// 🔴 Accéder au dashboard admin
  void _goToAdminDashboard() {
    Navigator.pushNamed(context, '/admin');
  }

  /// 🟣 Calculer la date d'inscription
  String _getMemberSince(String createdAt) {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.year}';
    } catch (e) {
      return '2025';
    }
  }

  /// 🟤 Obtenir le texte du rôle
  String _getRoleText() {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Administrateur';
      case 'client':
        return 'Client';
      default:
        return 'Utilisateur';
    }
  }

  /// 🟠 Obtenir la couleur du rôle
  Color _getRoleColor() {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'client':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Vérifier si l'utilisateur est admin
  bool get _isAdmin => role?.toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Mon Profil",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushNamed(context, "/"),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.blueAccent),
            onPressed: _goToMesCommandes,
          ),
          if (!isEditing && !isChangingPassword)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _logout,
            ),
          IconButton(
            icon: Icon(
              isEditing ? Icons.check : Icons.edit,
              color: Colors.blueAccent,
            ),
            onPressed: () {
              if (isEditing) {
                _updateProfile();
              } else if (!isChangingPassword) {
                setState(() => isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- USER CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar avec badge de rôle
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _isAdmin ? Colors.red : Colors.blueAccent,
                        child: Icon(
                          _isAdmin ? Icons.admin_panel_settings : Icons.person, 
                          size: 50, 
                          color: Colors.white
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRoleColor(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRoleText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "$firstName $lastName",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email ?? "",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  
                  // Informations du profil
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.blueAccent, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        "Membre depuis $memberSince",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Nombre de commandes (uniquement pour les clients)
                  if (role == 'client')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 5),
                        Text(
                          "$nbCommandes commande${nbCommandes != 1 ? 's' : ''}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- BOUTON ADMIN (uniquement pour les administrateurs) ---
            if (_isAdmin) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: _goToAdminDashboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.dashboard, size: 24),
                  label: const Text(
                    "Dashboard Administrateur",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // --- BOUTON CHANGEMENT DE MOT DE PASSE ---
            if (!isChangingPassword && !isEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isChangingPassword = true;
                      isEditing = false;
                      // Réinitialiser la visibilité des mots de passe
                      _showCurrentPassword = false;
                      _showNewPassword = false;
                      _showConfirmPassword = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock),
                  label: const Text(
                    "Changer le mot de passe",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // --- FORMULAIRE DE CHANGEMENT DE MOT DE PASSE ---
            if (isChangingPassword) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Changer le mot de passe",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                isChangingPassword = false;
                                currentPasswordController.clear();
                                newPasswordController.clear();
                                confirmPasswordController.clear();
                                // Réinitialiser la visibilité
                                _showCurrentPassword = false;
                                _showNewPassword = false;
                                _showConfirmPassword = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- MOT DE PASSE ACTUEL AVEC ŒIL ---
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: !_showCurrentPassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                          labelText: "Mot de passe actuel",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showCurrentPassword = !_showCurrentPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le mot de passe actuel est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // --- NOUVEAU MOT DE PASSE AVEC ŒIL ---
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !_showNewPassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                          labelText: "Nouveau mot de passe",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNewPassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showNewPassword = !_showNewPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nouveau mot de passe est obligatoire';
                          }
                          if (value.length < 6) {
                            return 'Le mot de passe doit contenir au moins 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // --- CONFIRMATION MOT DE PASSE AVEC ŒIL ---
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_reset, color: Colors.grey),
                          labelText: "Confirmer le nouveau mot de passe",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La confirmation du mot de passe est obligatoire';
                          }
                          if (value != newPasswordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Mettre à jour",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isChangingPassword = false;
                                  currentPasswordController.clear();
                                  newPasswordController.clear();
                                  confirmPasswordController.clear();
                                  // Réinitialiser la visibilité
                                  _showCurrentPassword = false;
                                  _showNewPassword = false;
                                  _showConfirmPassword = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Annuler",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // --- PERSONAL INFO ---
            if (!isChangingPassword)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Informations personnelles",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(Icons.person, "Prénom",
                          firstNameController, isEditing, TextInputType.text),
                      const SizedBox(height: 15),

                      _buildTextField(Icons.person, "Nom",
                          lastNameController, isEditing, TextInputType.text),
                      const SizedBox(height: 15),

                      _buildTextField(Icons.email, "Adresse e-mail",
                          emailController, isEditing, TextInputType.emailAddress),
                      const SizedBox(height: 15),

                      _buildTextField(Icons.phone, "Téléphone",
                          phoneController, isEditing, TextInputType.phone),
                      const SizedBox(height: 15),

                      _buildTextField(Icons.home, "Adresse",
                          addressController, isEditing, TextInputType.streetAddress),
                      
                      // Champ rôle (non éditable)
                      const SizedBox(height: 15),
                      TextFormField(
                        enabled: false,
                        initialValue: _getRoleText(),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            _isAdmin ? Icons.admin_panel_settings : Icons.security, 
                            color: Colors.grey
                          ),
                          labelText: "Rôle",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // --- BOUTON DÉCONNEXION ---
            if (!isEditing && !isChangingPassword) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    "Se déconnecter",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    IconData icon,
    String label,
    TextEditingController controller,
    bool editable,
    TextInputType keyboardType,
  ) {
    return TextFormField(
      controller: controller,
      enabled: editable,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Le champ $label est obligatoire";
        }
        
        // Validation spécifique pour l'email
        if (label.toLowerCase().contains('email')) {
          final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
          if (!emailRegex.hasMatch(value)) {
            return "Veuillez saisir un email valide";
          }
        }
        
        // Validation spécifique pour le téléphone
        if (label.toLowerCase().contains('téléphone') && value.length < 8) {
          return "Le numéro doit contenir au moins 8 chiffres";
        }
        
        return null;
      },
    );
  }

  @override
  void dispose() {
    // Nettoyer tous les contrôleurs
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}