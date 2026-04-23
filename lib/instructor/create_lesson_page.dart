import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import '../services/lesson_service.dart';
import '../services/car_service.dart';
import '../models/car_model.dart';

class CreateLessonPage extends StatefulWidget {
  final ParseUser? student;
  final DateTime? selectedDate;
  final bool skipDateStep; // Флаг для пропуска шага выбора даты

  const CreateLessonPage({Key? key, this.student, this.selectedDate, this.skipDateStep = false}) : super(key: key);

  @override
  _CreateLessonPageState createState() => _CreateLessonPageState();
}

class _CreateLessonPageState extends State<CreateLessonPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final LessonService _lessonService = LessonService();
  final CarService _carService = CarService();

  // Шаг 0: Тип занятия
  String _lessonType = 'driving';

  // Шаг 1: Выбор студента
  ParseUser? _selectedStudent;

  // Шаг 2: Дата и время
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  int _durationMinutes = 60;
  DateTime get _endDate => _startDate.add(Duration(minutes: _durationMinutes));

  // Шаг 3: Выбор автомобиля из автопарка
  List<Car> _instructorCars = [];
  Car? _selectedCar;
  bool _isLoadingCars = false;

  // Комментарий
  final TextEditingController _commentController = TextEditingController();

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Если передан студент (например, из профиля ученика), используем его
    if (widget.student != null) {
      _selectedStudent = widget.student;
    }
    // Если передана дата из календаря, используем её
    if (widget.selectedDate != null) {
      _startDate = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        12, // полдень по умолчанию
        0,
      );
    }
    _loadInstructorCars();
    _loadStudents();
  }

  List<ParseUser> _allStudents = [];
  bool _isLoadingStudents = false;

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final instructor = authService.currentUser;
      if (instructor == null) {
        setState(() => _isLoadingStudents = false);
        return;
      }

      // Получаем всех студентов, которые прикреплены к этому инструктору
      final studentObjects = await _lessonService.getStudentsForInstructor(instructor);
      setState(() {
        _allStudents = studentObjects.whereType<ParseUser>().toList();
        _isLoadingStudents = false;
      });
    } catch (e) {
      print('Ошибка загрузки студентов: $e');
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _loadInstructorCars() async {
    setState(() => _isLoadingCars = true);
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
    if (instructor == null) {
      setState(() => _isLoadingCars = false);
      return;
    }

    try {
      final cars = await _carService.getCarsForInstructor(instructor);
      setState(() {
        _instructorCars = cars.where((c) => c.isActive).toList();
        _isLoadingCars = false;
      });
    } catch (e) {
      print('Ошибка загрузки автомобилей: $e');
      setState(() => _isLoadingCars = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  void _nextStep() {
    if (_currentStep < 4) {
      // Проверка валидации перед переходом
      if (_currentStep == 1 && !_validateStudentStep()) return;
      if (_currentStep == 3 && !_validateCarStep()) return;

      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _createLesson();
    }
  }

  bool _validateStudentStep() {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ученика из списка'), backgroundColor: Colors.red),
      );
      return false;
    }
    return true;
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  bool _validateCarStep() {
    if (_instructorCars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте автомобили в автопарк в профиле инструктора'),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 4),
        ),
      );
      return false;
    }
    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите автомобиль из списка'), backgroundColor: Colors.red),
      );
      return false;
    }
    return true;
  }

  Future<void> _createLesson() async {
    // Финальная проверка перед созданием
    if (_instructorCars.isEmpty || _selectedCar == null) {
      if (!_validateCarStep()) return;
    }

    // Проверка студента
    final student = _selectedStudent ?? widget.student;
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: студент не выбран'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCreating = true);
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
    if (instructor == null) {
      setState(() => _isCreating = false);
      return;
    }

    try {
      await _lessonService.createLesson(
        type: _lessonType,
        startTime: _startDate,
        endTime: _endDate,
        carBrand: _selectedCar!.brand,
        carModel: _selectedCar!.model,
        carNumber: _selectedCar!.number,
        carPhotoUrl: _selectedCar!.photoUrl?.trim(),
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
        student: student,
        instructor: instructor,
      );

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
    final isLastStep = _currentStep == 4;
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
                        _buildStepIcon(1, Icons.person),
                        const SizedBox(height: 4),
                        const Text('Ученик', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    Container(width: 20, height: 2, color: Colors.white30),
                    Column(
                      children: [
                        _buildStepIcon(2, Icons.access_time),
                        const SizedBox(height: 4),
                        const Text('Время', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    Container(width: 20, height: 2, color: Colors.white30),
                    Column(
                      children: [
                        _buildStepIcon(3, Icons.directions_car),
                        const SizedBox(height: 4),
                        const Text('Авто', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    Container(width: 20, height: 2, color: Colors.white30),
                    Column(
                      children: [
                        _buildStepIcon(4, Icons.comment),
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
                    _buildStudentStep(),
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
        if (widget.selectedDate != null && widget.skipDateStep) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Дата уже выбрана', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('${widget.selectedDate!.day}.${widget.selectedDate!.month}.${widget.selectedDate!.year}', style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStudentStep() {
    // Если студент уже передан (например, из профиля ученика), показываем его и пропускаем выбор
    if (widget.student != null) {
      final student = widget.student!;
      final fullName = [
        student.get('surname') ?? '',
        student.get('firstname') ?? '',
        student.get('patronymic') ?? ''
      ].where((s) => s.isNotEmpty).join(' ');
      
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName.isNotEmpty ? fullName : student.get('email') ?? 'Ученик', 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(student.get('phone') ?? 'Телефон не указан', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Этот ученик уже выбран. Нажмите "Далее" для продолжения.', 
                     style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        ],
      );
    }
    
    // Иначе показываем список студентов для выбора
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
                const Text('Выберите ученика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_isLoadingStudents)
                  const Center(child: CircularProgressIndicator())
                else if (_allStudents.isEmpty) ...[
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет учеников', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Пока нет учеников, которым можно назначить занятие', 
                             style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ] else ...[
                  for (final student in _allStudents)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _selectedStudent?.objectId == student.objectId ? Colors.blue : Colors.grey.shade300,
                        child: Icon(Icons.person, color: _selectedStudent?.objectId == student.objectId ? Colors.white : Colors.grey),
                      ),
                      title: Text([
                        student.get('surname') ?? '',
                        student.get('firstname') ?? '',
                        student.get('patronymic') ?? ''
                      ].where((s) => s.isNotEmpty).join(' ') || student.get('email') ?? 'Ученик'),
                      subtitle: Text(student.get('phone') ?? 'Телефон не указан'),
                      selected: _selectedStudent?.objectId == student.objectId,
                      selectedTileColor: Colors.blue.shade50,
                      onTap: () => setState(() => _selectedStudent = student),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeStep() {
    // Если дата была передана из календаря, показываем её без возможности изменения
    final isDateFromCalendar = widget.selectedDate != null && widget.skipDateStep;
    
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
                if (!isDateFromCalendar) ...[
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
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.green),
                    title: Text('${_startDate.day}.${_startDate.month}.${_startDate.year}'),
                    subtitle: const Text('Дата выбрана в календаре'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.blue),
                    title: Text('${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')}'),
                    subtitle: const Text('Выберите время начала'),
                    onTap: () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_startDate),
                      );
                      if (time != null) {
                        setState(() {
                          _startDate = DateTime(
                            _startDate.year,
                            _startDate.month,
                            _startDate.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    },
                  ),
                ],
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
                const Text('Выберите автомобиль', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                if (_isLoadingCars)
                  const Center(child: CircularProgressIndicator())
                else if (_instructorCars.isEmpty) ...[
                  // Состояние: нет автомобилей
                  Column(
                    children: [
                      Icon(Icons.car_crash, size: 64, color: Colors.amber.shade700),
                      const SizedBox(height: 16),
                      Text(
                        'У вас пока нет автомобилей в автопарке',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Добавьте автомобиль в разделе "Автопарк" в профиле инструктора, чтобы назначать занятия.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Закрыть создание занятия
                          // Здесь можно добавить навигацию на профиль, если известен маршрут
                          // Например: Navigator.pushNamed(context, '/profile');
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Перейти в профиль'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Состояние: есть список автомобилей
                  Text(
                    'Выберите автомобиль из вашего автопарка:',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  ..._instructorCars.map((car) => RadioListTile<Car>(
                    value: car,
                    groupValue: _selectedCar,
                    onChanged: (value) {
                      setState(() {
                        _selectedCar = value;
                      });
                    },
                    title: Text('${car.brand} ${car.model}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(car.number),
                    secondary: car.photoUrl != null && car.photoUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: car.photoUrl!.trim(),
                        width: 60,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 40,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 20, color: Colors.grey),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 40,
                          color: Colors.blue.shade100,
                          child: const Icon(Icons.directions_car, size: 24, color: Colors.blue),
                        ),
                      ),
                    )
                        : Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.directions_car, size: 24, color: Colors.blue),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentStep() {
    final student = _selectedStudent ?? widget.student;
    final studentName = student != null 
        ? [student.get('surname') ?? '', student.get('firstname') ?? '', student.get('patronymic') ?? '']
            .where((s) => s.isNotEmpty).join(' ')
        : 'Не выбран';
    
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
                Text('Ученик: $studentName'),
                Text('Тип: ${_lessonType == 'driving' ? 'Вождение' : 'Экзамен'}'),
                Text('Дата: ${_startDate.day}.${_startDate.month}.${_startDate.year}'),
                Text('Время: ${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')} – ${_endDate.hour}:${_endDate.minute.toString().padLeft(2, '0')}'),
                Text('Длительность: $_durationMinutes мин'),
                if (_selectedCar != null) ...[
                  Text('Автомобиль: ${_selectedCar!.brand} ${_selectedCar!.model}'),
                  Text('Госномер: ${_selectedCar!.number}'),
                ],
                if (_commentController.text.isNotEmpty) Text('Комментарий: ${_commentController.text}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}