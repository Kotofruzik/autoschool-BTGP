import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'lesson_model.dart';

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;
  final bool showActions;
  final VoidCallback? onReschedule;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const LessonCard({
    Key? key,
    required this.lesson,
    required this.onTap,
    this.showActions = false,
    this.onReschedule,
    this.onApprove,
    this.onReject,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOngoing = lesson.isOngoing;
    final isPast = lesson.isPast;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.displayType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lesson.displayDateTimeRange,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (lesson.carPhotoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: lesson.carPhotoUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOngoing ? Colors.green : (isPast ? Colors.grey : Colors.blue),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      lesson.displayStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if (!isPast && !isOngoing)
                    Text(
                      'До начала: ${lesson.countdownDetailed}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  if (isOngoing)
                    Text(
                      'Осталось: ${lesson.countdownDetailed}',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green),
                    ),
                ],
              ),
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (lesson.status == 'reschedule_requested' && onApprove != null && onReject != null) ...[
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: onApprove,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: onReject,
                      ),
                    ],
                    if (lesson.status == 'scheduled' && onReschedule != null)
                      IconButton(
                        icon: const Icon(Icons.schedule, color: Colors.orange),
                        onPressed: onReschedule,
                      ),
                    if (lesson.status == 'reschedule_requested')
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Ожидает ответа', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      ),
                    if (onCancel != null)
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: onCancel,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}