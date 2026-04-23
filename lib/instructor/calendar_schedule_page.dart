import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart';
import '../lesson/lesson_model.dart';
import 'package:intl/intl.dart';

class CalendarSchedulePage extends StatefulWidget {
  final bool isInstructor;
  
  const CalendarSchedulePage({Key? key, this.isInstructor = false}) : super(key: key);

  @override
  _CalendarSchedulePageState createState() => _CalendarSchedulePageState();
}

class _CalendarSchedulePageState extends State<CalendarSchedulePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  List<Lesson> _lessons = [];
  bool _isLoading = true;
  final LessonService _lessonService = LessonService();

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      List<Lesson> allLessons;
      if (widget.isInstructor) {
        final objects = await _lessonService.getLessonsForInstructor(user);
        allLessons = objects.map((obj) => Lesson.fromParse(obj)).toList();
      } else {
        final objects = await _lessonService.getLessonsForStudent(user);
        allLessons = objects.map((obj) => Lesson.fromParse(obj)).toList();
      }
      
      setState(() {
        _lessons = allLessons;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки занятий: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Lesson> _getLessonsForDay(DateTime day) {
    return _lessons.where((lesson) {
      return lesson.startTime.year == day.year &&
             lesson.startTime.month == day.month &&
             lesson.startTime.day == day.day;
    }).toList();
  }

  bool _isDayBusy(DateTime day) {
    return _getLessonsForDay(day).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInstructor ? 'Расписание занятий' : 'Мои занятия'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
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
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Календарь
                  TableCalendar(
                    firstDay: DateTime.now().subtract(const Duration(days: 30)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: _calendarFormat,
                    eventLoader: _getLessonsForDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: const TextStyle(color: Colors.red),
                      holidayTextStyle: const TextStyle(color: Colors.red),
                      selectedDecoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade300,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonShowsNext: false,
                      formatButtonDecoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      formatButtonTextStyle: TextStyle(color: Colors.blue),
                      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Colors.white70),
                      weekendStyle: TextStyle(color: Colors.white70),
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return const SizedBox.shrink();
                        
                        final lessons = events as List<Lesson>;
                        final ongoing = lessons.any((l) => l.isOngoing);
                        
                        return Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ongoing ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Список занятий на выбранный день
                  Expanded(
                    child: _buildDayLessons(),
                  ),
                ],
              ),
      ),
      floatingActionButton: widget.isInstructor
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/instructor-students');
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              icon: const Icon(Icons.add),
              label: const Text('Назначить'),
            )
          : null,
    );
  }

  Widget _buildDayLessons() {
    if (_selectedDay == null) {
      return const Center(
        child: Text('Выберите дату', style: TextStyle(color: Colors.white, fontSize: 16)),
      );
    }

    final dayLessons = _getLessonsForDay(_selectedDay!);
    final dateStr = DateFormat('dd MMMM yyyy', 'ru_RU').format(_selectedDay!);

    if (dayLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Нет занятий на $dateStr',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            dateStr,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dayLessons.length,
            itemBuilder: (context, index) {
              final lesson = dayLessons[index];
              return _buildLessonCard(lesson);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLessonCard(Lesson lesson) {
    Color cardColor;
    switch (lesson.status) {
      case 'ongoing':
        cardColor = Colors.green.shade700;
        break;
      case 'completed':
        cardColor = Colors.grey.shade700;
        break;
      case 'cancelled':
        cardColor = Colors.red.shade700;
        break;
      default:
        cardColor = Colors.blue.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.3),
          child: Icon(
            lesson.type == 'driving' ? Icons.directions_car : Icons.assignment,
            color: Colors.white,
          ),
        ),
        title: Text(
          lesson.displayType,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${lesson.displayStartTime} – ${lesson.displayEndTime}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (!widget.isInstructor && lesson.student != null)
              Text(
                'Студент: ${lesson.student?.get('firstname') ?? ''} ${lesson.student?.get('surname') ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (lesson.carBrand != null && lesson.carBrand!.isNotEmpty)
              Text(
                '${lesson.carBrand} ${lesson.carModel ?? ''} (${lesson.carNumber ?? 'без номера'})',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lesson.displayStatus,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            if (lesson.isOngoing) ...[
              const SizedBox(height: 4),
              const Icon(Icons.play_circle, color: Colors.white, size: 20),
            ],
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/lesson-detail',
            arguments: {'lesson': lesson, 'isInstructor': widget.isInstructor},
          );
        },
      ),
    );
  }
}
