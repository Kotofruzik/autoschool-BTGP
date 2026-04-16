import 'package:autoschool_btgp/notification_service.dart';
import 'package:autoschool_btgp/services/users_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/login_page.dart';
import 'package:autoschool_btgp/services/register_page.dart';
import 'package:autoschool_btgp/services/photo_upload_page.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import 'package:autoschool_btgp/student/student_home_page.dart';
import 'package:autoschool_btgp/instructor/instructor_home_page.dart';
import 'package:autoschool_btgp/admin/admin_home_page.dart';
import 'dart:convert';

// ВАЖНО: Эта функция должна быть на верхнем уровне и иметь аннотацию
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 [BG-START] ${DateTime.now()} | Фоновое сообщение получено');
  print('🆔 [BG-ID] MessageID: ${message.messageId}');
  print('📝 [BG-DATA] Data: ${message.data}');

  // Гарантированная инициализация Firebase в фоне
  await Firebase.initializeApp();

  // Показываем уведомление напрямую без вызова setupPush()
  // Это предотвращает конфликты инициализации в фоновом режиме
  await _showBackgroundNotification(message);

  print('✅ [BG-SUCCESS] Обработка завершена');
}

Future<void> _showBackgroundNotification(RemoteMessage message) async {
  String title = message.notification?.title ?? 'Новое уведомление';
  String body = message.notification?.body ?? '';

  // Парсинг вложенных данных от Back4App
  if (message.data.isNotEmpty) {
    try {
      if (message.data.containsKey('data')) {
        var innerData = jsonDecode(message.data['data']);
        if (innerData['title'] != null) title = innerData['title'];
        if (innerData['body'] != null) body = innerData['body'];
      } else if (message.data.containsKey('title')) {
        title = message.data['title'];
        body = message.data['body'] ?? '';
      }
    } catch (e) {
      print('⚠️ [BG-PARSE] Ошибка: $e');
    }
  }

  if (body.isEmpty) body = "Нажмите для просмотра";

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Инициализация только если нужна (в фоне контекст ограничен)
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  // Игнорируем ошибки инициализации в фоне, если плагин уже инициализирован
  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (_) {}

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'lesson_channel',
    'Уроки и уведомления',
    channelDescription: 'Критические уведомления',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    autoCancel: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    details,
    payload: jsonEncode(message.data),
  );
  print('✅ [BG-SHOW] Уведомление показано: $title');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const keyApplicationId = 'qCxbZic6eqme0pvScG5jLoCxDUxztB9FGuiXhEiy';
  const keyClientKey = '50yEotCNReUkwSd7nhVmhYnoZspmLcbizp1GJC3v';
  const keyServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(
    keyApplicationId,
    keyServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
    debug: true,
  );

  await Firebase.initializeApp();

  // Регистрация фонового обработчика - ДО инициализации уведомлений
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  print('✅ [MAIN] Фоновый обработчик зарегистрирован');

  // Инициализация уведомлений и запрос разрешений
  await NotificationService.setupPush();
  
  // Проверка токена после инициализации
  final token = NotificationService.getCurrentToken();
  print('🔑 [MAIN] Текущий токен: $token');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
      ],
      child: MaterialApp(
        title: 'Автошкола',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(),
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterPage(),
          '/photo-upload': (context) => PhotoUploadPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _currentRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determineRole();
  }

  Future<void> _determineRole() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    
    // Ждем пока AuthService загрузит текущего пользователя
    if (auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _currentRole = null;
      });
      return;
    }

    // Получаем актуальные данные пользователя с сервера
    try {
      final query = QueryBuilder<ParseUser>(ParseUser.forQuery())
        ..whereEqualTo('objectId', auth.currentUser!.objectId);
      final response = await query.query();
      
      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final updatedUser = response.results!.first as ParseUser;
        _currentRole = updatedUser.get('role') ?? 'student';
        // Обновляем роль в локальном пользователе
        auth.currentUser!.set('role', _currentRole);
      } else {
        _currentRole = auth.currentUser!.get('role') ?? 'student';
      }
    } catch (e) {
      print('⚠️ Ошибка получения роли: $e');
      _currentRole = auth.currentUser!.get('role') ?? 'student';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.currentUser != null && auth.currentUser!.sessionToken != null) {
      switch (_currentRole) {
        case 'admin':
          return AdminHomePage();
        case 'instructor':
          return InstructorHomePage();
        case 'student':
        default:
          return StudentHomePage();
      }
    }
    return LoginPage();
  }
}
