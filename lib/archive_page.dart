import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import '../services/lesson_service.dart';
import 'package:autoschool_btgp/lesson/lesson_model.dart';
import 'package:autoschool_btgp/lesson/lesson_detail_page.dart';

class ArchivePage extends StatefulWidget {
  @override
  _ArchivePageState createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Lesson> _archive = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final lessonService = LessonService();
    try {
      // Определяем роль пользователя (можно передавать извне, но для простоты определим по роли)
      final isInstructor = user.get('role') == 'instructor';
      final objects = isInstructor
          ? await lessonService.getLessonsForInstructor(user)
          : await lessonService.getLessonsForStudent(user);
      final all = objects.map((obj) => Lesson.fromParse(obj)).toList();
      setState(() {
        _archive = all.where((l) => l.isPast || l.status == 'cancelled').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив занятий'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _archive.isEmpty
            ? const Center(child: Text('Нет завершённых занятий', style: TextStyle(color: Colors.white)))
            : ListView.builder(
          itemCount: _archive.length,
          itemBuilder: (ctx, index) {
            final lesson = _archive[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    lesson.type == 'driving' ? Icons.directions_car : Icons.assignment,
                    color: Colors.grey,
                  ),
                ),
                title: Text(lesson.displayType),
                subtitle: Text('${lesson.displayDateTimeRange} • ${lesson.displayStatus}'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: false)),
                  );
                  _loadArchive(); // обновляем после возврата
                },
              ),
            );
          },
        ),
      ),
    );
  }
}