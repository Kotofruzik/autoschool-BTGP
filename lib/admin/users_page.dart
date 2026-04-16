import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autoschool_btgp/services/users_provider.dart';
import '../services/auth_service.dart';
import 'user_preview_page.dart';
import 'add_user_page.dart';

class UsersPage extends StatefulWidget {
  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String? _selectedRoleFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  void _loadUsers() {
    final provider = Provider.of<UsersProvider>(context, listen: false);
    provider.loadUsers(
      roleFilter: _selectedRoleFilter,
      searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      useCloud: true,
    );
  }

  void _applyFilters() {
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = Provider.of<UsersProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.objectId;

    final filteredUsers = usersProvider.users.where((u) => u.objectId != currentUserId).toList();

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Поле поиска (расширяемое)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Поиск..',
                                filled: true,
                                fillColor: Colors.transparent,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.search),
                                prefixIconConstraints: const BoxConstraints(
                                  minHeight: 32,
                                ),
                                contentPadding: const EdgeInsets.fromLTRB(24, 12, 16, 12), // ← Левый отступ 24
                                isDense: true,
                              ),
                              onChanged: (_) => _applyFilters(),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),
                        // Выпадающий список для фильтра по роли
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedRoleFilter,
                            hint: const Text('Все'),
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Все')),
                              DropdownMenuItem(value: 'student', child: Text('Ученики')),
                              DropdownMenuItem(value: 'instructor', child: Text('Инструкторы')),
                              DropdownMenuItem(value: 'admin', child: Text('Админы')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRoleFilter = value;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Кнопка добавления пользователя
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddUserPage()),
                            );
                          },
                          child: const Icon(Icons.person_add, color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Список пользователей
              Expanded(
                child: usersProvider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : usersProvider.error != null
                    ? Center(child: Text('Ошибка: ${usersProvider.error}', style: const TextStyle(color: Colors.white)))
                    : filteredUsers.isEmpty
                    ? const Center(child: Text('Нет пользователей', style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (ctx, index) {
                    final user = filteredUsers[index];
                    final photoUrl = user.get('photo') as String?;
                    final surname = user.get('surname') ?? '';
                    final firstname = user.get('firstname') ?? '';
                    final fullName = '$surname $firstname'.trim();
                    final email = user.get('email') ?? '';
                    final role = user.get('role') ?? 'student';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                          child: photoUrl == null
                              ? Text(
                            fullName.isNotEmpty ? fullName[0] : '?',
                            style: const TextStyle(color: Colors.blue),
                          )
                              : null,
                        ),
                        title: Text(fullName.isNotEmpty ? fullName : email),
                        subtitle: Text(email),
                        trailing: Chip(
                          label: Text(_getRoleName(role)),
                          backgroundColor: Colors.blue.shade50,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserPreviewPage(user: user),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'student':
        return 'Ученик';
      case 'instructor':
        return 'Инструктор';
      case 'admin':
        return 'Админ';
      default:
        return role;
    }
  }
}