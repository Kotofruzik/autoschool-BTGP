import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../lesson/lesson_model.dart';

class CircularLessonTimer extends StatefulWidget {
  final Lesson lesson;
  final double size;
  final VoidCallback? onTap;
  final bool showLabel;

  const CircularLessonTimer({
    Key? key,
    required this.lesson,
    this.size = 200,
    this.onTap,
    this.showLabel = true,
  }) : super(key: key);

  @override
  State<CircularLessonTimer> createState() => _CircularLessonTimerState();
}

class _CircularLessonTimerState extends State<CircularLessonTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  Timer? _updateTimer;

  double _progress = 1.0;
  String _timeText = '';
  String _labelText = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Инициализируем прогресс перед созданием анимации
    _updateProgressValues();

    _progressAnimation = Tween<double>(begin: _progress, end: _progress).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateProgressValues();
        _animateToNewProgress();
      }
    });
  }

  void _updateProgressValues() {
    final now = DateTime.now();
    final lesson = widget.lesson;

    if (lesson.isOngoing) {
      // Идёт сейчас - показываем прогресс до конца
      final totalDuration = lesson.endTime.difference(lesson.startTime).inMilliseconds;
      final remaining = lesson.endTime.difference(now).inMilliseconds;
      _progress = remaining.clamp(0, totalDuration) / totalDuration;

      final left = lesson.timeUntilEnd;
      if (left.inHours > 0) {
        _timeText = '${left.inHours}ч ${left.inMinutes.remainder(60)}м';
      } else if (left.inMinutes > 0) {
        _timeText = '${left.inMinutes}м ${left.inSeconds.remainder(60)}с';
      } else {
        _timeText = '${left.inSeconds}с';
      }
      _labelText = 'Идёт занятие';

    } else if (!lesson.isPast && lesson.startTime.isAfter(now)) {
      // Назначено - показываем прогресс до начала
      final totalTime = lesson.startTime.difference(DateTime.now().subtract(Duration(hours: 2))).inMilliseconds;
      final untilStart = lesson.startTime.difference(now).inMilliseconds;

      // Прогресс от 1 (давно) до 0 (скоро начало)
      _progress = 1.0 - (untilStart / totalTime).clamp(0.0, 1.0);

      final until = lesson.timeUntilStart;
      if (until.inDays > 0) {
        _timeText = '${until.inDays}д ${until.inHours.remainder(24)}ч';
      } else if (until.inHours > 0) {
        _timeText = '${until.inHours}ч ${until.inMinutes.remainder(60)}м';
      } else if (until.inMinutes > 0) {
        _timeText = '${until.inMinutes}м ${until.inSeconds.remainder(60)}с';
      } else {
        _timeText = '${until.inSeconds}с';
      }
      _labelText = 'До начала';

    } else {
      _progress = 0.0;
      _timeText = 'Завершено';
      _labelText = '';
    }
  }

  void _animateToNewProgress() {
    setState(() {
      _progressAnimation = Tween<double>(begin: _progressAnimation.value, end: _progress).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      _animationController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOngoing = widget.lesson.isOngoing;
    final isPast = widget.lesson.isPast;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Круговой прогресс-бар
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOngoing
                      ? Colors.green
                      : (isPast ? Colors.grey : Colors.orange),
                ),
                strokeCap: StrokeCap.round,
              ),
            ),

            // Центральная часть с информацией
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showLabel)
                  Text(
                    _labelText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    _timeText,
                    key: ValueKey(_timeText),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isOngoing
                          ? Colors.green
                          : (isPast ? Colors.grey : Colors.orange),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.lesson.displayType,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            // Индикатор статуса в углу
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOngoing
                      ? Colors.green
                      : (isPast ? Colors.grey : Colors.blue),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isOngoing ? Colors.green : (isPast ? Colors.grey : Colors.blue)).withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: isOngoing
                    ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.5 + 0.5 * math.sin(value * math.pi * 2),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}