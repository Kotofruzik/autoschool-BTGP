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
  final bool skipDateStep;
  final bool skipStudentStep;

  const CreateLessonPage({Key? key, this.student, this.selectedDate, this.skipDateStep = false, this.skipStudentStep = false}) : super(key: key);

  @override
  _CreateLessonPageState createState() => _CreateLessonPageState();
}

class _CreateLessonPageState extends State<CreateLessonPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final LessonService _lessonService = LessonService();
  final CarService _carService = CarService();

  // Конфигурация шагов
  late final List<Map<String, dynamic>> _steps;
  
  // Данные
  String _lessonType = 'driving';
  ParseUser? _selectedStudent;
  List<ParseUser> _allStudents = [];
  bool _isLoadingStudents = false;
  DateTime _startDate = DateTime.now().add(const Duration(hours: 1));
  int _durationMinutes = 60;
  DateTime get _endDate => _startDate.add(Duration(minutes: _durationMinutes));
  List<Car> _instructorCars = [];
  Car? _selectedCar;
  bool _isLoadingCars = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) _selectedStudent = widget.student;
    if (widget.selectedDate != null) {
      _startDate = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, 12, 0);
    }
    
    // Инициализация шагов в зависимости от skipDateStep и skipStudentStep
    final showTypeStep = !widget.skipDateStep;
    final showStudentStep = !widget.skipStudentStep && widget.student == null;
    
    _steps = [
      if (showTypeStep) {'icon': Icons.category, 'label': 'Тип', 'widget': _buildTypeStep},
      if (showStudentStep) {'icon': Icons.person, 'label': 'Ученик', 'widget': _buildStudentStep},
      {'icon': Icons.access_time, 'label': 'Время', 'widget': _buildDateTimeStep},
      {'icon': Icons.directions_car, 'label': 'Авто', 'widget': _buildCarStep},
      {'icon': Icons.comment, 'label': 'Коммент', 'widget': _buildCommentStep},
    ];
    
    _currentStep = 0;
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadInstructorCars();
    if (!widget.skipStudentStep && widget.student == null) {
      await _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
      if (instructor == null) return setState(() => _isLoadingStudents = false);
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
    if (instructor == null) return setState(() => _isLoadingCars = false);
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
      context: context, initialDate: _startDate,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startDate));
      if (time != null) {
        setState(() => _startDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      if (!_validateStep()) return;
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _createLesson();
    }
  }

  bool _validateStep() {
    final studentStepIndex = widget.skipDateStep ? 0 : (widget.skipStudentStep || widget.student != null ? 0 : 1);
    final carStepIndex = studentStepIndex + 2;
    
    if (_currentStep == studentStepIndex && _selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите ученика'), backgroundColor: Colors.red));
      return false;
    }
    if (_currentStep == carStepIndex) {
      if (_instructorCars.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавьте автомобили в автопарк'), backgroundColor: Colors.amber));
        return false;
      }
      if (_selectedCar == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите автомобиль'), backgroundColor: Colors.red));
        return false;
      }
    }
    return true;
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  Future<void> _createLesson() async {
    if (_instructorCars.isEmpty || _selectedCar == null) {
      if (!_validateStep()) return;
    }
    final student = _selectedStudent ?? widget.student;
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Студент не выбран'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isCreating = true);
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
    if (instructor == null) return setState(() => _isCreating = false);

    try {
      await _lessonService.createLesson(
        type: _lessonType, startTime: _startDate, endTime: _endDate,
        carBrand: _selectedCar!.brand, carModel: _selectedCar!.model, carNumber: _selectedCar!.number,
        carPhotoUrl: _selectedCar!.photoUrl?.trim(), comment: _commentController.text.isNotEmpty ? _commentController.text : null,
        student: student, instructor: instructor,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_lessonType == 'driving' ? 'Вождение' : 'Экзамен'} назначен'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentStep == _steps.length - 1;
    final buttonText = isLastStep ? (_lessonType == 'driving' ? 'Назначить вождение' : 'Назначить экзамен') : 'Далее';

    return Scaffold(
      appBar: AppBar(title: const Text('Назначить занятие'), elevation: 0),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.blue, Colors.lightBlueAccent])),
        child: SafeArea(
          child: Column(
            children: [
              // Индикатор шагов
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int i = 0; i < _steps.length; i++) ...[
                      _buildStepItem(i),
                      if (i < _steps.length - 1) Container(width: 20, height: 2, color: Colors.white30),
                    ],
                  ],
                ),
              ),
              // Контент шагов
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentStep = index),
                  children: _steps.map((s) => s['widget']() as Widget).toList(),
                ),
              ),
              // Кнопки навигации
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('Назад'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLastStep ? (_lessonType == 'driving' ? Colors.green : Colors.orange) : Colors.white,
                          foregroundColor: isLastStep ? Colors.white : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isCreating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildStepItem(int step) {
    final isActive = _currentStep >= step;
    final data = _steps[step];
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40, height: 40,
          decoration: BoxDecoration(color: isActive ? Colors.blue : Colors.white.withOpacity(0.3), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: Icon(data['icon'], color: isActive ? Colors.white : Colors.white70, size: 20),
        ),
        const SizedBox(height: 4),
        Text(data['label'], style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
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
                          child: Column(children: [
                            Icon(Icons.directions_car, size: 40, color: _lessonType == 'driving' ? Colors.blue : Colors.grey),
                            const SizedBox(height: 8),
                            Text('Вождение', style: TextStyle(fontWeight: FontWeight.bold, color: _lessonType == 'driving' ? Colors.blue : Colors.grey)),
                          ]),
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
                          child: Column(children: [
                            Icon(Icons.assignment, size: 40, color: _lessonType == 'exam' ? Colors.blue : Colors.grey),
                            const SizedBox(height: 8),
                            Text('Экзамен', style: TextStyle(fontWeight: FontWeight.bold, color: _lessonType == 'exam' ? Colors.blue : Colors.grey)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.selectedDate != null) ...[
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
    if (widget.student != null) return _buildSelectedStudentCard(widget.student!);
    if (_selectedStudent != null) return _buildSelectedStudentCard(_selectedStudent!);
    
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
                else if (_allStudents.isEmpty)
                  const Center(child: Column(children: [Icon(Icons.people_outline, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Нет учеников', style: TextStyle(color: Colors.grey))]))
                else
                  for (final student in _allStudents)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: _selectedStudent?.objectId == student.objectId ? Colors.blue : Colors.grey.shade300, child: Icon(Icons.person, color: _selectedStudent?.objectId == student.objectId ? Colors.white : Colors.grey)),
                      title: Text(_getStudentName(student)),
                      subtitle: Text(student.get('phone') ?? 'Телефон не указан'),
                      selected: _selectedStudent?.objectId == student.objectId,
                      selectedTileColor: Colors.blue.shade50,
                      onTap: () => setState(() => _selectedStudent = student),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedStudentCard(ParseUser student) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        CircleAvatar(radius: 30, backgroundColor: Colors.blue, child: const Icon(Icons.person, color: Colors.white, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_getStudentName(student), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(student.get('phone') ?? 'Телефон не указан', style: const TextStyle(color: Colors.grey)),
        ])),
        const Icon(Icons.check_circle, color: Colors.green, size: 32),
      ]))),
      const SizedBox(height: 16),
      const Text('Ученик выбран. Нажмите "Далее" для продолжения.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildDateTimeStep() {
    final isDateFromCalendar = widget.selectedDate != null && widget.skipDateStep;
    final isFromStudentProfile = widget.student != null || widget.skipStudentStep;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Карточка даты
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: isDateFromCalendar ? Colors.green : Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Дата',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDateFromCalendar ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDateFromCalendar ? Colors.green : Colors.blue, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: isDateFromCalendar ? Colors.green : Colors.blue, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_startDate.day}.${_startDate.month}.${_startDate.year}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isDateFromCalendar ? 'Выбрана в календаре' : 'Нажмите для изменения',
                              style: TextStyle(fontSize: 14, color: isDateFromCalendar ? Colors.green.shade700 : Colors.blue.shade700),
                            ),
                          ],
                        ),
                      ),
                      if (!isDateFromCalendar)
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
                if (!isDateFromCalendar) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _selectStartDate,
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Изменить дату'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Карточка времени
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Время',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_startDate),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.orange)),
                        child: child!,
                      ),
                    );
                    if (time != null) {
                      setState(() => _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day, time.hour, time.minute));
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.orange, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Нажмите для выбора времени',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Длительность занятия', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButtonFormField<int>(
                        value: _durationMinutes,
                        items: [30, 45, 60, 90, 120].map((v) => DropdownMenuItem(value: v, child: Text('$v мин', style: const TextStyle(fontSize: 16)))).toList(),
                        onChanged: (v) => setState(() => _durationMinutes = v!),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: Icon(Icons.timer, color: Colors.orange),
                        ),
                        dropdownColor: Colors.white,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Окончание:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        '${_endDate.hour}:${_endDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
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
                else if (_instructorCars.isEmpty)
                  Column(children: [
                    Icon(Icons.car_crash, size: 64, color: Colors.amber.shade700),
                    const SizedBox(height: 16),
                    Text('У вас пока нет автомобилей в автопарке', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Добавьте автомобиль в разделе \"Автопарк\" в профиле инструктора', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.person), label: const Text('Перейти в профиль'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
                  ])
                else ...[
                  Text('Выберите автомобиль из вашего автопарка:', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  for (final car in _instructorCars)
                    RadioListTile<Car>(value: car, groupValue: _selectedCar, onChanged: (v) => setState(() => _selectedCar = v),
                      title: Text('${car.brand} ${car.model}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(car.number),
                      secondary: car.photoUrl != null && car.photoUrl!.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: car.photoUrl!.trim(), width: 60, height: 40, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 60, height: 40, color: Colors.grey[300], child: const Icon(Icons.image, size: 20, color: Colors.grey)), errorWidget: (_, __, ___) => Container(width: 60, height: 40, color: Colors.blue.shade100, child: const Icon(Icons.directions_car, size: 24, color: Colors.blue))))
                          : Container(width: 60, height: 40, decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.directions_car, size: 24, color: Colors.blue)),
                    ),
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
    final studentName = student != null ? [student.get('surname') ?? '', student.get('firstname') ?? '', student.get('patronymic') ?? ''].where((s) => s.isNotEmpty).join(' ') : 'Не выбран';
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Комментарий (необязательно)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _commentController, maxLines: 4, decoration: const InputDecoration(hintText: 'Дополнительная информация...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment))),
        ]))),
        const SizedBox(height: 16),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Краткая информация', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Ученик: $studentName'),
          Text('Тип: ${_lessonType == 'driving' ? 'Вождение' : 'Экзамен'}'),
          Text('Дата: ${_startDate.day}.${_startDate.month}.${_startDate.year}'),
          Text('Время: ${_startDate.hour}:${_startDate.minute.toString().padLeft(2, '0')} – ${_endDate.hour}:${_endDate.minute.toString().padLeft(2, '0')}'),
          Text('Длительность: $_durationMinutes мин'),
          if (_selectedCar != null) ...[Text('Автомобиль: ${_selectedCar!.brand} ${_selectedCar!.model}'), Text('Госномер: ${_selectedCar!.number}')],
          if (_commentController.text.isNotEmpty) Text('Комментарий: ${_commentController.text}'),
        ]))),
      ],
    );
  }

  String _getStudentName(ParseUser student) {
    final parts = [student.get('surname') ?? '', student.get('firstname') ?? '', student.get('patronymic') ?? '']
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? (student.get('email') ?? 'Ученик') : parts.join(' ');
  }
}