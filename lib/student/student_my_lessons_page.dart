import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import '../services/lesson_service.dart';
import 'package:autoschool_btgp/lesson/lesson_model.dart';
import 'package:autoschool_btgp/lesson/lesson_detail_page.dart';

class StudentMyLessonsPage extends StatefulWidget {
  @override
  _StudentMyLessonsPageState createState() => _StudentMyLessonsPageState();
}

class _StudentMyLessonsPageState extends State<StudentMyLessonsPage> {
  List<Lesson> _upcoming = [];
  bool _isLoading = true;
  Timer? _timer;
  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _authService?.addListener(_onAuthChanged);
    _loadLessons();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() => _isLoading = true);
      _loadLessons();
    }
  }

  Future<void> _loadLessons() async {
    final student = _authService?.currentUser;
    if (student == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final lessonService = LessonService();
    try {
      final objects = await lessonService.getLessonsForStudent(student);
      final all = objects.map((obj) => Lesson.fromParse(obj)).toList();

      for (final lesson in all) {
        if (lesson.isPast && lesson.status != 'completed' && lesson.status != 'cancelled') {
          final updatedLesson = lesson.toParse();
          updatedLesson.set('status', 'completed');
          await updatedLesson.save();
        }
      }

      final updatedObjects = await lessonService.getLessonsForStudent(student);
      final updatedAll = updatedObjects.map((obj) => Lesson.fromParse(obj)).toList();
      final upcoming = updatedAll.where((l) => !l.isPast && l.status != 'cancelled').toList();

      if (mounted) {
        setState(() {
          _upcoming = upcoming;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.blue, // 🔧 Исправлено: был transparent
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final current = _currentLesson;
    final next = _nextLesson;
    final others = _otherLessons;
    final hasAnyLesson = current != null || next != null || others.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.blue, // 🔧 Исправлено: был transparent
      appBar: AppBar(
        title: const Text('Мои занятия'),
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
            MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: false)),
          );
          _loadLessons();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Сейчас идёт', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 8),
              Text(lesson.displayType, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(lesson.displayDateTimeRange, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                child: Text(lesson.countdownDetailed),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: false)),
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
            MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: false)),
          );
          _loadLessons();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Ближайшее занятие', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
              const SizedBox(height: 8),
              Text(lesson.displayType, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(lesson.displayDateTimeRange, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                child: Text(lesson.countdownDetailed),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: false)),
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
          child: Icon(lesson.type == 'driving' ? Icons.directions_car : Icons.assignment, color: Colors.blue),
        ),
        title: Text(lesson.displayType),
        subtitle: Text('${lesson.displayDateTimeRange} • ${lesson.countdownShort}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LessonDetailPage(lesson: lesson, isInstructor: false)),
          );
          _loadLessons();
        },
      ),
    );
  }
}