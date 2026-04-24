import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InstructorStudentsPage extends StatefulWidget {
  const InstructorStudentsPage({Key? key}) : super(key: key);

  @override
  State<InstructorStudentsPage> createState() => _InstructorStudentsPageState();
}

class _InstructorStudentsPageState extends State<InstructorStudentsPage> {
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ParseCloudFunction('getMyStudents').execute();

      if (response.success && response.result != null) {
        setState(() {
          _students = List<dynamic>.from(response.result);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки: ${response.error?.message ?? "Неизвестная ошибка"}')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _detachStudent(String studentId) async {
    // Показываем диалог подтверждения
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Открепить ученика?'),
        content: const Text(
          'Это удалит все будущие занятия с этим учеником и открепит его от вас.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Открепить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Вызываем облачную функцию detachStudent
      // Параметры передаются ВНУТРЬ метода execute()
      final response = await ParseCloudFunction('detachStudent')
          .execute({'studentId': studentId});

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ученик успешно откреплен')),
          );
          // Перезагружаем список
          _loadStudents();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${response.error?.message ?? "Не удалось открепить"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои ученики'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
          ? const Center(child: Text('У вас пока нет учеников'))
          : ListView.builder(
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          final fullName = '${student['surname'] ?? ''} ${student['firstname'] ?? ''} ${student['patronymic'] ?? ''}'.trim();
          final photoUrl = student['photo'];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              onLongPress: () => _detachStudent(student['id']),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Icon(Icons.person, color: Colors.grey[600])
                    : null,
              ),
              title: Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(student['email'] ?? ''),
              isThreeLine: true,
              trailing: const Icon(Icons.more_vert),
            ),
          );
        },
      ),
    );
  }
}