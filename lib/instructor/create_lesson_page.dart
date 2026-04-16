import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import '../services/lesson_service.dart';

class CreateLessonPage extends StatefulWidget {
  final ParseUser student;
  const CreateLessonPage({Key? key, required this.student}) : super(key: key);

  @override
  _CreateLessonPageState createState() => _CreateLessonPageState();
}

class _CreateLessonPageState extends State<CreateLessonPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final LessonService _lessonService = LessonService();

  // Шаг 0: Тип занятия
  String _lessonType = 'driving';

  // Шаг 1: Дата и время
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  int _durationMinutes = 60;
  DateTime get _endDate => _startDate.add(Duration(minutes: _durationMinutes));

  // Шаг 2: Автомобиль (опционально)
  final TextEditingController _carBrandController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();
  String? _carPhotoUrl;
  bool _isUploading = false;

  // Шаг 3: Комментарий
  final TextEditingController _commentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _isCreating = false;

  @override
  void dispose() {
    _pageController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _carNumberController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate),
      );
      if (time != null) {
        setState(() {
          _startDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressQuality: 80,
      maxWidth: 1024,
      maxHeight: 576,
    );

    final fileToUpload = croppedFile != null ? File(croppedFile.path) : File(image.path);
    setState(() => _isUploading = true);

    final photoUrl = await _lessonService.uploadCarPhoto(XFile(fileToUpload.path));
    setState(() {
      _carPhotoUrl = photoUrl;
      _isUploading = false;
    });

    if (photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
      );
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _createLesson();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  Future<void> _createLesson() async {
    if (!_validateStep()) return;

    setState(() => _isCreating = true);
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
    if (instructor == null) return;

    try {
      await _lessonService.createLesson(
        type: _lessonType,
        startTime: _startDate,
        endTime: _endDate,
        carBrand: _carBrandController.text.isNotEmpty ? _carBrandController.text : null,
        carModel: _carModelController.text.isNotEmpty ? _carModelController.text : null,
        carNumber: _carNumberController.text.isNotEmpty ? _carNumberController.text : null,
        carPhotoUrl: _carPhotoUrl,
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
        student: widget.student,
        instructor: instructor,
      );

      // Отправка push-уведомления ученику
      try {
        final cloudFunc = ParseCloudFunction('sendPushToStudent');
        await cloudFunc.execute(parameters: {
          'studentId': widget.student.objectId,
          'lessonType': _lessonType,
          'lessonTime': _formatTime(_startDate),
        });
        print('✅ Push-уведомление отправлено');
      } catch (e) {
        print('❌ Ошибка отправки уведомления: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_lessonType == 'driving' ? 'Вождение' : 'Экзамен'} назначен'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  String _formatTime(DateTime date) => '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

  bool _validateStep() {
    switch (_currentStep) {
      case 0:
        return true;
      case 1:
        return true;
      case 2:
        if (_carNumberController.text.isNotEmpty && _carNumberController.text.length < 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Госномер должен быть не менее 5 символов'), backgroundColor: Colors.red),
          );
          return false;
        }
        return true;
      case 3:
        return true;
      default:
        return true;
    }
  }

  Widget _buildStepIcon(int step, IconData icon) {
    final isActive = _currentStep >= step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentStep == 3;
    final buttonText = isLastStep ? (_lessonType == 'driving' ? 'Назначить вождение' : 'Назначить экзамен') : 'Далее';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Назначить занятие'),
        elevation: 0,
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
          child: Column(
            children: [
              // Индикатор шагов (иконки)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        _buildStepIcon(0, Icons.category),
                        const SizedBox(height: 4),
                        const Text('Тип', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    Container(width: 20, height: 2, color: Colors.white30),
                    Column(
                      children: [
                        _buildStepIcon(1, Icons.calendar_today),
                        const SizedBox(height: 4),
                        const Text('Время', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    Container(width: 20, height: 2, color: Colors.white30),
                    Column(
                      children: [
                        _buildStepIcon(2, Icons.directions_car),
                        const SizedBox(height: 4),
                        const Text('Авто', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    Container(width: 20, height: 2, color: Colors.white30),
                    Column(
                      children: [
                        _buildStepIcon(3, Icons.comment),
                        const SizedBox(height: 4),
                        const Text('Коммент', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Страницы с контентом
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentStep = index),
                  children: [
                    _buildTypeStep(),
                    _buildDateTimeStep(),
                    _buildCarStep(),
                    _buildCommentStep(),
                  ],
                ),
              ),

              // Кнопки навигации
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Назад'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLastStep ? (_lessonType == 'driving' ? Colors.green : Colors.orange) : Colors.white,
                          foregroundColor: isLastStep ? Colors.white : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isCreating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Выберите тип занятия', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _lessonType = 'driving'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _lessonType == 'driving' ? Colors.blue.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _lessonType == 'driving' ? Colors.blue : Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.directions_car, size: 40, color: _lessonType == 'driving' ? Colors.blue : Colors.grey),
                              const SizedBox(height: 8),
                              Text('Вождение', style: TextStyle(fontWeight: FontWeight.bold, color: _lessonType == 'driving' ? Colors.blue : Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _lessonType = 'exam'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _lessonType == 'exam' ? Colors.blue.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _lessonType == 'exam' ? Colors.blue : Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.assignment, size: 40, color: _lessonType == 'exam' ? Colors.blue : Colors.grey),
                              const SizedBox(height: 8),
                              Text('Экзамен', style: TextStyle(fontWeight: FontWeight.bold, color: _lessonType == 'exam' ? Colors.blue : Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Дата и время', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text('${_startDate.day}.${_startDate.month}.${_startDate.year}'),
                  subtitle: const Text('Выберите дату'),
                  onTap: _selectStartDate,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.access_time, color: Colors.blue),
                  title: Text('${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')}'),
                  subtitle: const Text('Выберите время начала'),
                  onTap: _selectStartDate,
                ),
                const SizedBox(height: 8),
                const Text('Длительность', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _durationMinutes,
                  items: [30, 45, 60, 90, 120].map((v) => DropdownMenuItem(value: v, child: Text('$v мин'))).toList(),
                  onChanged: (v) => setState(() => _durationMinutes = v!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Окончание: ${_endDate.hour}:${_endDate.minute.toString().padLeft(2, '0')}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Автомобиль (необязательно)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _carBrandController,
                  decoration: const InputDecoration(
                    labelText: 'Марка',
                    prefixIcon: Icon(Icons.local_car_wash),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _carModelController,
                  decoration: const InputDecoration(
                    labelText: 'Модель',
                    prefixIcon: Icon(Icons.settings),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _carNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Госномер',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_carPhotoUrl == null)
                  ElevatedButton.icon(
                    onPressed: _pickAndUploadImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Добавить фото'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
                  )
                else
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_carPhotoUrl!, height: 150, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _pickAndUploadImage,
                        icon: const Icon(Icons.change_circle),
                        label: const Text('Заменить фото'),
                      ),
                    ],
                  ),
                if (_isUploading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Комментарий (необязательно)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Дополнительная информация...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Краткая информация', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Тип: ${_lessonType == 'driving' ? 'Вождение' : 'Экзамен'}'),
                Text('Дата: ${_startDate.day}.${_startDate.month}.${_startDate.year}'),
                Text('Время: ${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')} – ${_endDate.hour}:${_endDate.minute.toString().padLeft(2, '0')}'),
                Text('Длительность: $_durationMinutes мин'),
                if (_carBrandController.text.isNotEmpty) Text('Автомобиль: ${_carBrandController.text} ${_carModelController.text}'),
                if (_carNumberController.text.isNotEmpty) Text('Госномер: ${_carNumberController.text}'),
                if (_commentController.text.isNotEmpty) Text('Комментарий: ${_commentController.text}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}