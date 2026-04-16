import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:convert';
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static String? _currentToken;
  static bool _isInitialized = false;
  static final StreamController<String> _notificationStream =
  StreamController<String>.broadcast();

  static Stream<String> get notificationStream => _notificationStream.stream;

  static Future<void> setupPush() async {
    if (_isInitialized) {
      print('ℹ️ [NOTIFY] Уже инициализировано, пропускаем');
      return;
    }

    print('🔔 [NOTIFY] Начало инициализации...');

    // 1. Настройка плагина локальных уведомлений
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTapped,
    );
    print('✅ [NOTIFY] Плагин инициализирован');

    // 2. Создание канала
    await _createHighImportanceChannel();

    // 3. ЗАПРОС РАЗРЕШЕНИЙ (ПЕРВЫМ ШАГОМ!)
    // Это критично для Android 13+, иначе токен может не прийти или пуши не показываться
    await _requestAllPermissions();

    // 4. Получение токена ТОЛЬКО ПОСЛЕ разрешений
    String? token = await _firebaseMessaging.getToken();
    print('[FCM] Получен токен: ${token != null ? "${token.substring(0, 10)}..." : "null"}');

    _currentToken = token;

    // 5. Сохранение токена, если пользователь уже залогинен
    if (token != null) {
      await saveTokenToServer(token);
    }

    // 6. Слушатели обновлений
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('[FCM] Токен обновлен: ${newToken.substring(0, 10)}...');
      _currentToken = newToken;
      await saveTokenToServer(newToken);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Проверка начального сообщения (если приложение открыто из убитого состояния по пушу)
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 [OPEN] Приложение запущено через пуш');
      _handleMessageOpenedApp(initialMessage);
    }

    _isInitialized = true;
    print('✅ [NOTIFY] Инициализация завершена');
  }

  static Future<void> saveTokenToServer(String? token) async {
    if (token == null) return;

    try {
      final currentUser = await ParseUser.currentUser() as ParseUser?;

      if (currentUser == null) {
        // Пользователь не залогинен, сохраняем в память, отправим при логине
        print('⚠️ [FCM] Пользователь не авторизован, токен сохранен в памяти');
        _currentToken = token;
        return;
      }

      final existingToken = currentUser.get('fcmToken');

      // Сравниваем, чтобы не делать лишних запросов к серверу
      if (existingToken == token) {
        return;
      }

      currentUser.set('fcmToken', token);
      final response = await currentUser.save();

      if (response.success) {
        print('✅ [FCM] Токен успешно сохранен в базу для ${currentUser.username}');
      } else {
        print('❌ [FCM] Ошибка сохранения: ${response.error?.message}');
      }
    } catch (e) {
      print('❌ [FCM] Исключение при сохранении: $e');
    }
  }

  // Вызывать этот метод сразу после успешного логина пользователя
  static Future<void> resendTokenIfLoggedIn() async {
    print('🔄 [FCM] Попытка отправить токен после логина...');

    // Если токен уже есть в памяти (получен ранее), отправляем его
    if (_currentToken != null) {
      await saveTokenToServer(_currentToken);
      return;
    }

    // Если токена нет, пробуем получить свежий
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      _currentToken = token;
      await saveTokenToServer(token);
    } else {
      print('⚠️ [FCM] Токен все еще недоступен, повторная попытка через 2 сек');
      Future.delayed(const Duration(seconds: 2), () async {
        final retryToken = await _firebaseMessaging.getToken();
        if (retryToken != null) {
          _currentToken = retryToken;
          await saveTokenToServer(retryToken);
        }
      });
    }
  }

  static Future<void> _createHighImportanceChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'lesson_channel',
      'Уроки и уведомления',
      description: 'Критические уведомления о занятиях',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  static Future<void> _requestAllPermissions() async {
    print('🔐 [PERMISSION] Запрос разрешений...');

    // Запрос разрешений iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    // Запрос разрешений Android 13+
    final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      bool? granted = await androidPlugin.requestNotificationsPermission();
      print('📢 [PERMISSION] Android Permission: ${granted == true ? "Granted" : "Denied"}');
    }

    final settings = await _firebaseMessaging.getNotificationSettings();
    print('📊 [STATUS] Authorization: ${settings.authorizationStatus.name}');
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    print('📩 [FOREGROUND] Сообщение получено: ${message.notification?.title}');
    _notificationStream.add(jsonEncode(message.data));
    _showLocalNotificationFromMessage(message);
  }

  static void onNotificationTapped(NotificationResponse response) {
    print('👆 [TAP] Нажатие на уведомление');
    // Здесь можно добавить навигацию на экран урока, распарсив response.payload
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('🚀 [OPEN] Приложение открыто из пуша');
    // Логика навигации при открытии приложения
  }

  static Future<void> _showLocalNotificationFromMessage(RemoteMessage message) async {
    String title = message.notification?.title ?? 'Уведомление';
    String body = message.notification?.body ?? '';

    // Дополнительная проверка данных, если они пришли в поле data
    if (message.data.containsKey('title')) {
      title = message.data['title']!;
    }
    if (message.data.containsKey('body') && body.isEmpty) {
      body = message.data['body']!;
    }

    if (body.isEmpty) body = "Новое событие";

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lesson_channel',
      'Уроки и уведомления',
      channelDescription: 'Критические уведомления',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  static String? getCurrentToken() => _currentToken;
  static bool isInitialized() => _isInitialized;
}