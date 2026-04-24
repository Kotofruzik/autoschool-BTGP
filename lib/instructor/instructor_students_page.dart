import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'instructor_student_preview_page.dart';

class InstructorStudentsPage extends StatefulWidget {
  @override
  _InstructorStudentsPageState createState() => _InstructorStudentsPageState();
}

class _InstructorStudentsPageState extends State<InstructorStudentsPage> {
  List<ParseUser> _students = [];
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
        final List<dynamic> results = response.result as List<dynamic>;
        final List<ParseUser> students = results.map((json) {
          final user = ParseUser(null, null, null);
          user.objectId = json['id'];
          user.set('surname', json['surname']);
          user.set('firstname', json['firstname']);
          user.set('patronymic', json['patronymic']);
          user.set('email', json['email']);
          user.set('phone', json['phone']);
          user.set('photo', json['photo']);
          return user;
        }).toList();

        setState(() {
          _students = students;
        });
      } else {
        setState(() {
          _error = response.error?.message ?? 'Ошибка загрузки';
        });
      }
    } catch (e) {
      setState(() {
        _error = (e).toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _detachStudent(ParseUser student) async {
    final studentName = '${student.get('surname') ?? ''} ${student.get('firstname') ?? ''}'.trim();
    
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

    try {
      // Получаем текущего инструктора
      final instructor = await ParseUser.currentUser() as ParseUser?;
      if (instructor == null || instructor.objectId == null) {
        throw Exception('Инструктор не авторизован');
      }

      // Отправляем уведомление инструктору об откреплении
      await LessonService().notifyInstructorAboutDetach(
        instructorId: instructor.objectId!,
        studentName: studentName,
      );

      // Удаляем все будущие занятия с этим учеником
      final lessonService = LessonService();
      final lessons = await lessonService.getLessonsForInstructor(instructor);
      
      for (final lesson in lessons) {
        final lessonStudent = lesson.get('student');
        if (lessonStudent is Map && lessonStudent['objectId'] == student.objectId) {
          final startTime = lesson.get<DateTime>('startTime');
          // Удаляем только будущие занятия
          if (startTime.isAfter(DateTime.now())) {
            await lessonService.deleteLesson(lesson);
          }
        }
      }

      // Перезагружаем список студентов
      await _loadStudents();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ученик "$studentName" откреплён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при откреплении: $e')),
        );
      }
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
            final student = _students[index];
            final name = '${student.get('surname') ?? ''} ${student.get('firstname') ?? ''}'.trim();
            final photoUrl = student.get('photo') as String?;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                      : null,
                ),
                title: Text(name),
                subtitle: Text(student.get('email') ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstructorStudentPreviewPage(student: student),
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