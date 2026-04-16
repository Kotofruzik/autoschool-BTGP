import 'dart:io';
import 'dart:convert'; // Для JSON
import 'package:minio/io.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:minio/minio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Импорт для HTTP запросов

class LessonService {
  // Константы вашего сервера
  static const String _serverUrl = 'https://parseapi.back4app.com';
  static const String _appId = 'qCxbZic6eqme0pvScG5jLoCxDUxztB9FGuiXhEiy';
  static const String _clientKey = '50yEotCNReUkwSd7nhVmhYnoZspmLcbizp1GJC3v';

  // --- Загрузка фото автомобиля ---
  Future<String?> uploadCarPhoto(XFile image) async {
    try {
      final file = File(image.path);
      const accessKey = 'YCAJEyTjVJ5hPHjDHwCdRFvqu';
      const secretKey = 'YCPsjstQHgXYSe0ZwRRl-fKFUCSnKMAj5WtyGJ4W';
      const bucket = 'autoschoolbtgp';
      const region = 'ru-central1';
      const endpoint = 'storage.yandexcloud.net';

      final minio = Minio(
        endPoint: endpoint,
        port: 443,
        useSSL: true,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
      );

      final key = 'lessons/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await minio.fPutObject(
        bucket,
        key,
        file.path,
        metadata: {'Content-Type': 'image/jpeg'},
      );

      final photoUrl = 'https://$endpoint/$bucket/$key';
      return photoUrl;
    } catch (e) {
      print('❌ Ошибка загрузки фото: $e');
      return null;
    }
  }

  // --- Отправка Push-уведомления через прямой HTTP запрос ---
  Future<void> sendLessonNotification({
    required String studentId,
    required String lessonType,
    required DateTime startTime,
    required String lessonId,
  }) async {
    try {
      print('🔔 [PUSH] Отправка уведомления ученику $studentId...');

      final url = Uri.parse('$_serverUrl/functions/sendLessonNotification');

      final payload = jsonEncode({
        'studentId': studentId,
        'lessonType': lessonType,
        'startTime': startTime.toIso8601String(),
        'lessonId': lessonId,
      });

      // Получаем текущий session token пользователя
      final user = await ParseUser.currentUser() as ParseUser?;
      final sessionToken = user?.sessionToken;

      if (sessionToken == null) {
        print('⚠️ [PUSH] Пользователь не авторизован, уведомление не отправлено.');
        return;
      }

      final response = await http.post(
        url,
        headers: {
          'X-Parse-Application-Id': _appId,
          'X-Parse-Client-Key': _clientKey,
          'X-Parse-Session-Token': sessionToken,
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        print('✅ [PUSH] Уведомление успешно отправлено через HTTP');
      } else {
        print('⚠️ [PUSH] Ошибка сервера (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ [PUSH] Исключение при вызове Cloud Function: $e');
    }
  }

  // --- Создание занятия ---
  Future<ParseObject?> createLesson({
    required String type,
    required DateTime startTime,
    required DateTime endTime,
    String? carBrand,
    String? carModel,
    String? carNumber,
    String? carPhotoUrl,
    String? comment,
    required ParseUser student,
    required ParseUser instructor,
  }) async {
    final lesson = ParseObject('Lesson')
      ..set('type', type)
      ..set('startTime', startTime)
      ..set('endTime', endTime)
      ..set('duration', endTime.difference(startTime).inMinutes)
      ..set('carBrand', carBrand)
      ..set('carModel', carModel)
      ..set('carNumber', carNumber)
      ..set('carPhoto', carPhotoUrl)
      ..set('comment', comment)
      ..set('student', student.toPointer())
      ..set('instructor', instructor.toPointer())
      ..set('status', 'scheduled')
      ..setACL(_createLessonACL(instructor, student));

    final response = await lesson.save();

    if (response.success) {
      final createdLesson = response.result as ParseObject;
      print('✅ Урок создан: ${createdLesson.objectId}');

      // 🚀 ОТПРАВЛЯЕМ УВЕДОМЛЕНИЕ СРАЗУ ПОСЛЕ СОЗДАНИЯ
      if (student.objectId != null && createdLesson.objectId != null) {
        await sendLessonNotification(
          studentId: student.objectId!,
          lessonType: type,
          startTime: startTime,
          lessonId: createdLesson.objectId!,
        );
      } else {
        print('⚠️ Не удалось отправить пуш: отсутствует objectId');
      }

      return createdLesson;
    } else {
      throw Exception(response.error!.message);
    }
  }

  ParseACL _createLessonACL(ParseUser instructor, ParseUser student) {
    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: false);
    acl.setPublicWriteAccess(allowed: false);
    acl.setReadAccess(userId: instructor.objectId!, allowed: true);
    acl.setWriteAccess(userId: instructor.objectId!, allowed: true);
    acl.setReadAccess(userId: student.objectId!, allowed: true);
    return acl;
  }

  // --- Получение занятий ученика ---
  Future<List<ParseObject>> getLessonsForStudent(ParseUser student) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Lesson'))
      ..whereEqualTo('student', student.toPointer())
      ..orderByAscending('startTime');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.cast<ParseObject>();
    } else {
      print('⚠️ Ошибка получения уроков студента: ${response.error?.message}');
      return [];
    }
  }

  // --- Получение занятий инструктора ---
  Future<List<ParseObject>> getLessonsForInstructor(ParseUser instructor) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Lesson'))
      ..whereEqualTo('instructor', instructor.toPointer())
      ..orderByAscending('startTime');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.cast<ParseObject>();
    } else {
      print('⚠️ Ошибка получения уроков инструктора: ${response.error?.message}');
      return [];
    }
  }

  // --- Отмена занятия ---
  Future<void> cancelLesson(ParseObject lesson) async {
    lesson.set('status', 'cancelled');
    final response = await lesson.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Не удалось отменить занятие');
    }
  }

  // --- Запрос переноса (ученик) ---
  Future<void> requestReschedule(ParseObject lesson, DateTime newStartTime, DateTime newEndTime, {String? reason}) async {
    lesson.set('rescheduleRequest', {
      'newStartTime': newStartTime.toIso8601String(),
      'newEndTime': newEndTime.toIso8601String(),
      'reason': reason,
    });
    lesson.set('status', 'reschedule_requested');
    final response = await lesson.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Не удалось запросить перенос');
    }
  }

  // --- Подтверждение переноса (инструктор) ---
  Future<void> approveReschedule(ParseObject lesson) async {
    final request = lesson.get<Map<String, dynamic>>('rescheduleRequest');
    if (request != null) {
      lesson.set('startTime', DateTime.parse(request['newStartTime']));
      lesson.set('endTime', DateTime.parse(request['newEndTime']));
      lesson.set('duration', DateTime.parse(request['newEndTime']).difference(DateTime.parse(request['newStartTime'])).inMinutes);
      lesson.set('rescheduleRequest', null);
      lesson.set('status', 'scheduled');

      final response = await lesson.save();
      if (!response.success) {
        throw Exception(response.error?.message ?? 'Не удалось подтвердить перенос');
      }
    }
  }

  // --- Отклонение переноса (инструктор) ---
  Future<void> rejectReschedule(ParseObject lesson) async {
    lesson.set('rescheduleRequest', null);
    lesson.set('status', 'scheduled');
    final response = await lesson.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Не удалось отклонить перенос');
    }
  }

  // --- Удаление занятия ---
  Future<void> deleteLesson(ParseObject lesson) async {
    final response = await lesson.delete();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Не удалось удалить занятие');
    }
  }
}