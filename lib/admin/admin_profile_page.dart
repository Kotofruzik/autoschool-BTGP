import 'package:autoschool_btgp/services/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autoschool_btgp/services/auth_service.dart';

class AdminProfilePage extends StatefulWidget {
  @override
  _AdminProfilePageState createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  Future<void> _signOut() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление профиля'),
        content: const Text('Вы уверены? Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Функция удаления временно недоступна')),
      );
    }
  }

  void _editProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfilePage()));
  }

  String _getFullName() {
    final user = Provider.of<AuthService>(context).currentUser;
    if (user == null) return 'Без имени';
    String surname = user.get('surname') ?? '';
    String firstname = user.get('firstname') ?? '';
    List<String> parts = [surname, firstname].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    final username = user.get('username');
    if (username != null && username.isNotEmpty) {
      if (username.contains('@')) return username.split('@')[0];
      return username;
    }
    return 'Пользователь';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final photoUrl = user?.get('photo') as String?;
    final phone = user?.get('phone') as String? ?? 'Не указан';
    final email = user?.get('email') as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60.0, left: 24.0, right: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _editProfile,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            image: photoUrl != null
                                ? DecorationImage(
                              image: CachedNetworkImageProvider(photoUrl),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: photoUrl == null
                              ? const Icon(Icons.person, size: 60, color: Colors.blue)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _getFullName(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 28),
                  onPressed: _editProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
