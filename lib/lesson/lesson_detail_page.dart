import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'lesson_model.dart';
import '../services/lesson_service.dart';
import 'package:autoschool_btgp/user_profile_page.dart'; // путь к вашей странице профиля (например, InstructorStudentPreviewPage)

class LessonDetailPage extends StatefulWidget {
  final Lesson lesson;
  final bool isInstructor;

  const LessonDetailPage({Key? key, required this.lesson, required this.isInstructor}) : super(key: key);

  @override
  _LessonDetailPageState createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _instructorData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final studentId = widget.lesson.student?.objectId;
    final instructorId = widget.lesson.instructor?.objectId;

    if (studentId != null) {
      final result = await _fetchUserById(studentId);
      if (result != null) setState(() => _studentData = result);
    }
    if (instructorId != null) {
      final result = await _fetchUserById(instructorId);
      if (result != null) setState(() => _instructorData = result);
    }
    setState(() => _isLoading = false);
  }

  Future<Map<String, dynamic>?> _fetchUserById(String userId) async {
    final function = ParseCloudFunction('getUserById');
    final response = await function.execute(parameters: {'userId': userId});
    if (response.success && response.result != null) {
      return response.result as Map<String, dynamic>;
    }
    return null;
  }

  String _getFullName(Map<String, dynamic>? user) {
    if (user == null) return 'Не найден';
    final surname = user['surname'] as String? ?? '';
    final firstname = user['firstname'] as String? ?? '';
    final patronymic = user['patronymic'] as String? ?? '';
    final parts = [surname, firstname, patronymic].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    final username = user['username'] as String? ?? '';
    if (username.isNotEmpty) return username;
    final email = user['email'] as String? ?? '';
    if (email.isNotEmpty) return email;
    return 'Имя не указано';
  }

  String _getPhone(Map<String, dynamic>? user) {
    if (user == null) return 'Не найден';
    final phone = user['phone'] as String?;
    return (phone != null && phone.isNotEmpty) ? phone : 'Не указан';
  }

  String _getPhotoUrl(Map<String, dynamic>? user) {
    return user?['photo'] as String? ?? '';
  }

  Future<void> _cancelLesson(BuildContext context) async {
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
        await lessonService.cancelLesson(widget.lesson.toParse());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Занятие отменено'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openUserProfile(Map<String, dynamic> userData) {
    // Создаём объект ParseUser из данных (или передаём ID)
    final user = ParseUser(null, null, null);
    user.objectId = userData['id'];
    user.set('surname', userData['surname']);
    user.set('firstname', userData['firstname']);
    user.set('patronymic', userData['patronymic']);
    user.set('phone', userData['phone']);
    user.set('email', userData['email']);
    user.set('photo', userData['photo']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(user: user), // используйте вашу страницу профиля
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriving = widget.lesson.type == 'driving';
    final typeIcon = isDriving ? Icons.directions_car : Icons.assignment;
    final typeColor = isDriving ? Colors.blue : Colors.orange;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Детали занятия'),
        elevation: 0,
        backgroundColor: Colors.blue,
        actions: [
          if (widget.isInstructor &&
              widget.lesson.status != 'cancelled' &&
              widget.lesson.status != 'completed')
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _cancelLesson(context),
              tooltip: 'Отменить занятие',
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Основная карточка с типом, датой, статусом
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(typeIcon, color: typeColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.lesson.displayType,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatDate(widget.lesson.startTime)} • ${_formatTime(widget.lesson.startTime)} – ${_formatTime(widget.lesson.endTime)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusChip(widget.lesson.displayStatus),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.access_time,
                            label: 'Длительность',
                            value: '${widget.lesson.calculatedDuration} мин',
                          ),
                          if (widget.lesson.comment != null && widget.lesson.comment!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              icon: Icons.comment,
                              label: 'Комментарий',
                              value: widget.lesson.comment!,
                              isMultiline: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Карточка участника (кликабельная)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: InkWell(
                      onTap: () {
                        final userData = widget.isInstructor ? _studentData : _instructorData;
                        if (userData != null && userData['id'] != null) {
                          _openUserProfile(userData);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Данные пользователя не найдены')),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isInstructor ? 'Ученик' : 'Инструктор',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: _getPhotoUrl(widget.isInstructor ? _studentData : _instructorData).isNotEmpty
                                      ? CachedNetworkImageProvider(_getPhotoUrl(widget.isInstructor ? _studentData : _instructorData))
                                      : null,
                                  backgroundColor: Colors.blue.shade100,
                                  child: _getPhotoUrl(widget.isInstructor ? _studentData : _instructorData).isEmpty
                                      ? Icon(
                                    widget.isInstructor ? Icons.person : Icons.school,
                                    color: Colors.blue,
                                  )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.isInstructor
                                            ? _getFullName(_studentData)
                                            : _getFullName(_instructorData),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      Text(
                                        widget.isInstructor
                                            ? 'Телефон: ${_getPhone(_studentData)}'
                                            : 'Телефон: ${_getPhone(_instructorData)}',
                                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Карточка автомобиля
                  if (widget.lesson.carBrand != null ||
                      widget.lesson.carModel != null ||
                      widget.lesson.carNumber != null ||
                      widget.lesson.carPhotoUrl != null)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Автомобиль',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (widget.lesson.carBrand != null && widget.lesson.carBrand!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.directions_car,
                                label: 'Марка',
                                value: widget.lesson.carBrand!,
                              ),
                            if (widget.lesson.carModel != null && widget.lesson.carModel!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.settings,
                                label: 'Модель',
                                value: widget.lesson.carModel!,
                              ),
                            if (widget.lesson.carNumber != null && widget.lesson.carNumber!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.local_police,
                                label: 'Госномер',
                                value: widget.lesson.carNumber!,
                              ),
                            if (widget.lesson.carPhotoUrl != null && widget.lesson.carPhotoUrl!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: widget.lesson.carPhotoUrl!,
                                  placeholder: (_, __) => const SizedBox(
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'запланировано':
        color = Colors.blue;
        break;
      case 'идёт сейчас':
        color = Colors.orange;
        break;
      case 'проведено':
        color = Colors.green;
        break;
      case 'отменено':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            softWrap: true,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
  String _formatTime(DateTime date) => '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}