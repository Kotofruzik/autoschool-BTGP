import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'instructor_student_preview_page.dart';

class InstructorStudentsPage extends StatefulWidget {
  @override
  _InstructorStudentsPageState createState() => _InstructorStudentsPageState();
}

class _InstructorStudentsPageState extends State<InstructorStudentsPage> {
  List<dynamic> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final function = ParseCloudFunction('getMyStudents');
      final response = await function.execute(parameters: {});

      if (response.success && response.result != null) {
        setState(() {
          _students = List<dynamic>.from(response.result);
        });
      } else {
        setState(() {
          _error = response.error?.message ?? 'Ошибка загрузки';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _detachStudent(Map<String, dynamic> student) async {
    final studentName = '${student['firstname'] ?? ''} ${student['surname'] ?? ''}'.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открепить ученика?'),
        content: Text('Вы уверены, что хотите открепить ученика "$studentName"? Все будущие занятия с ним будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Открепить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Сначала вызываем облачную функцию для удаления занятий
      final function = ParseCloudFunction('detachStudent');
      final response = await function.execute(parameters: {'studentId': student['id']});

      if (!response.success) {
        throw Exception(response.error?.message ?? 'Неизвестная ошибка');
      }

      // Явно очищаем instructorId у студента через прямой запрос к серверу
      final studentObject = ParseObject('_User')
        ..objectId = student['id'];
      
      studentObject.set('instructorId', null);
      final saveResponse = await studentObject.save();
      
      if (!saveResponse.success) {
        print('⚠️ Не удалось очистить instructorId: ${saveResponse.error?.message}');
        throw Exception('Не удалось обновить данные ученика: ${saveResponse.error?.message}');
      } else {
        print('✅ instructorId успешно очищен у студента ${student['id']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ученик "$studentName" откреплён')),
      );
      await _loadStudents(); // обновляем список
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue, Colors.lightBlueAccent],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _error != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $_error', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadStudents,
                child: const Text('Повторить'),
              ),
            ],
          ),
        )
            : _students.isEmpty
            ? const Center(
          child: Text(
            'У вас пока нет учеников',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _students.length,
          itemBuilder: (ctx, index) {
            final student = _students[index] as Map<String, dynamic>;
            final name = '${student['firstname'] ?? ''} ${student['surname'] ?? ''}'.trim();
            final photoUrl = student['photo'] as String?;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  backgroundImage: photoUrl != null
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                      : null,
                ),
                title: Text(name.isNotEmpty ? name : 'Без имени'),
                subtitle: Text(student['email'] ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstructorStudentPreviewPage(studentData: student),
                    ),
                  );
                },
                onLongPress: () => _detachStudent(student),
              ),
            );
          },
        ),
      ),
    );
  }
}