import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';

class InstructorStudentsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;
  String? _error;
  ParseLiveQueryClient? _liveQueryClient;
  ParseSubscription? _subscription;
  String? _currentInstructorId;

  List<Map<String, dynamic>> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Инициализирует LiveQuery подписку для отслеживания изменений
  Future<void> initializeLiveQuery(String instructorId) async {
    if (_currentInstructorId == instructorId && _subscription != null) {
      return; // Уже подписаны на этого инструктора
    }

    await _stopLiveQuery();
    _currentInstructorId = instructorId;

    try {
      // Создаём LiveQuery клиент
      _liveQueryClient = await Parse().createLiveQueryClient();
      
      // Создаём запрос для отслеживания изменений пользователей с этим instructorId
      final query = QueryBuilder<ParseObject>(ParseObject('_User'))
        ..whereEqualTo('instructorId', instructorId);

      // Подписываемся на события
      _subscription = await _liveQueryClient!.subscribe(query);
      
      // Обработчик создания/обновления объекта (когда ученик привязывается)
      _subscription!.on(ParseLiveQueryEvent.create, (event) {
        print('🔔 LiveQuery: новый ученик привязан');
        _handleStudentChange(event.data);
      });

      _subscription!.on(ParseLiveQueryEvent.update, (event) {
        print('🔔 LiveQuery: данные ученика обновлены');
        _handleStudentChange(event.data);
      });

      // Обработчик удаления/отвязки ученика
      _subscription!.on(ParseLiveQueryEvent.delete, (event) {
        print('🔔 LiveQuery: ученик откреплён');
        final studentId = event.data.objectId;
        if (studentId != null) {
          removeStudentLocally(studentId);
        }
      });

      _subscription!.on(ParseLiveQueryEvent.enter, (event) {
        print('🔔 LiveQuery: ученик вошёл в выборку (привязался)');
        _handleStudentChange(event.data);
      });

      _subscription!.on(ParseLiveQueryEvent.leave, (event) {
        print('🔔 LiveQuery: ученик покинул выборку (открепился)');
        final studentId = event.data.objectId;
        if (studentId != null) {
          removeStudentLocally(studentId);
        }
      });

      // Загружаем текущий список после подписки
      await loadStudents();
      
      print('✅ LiveQuery подписка активирована для инструктора $instructorId');
    } catch (e) {
      print('❌ Ошибка при создании LiveQuery подписки: $e');
    }
  }

  /// Обрабатывает изменение данных ученика
  void _handleStudentChange(ParseObject data) {
    final instructorId = data.get('instructorId');
    
    // Если instructorId совпадает с текущим инструктором - добавляем/обновляем ученика
    if (instructorId == _currentInstructorId) {
      final studentMap = {
        'id': data.objectId,
        'email': data.get('email') ?? '',
        'surname': data.get('surname') ?? '',
        'firstname': data.get('firstname') ?? '',
        'patronymic': data.get('patronymic') ?? '',
        'phone': data.get('phone') ?? '',
        'photo': data.get('photo'),
        'role': data.get('role') ?? 'student',
      };
      addStudentLocally(studentMap);
    } else {
      // Если instructorId изменился на другой или стал null - удаляем из списка
      final studentId = data.objectId;
      if (studentId != null) {
        removeStudentLocally(studentId);
      }
    }
  }

  /// Останавливает LiveQuery подписку
  Future<void> _stopLiveQuery() async {
    if (_subscription != null) {
      await _liveQueryClient?.unsubscribe(_subscription!);
      _subscription = null;
    }
    if (_liveQueryClient != null) {
      await _liveQueryClient?.disconnect();
      _liveQueryClient = null;
    }
    _currentInstructorId = null;
  }

  /// Загружает список учеников текущего инструктора
  Future<void> loadStudents() async {
    _setLoading(true);
    _error = null;

    try {
      final function = ParseCloudFunction('getMyStudents');
      final response = await function.execute(parameters: {});

      if (response.success && response.result != null) {
        _students = List<Map<String, dynamic>>.from(response.result);
        notifyListeners();
      } else {
        _error = response.error?.message ?? 'Ошибка загрузки';
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Удаляет ученика из списка локально (после успешного открепления)
  void removeStudentLocally(String studentId) {
    final removed = _students.removeWhere((student) => student['id'] == studentId);
    if (removed) {
      notifyListeners();
    }
  }

  /// Добавляет ученика в список локально (если нужно)
  void addStudentLocally(Map<String, dynamic> student) {
    // Проверяем, нет ли уже такого ученика
    final index = _students.indexWhere((s) => s['id'] == student['id']);
    if (index != -1) {
      // Обновляем существующего
      _students[index] = student;
      notifyListeners();
    } else {
      // Добавляем нового
      _students.add(student);
      notifyListeners();
    }
  }

  /// Очищает ошибку
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLiveQuery();
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
