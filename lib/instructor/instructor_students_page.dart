import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'instructor_student_preview_page.dart';
import '../services/instructor_students_provider.dart';
import '../services/auth_service.dart';

class InstructorStudentsPage extends StatefulWidget {
  @override
  _InstructorStudentsPageState createState() => _InstructorStudentsPageState();
}

class _InstructorStudentsPageState extends State<InstructorStudentsPage> {
  @override
  void initState() {
    super.initState();
    // Загружаем учеников и подписываемся на LiveQuery при инициализации страницы
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<InstructorStudentsProvider>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final instructorId = auth.currentUser?.objectId;
      
      if (instructorId != null) {
        print('🔵 [InstructorStudentsPage] Инициализация LiveQuery для инструктора: $instructorId');
        // Инициализируем LiveQuery подписку для автоматического обновления
        await provider.initializeLiveQuery(instructorId);
      } else if (provider.students.isEmpty) {
        // Если нет ID инструктора, просто загружаем список
        await provider.loadStudents();
      }
    });
  }

  Future<void> _detachStudent(Map<String, dynamic> student, InstructorStudentsProvider provider) async {
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

    setState(() {}); // Trigger loading state via provider
    try {
      final function = ParseCloudFunction('detachStudent');
      final response = await function.execute(parameters: {'studentId': student['id']});

      if (!response.success) {
        throw Exception(response.error?.message ?? 'Неизвестная ошибка');
      }

      print('✅ Облачная функция detachStudent выполнена успешно');

      final query = QueryBuilder<ParseObject>(ParseObject('_User'))
        ..whereEqualTo('objectId', student['id']);
      final queryResponse = await query.query();
      
      if (queryResponse.success && queryResponse.results != null && queryResponse.results!.isNotEmpty) {
        final studentObject = queryResponse.results!.first;
        studentObject.set('instructorId', null);
        final saveResponse = await studentObject.save();
        
        if (!saveResponse.success) {
          print('⚠️ Не удалось очистить instructorId: ${saveResponse.error?.message}');
          throw Exception('Не удалось обновить данные ученика: ${saveResponse.error?.message}');
        } else {
          print('✅ instructorId успешно очищен у студента ${student['id']}');
        }
      } else {
        print('⚠️ Не удалось найти студента для обновления: ${student['id']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ученик "$studentName" откреплён')),
      );
      // LiveQuery автоматически обновит список при изменении данных
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InstructorStudentsProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue, Colors.lightBlueAccent],
            ),
          ),
          child: SafeArea(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : provider.error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ошибка: ${provider.error}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => provider.loadStudents(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
                : provider.students.isEmpty
                ? const Center(
              child: Text(
                'У вас пока нет учеников',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.students.length,
              itemBuilder: (ctx, index) {
                final student = provider.students[index];
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
                    onLongPress: () => _detachStudent(student, provider),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}