import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/users_provider.dart';

class UserPreviewPage extends StatefulWidget {
  final ParseUser user;
  const UserPreviewPage({Key? key, required this.user}) : super(key: key);

  @override
  _UserPreviewPageState createState() => _UserPreviewPageState();
}

class _UserPreviewPageState extends State<UserPreviewPage> {
  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user.get('firstname') ?? '';
    final lastName = user.get('surname') ?? '';
    final email = user.get('email') ?? '';
    final phone = user.get('phone') ?? 'Не указан';
    final role = user.get('role') ?? 'student';
    final photoUrl = user.get('photo') as String?;

    String formattedDate = 'неизвестно';
    if (user.createdAt != null) {
      formattedDate = '${user.createdAt!.day}.${user.createdAt!.month}.${user.createdAt!.year}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Просмотр профиля'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'change_role') {
                _showChangeRoleDialog();
              } else if (value == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'change_role', child: Text('Сменить роль')),
              const PopupMenuItem(value: 'delete', child: Text('Удалить пользователя')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: SafeArea(
          bottom: false, // 👈 убираем нижний отступ, чтобы градиент дошёл до низа
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                    (firstName.isNotEmpty ? firstName[0] : '?').toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.blue),
                  )
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  lastName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  firstName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      phone,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Chip(
                  label: Text(_getRoleName(role)),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Дата регистрации: $formattedDate',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeRoleDialog() {
    final provider = Provider.of<UsersProvider>(context, listen: false);
    String? selectedRole = widget.user.get('role') ?? 'student';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена роли'),
        content: DropdownButtonFormField<String>(
          value: selectedRole,
          items: const [
            DropdownMenuItem(value: 'student', child: Text('Ученик')),
            DropdownMenuItem(value: 'instructor', child: Text('Инструктор')),
            DropdownMenuItem(value: 'admin', child: Text('Администратор')),
          ],
          onChanged: (value) => selectedRole = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.updateUserRoleViaCloud(widget.user.objectId!, selectedRole!);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Роль обновлена')),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? 'Ошибка')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление пользователя'),
        content: const Text('Вы уверены? Это действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<UsersProvider>(context, listen: false);
              final success = await provider.deleteUserViaCloud(widget.user.objectId!);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пользователь удалён')),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error ?? 'Ошибка удаления')),
                );
              }
            },
            child: const Text('Удалить'),
          ),
        ],
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