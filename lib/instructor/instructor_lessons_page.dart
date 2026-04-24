import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import '../services/lesson_service.dart';
import 'package:autoschool_btgp/lesson/lesson_model.dart';
import 'package:autoschool_btgp/lesson/lesson_detail_page.dart';
import 'package:autoschool_btgp/lesson/circular_lesson_timer.dart';
import 'calendar_schedule_page.dart';

class InstructorLessonsPage extends StatefulWidget {
  @override
  _InstructorLessonsPageState createState() => _InstructorLessonsPageState();
}

class _InstructorLessonsPageState extends State<InstructorLessonsPage> {
  List<Lesson> _upcoming = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
    if (instructor == null) return;

    final lessonService = LessonService();
    try {
      final objects = await lessonService.getLessonsForInstructor(instructor);
      final all = objects.map((obj) => Lesson.fromParse(obj)).toList();
      // Обновляем статус завершённых занятий
      for (final lesson in all) {
        if (lesson.isPast && lesson.status != 'completed' && lesson.status != 'cancelled') {
          final updatedLesson = lesson.toParse();
          updatedLesson.set('status', 'completed');
          await updatedLesson.save();
        }
      }
      // Перезагружаем после обновления статусов
      final updatedObjects = await lessonService.getLessonsForInstructor(instructor);
      final updatedAll = updatedObjects.map((obj) => Lesson.fromParse(obj)).toList();
      setState(() {
        _upcoming = updatedAll.where((l) => !l.isPast && l.status != 'cancelled').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Lesson? get _currentLesson {
    for (var l in _upcoming) {
      if (l.isOngoing) return l;
    }
    return null;
  }

  Lesson? get _nextLesson {
    final future = _upcoming.where((l) => !l.isOngoing).toList();
    if (future.isEmpty) return null;
    return future.reduce((a, b) => a.startTime.isBefore(b.startTime) ? a : b);
  }

  List<Lesson> get _otherLessons {
    final future = _upcoming.where((l) => l != _currentLesson && l != _nextLesson).toList();
    future.sort((a, b) => a.startTime.compareTo(b.startTime));
    return future;
  }

  Future<void> _cancelLesson(Lesson lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отмена занятия'),
        content: const Text('Вы уверены, что хотите отменить это занятие?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да, отменить')),
        ],
      ),
    );
    if (confirm == true) {
      final lessonService = LessonService();
      try {
        await lessonService.cancelLesson(lesson.toParse());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Занятие отменено'), backgroundColor: Colors.green),
        );
        _loadLessons();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final current = _currentLesson;
    final next = _nextLesson;
    final others = _otherLessons;
    final hasAnyLesson = current != null || next != null || others.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Занятия'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CalendarSchedulePage(isInstructor: true)),
              );
            },
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
          child: SizedBox.expand(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: hasAnyLesson ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  if (current != null) ...[
                    const SizedBox(height: 16),
                    _buildCurrentLessonCard(current),
                  ],
                  if (next != null) ...[
                    const SizedBox(height: 16),
                    _buildNextLessonCard(next),
                  ],
                  if (others.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Другие занятия',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    ...others.map((lesson) => _buildOtherLessonCard(lesson)),
                  ],
                  if (!hasAnyLesson) ...[
                    const Center(
                      child: Text(
                        'Нет предстоящих занятий',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLessonCard(Lesson lesson) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green.shade700,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
          );
          _loadLessons();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Сейчас идёт',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              CircularLessonTimer(
                lesson: lesson,
                size: 300, // Очень крупный размер для инструктора
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
                  );
                  _loadLessons();
                },
              ),
              const SizedBox(height: 16),
              Text(
                lesson.displayType,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                lesson.displayDateTimeRange,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
                  );
                  _loadLessons();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green),
                child: const Text('Подробнее'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextLessonCard(Lesson lesson) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade700,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
          );
          _loadLessons();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Ближайшее занятие',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              CircularLessonTimer(
                lesson: lesson,
                size: 300, // Очень крупный размер для инструктора
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
                  );
                  _loadLessons();
                },
              ),
              const SizedBox(height: 16),
              Text(
                lesson.displayType,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                lesson.displayDateTimeRange,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
                  );
                  _loadLessons();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                child: const Text('Подробнее'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherLessonCard(Lesson lesson) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            lesson.type == 'driving' ? Icons.directions_car : Icons.assignment,
            color: Colors.blue,
          ),
        ),
        title: Text(lesson.displayType),
        subtitle: Text('${lesson.displayDateTimeRange} • ${lesson.countdownShort}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _cancelLesson(lesson),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: true)),
          );
          _loadLessons();
        },
      ),
    );
  }
}