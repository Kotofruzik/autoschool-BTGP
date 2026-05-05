import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:minio/minio.dart';
import '../models/chat_message.dart';

class ChatService {
  static const String _className = 'ChatMessage';

  static const String _accessKey = 'YCAJEyTjVJ5hPHjDHwCdRFvqu';
  static const String _secretKey = 'YCPsjstQHgXYSe0ZwRRl-fKFUCSnKMAj5WtyGJ4W';
  static const String _bucket = 'autoschoolbtgp';
  static const String _region = 'ru-central1';
  static const String _endpoint = 'storage.yandexcloud.net';

  // Получить чат между двумя пользователями
  static Future<List<ChatMessage>> getChatMessages(String userId1, String userId2, {int limit = 100}) async {
    try {
      print('📩 [CHAT] Загрузка сообщений между $userId1 и $userId2');
      
      // Получаем сообщения где (senderId=userId1 AND receiverId=userId2)
      final query1 = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereEqualTo('senderId', userId1)
        ..whereEqualTo('receiverId', userId2)
        ..orderByAscending('createdAt')
        ..setLimit(limit);

      final response1 = await query1.query();
      print('📩 [CHAT] Запрос 1: success=${response1.success}, count=${response1.results?.length ?? 0}');
      
      // Получаем сообщения где (senderId=userId2 AND receiverId=userId1)
      final query2 = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereEqualTo('senderId', userId2)
        ..whereEqualTo('receiverId', userId1)
        ..orderByAscending('createdAt')
        ..setLimit(limit);

      final response2 = await query2.query();
      print('📩 [CHAT] Запрос 2: success=${response2.success}, count=${response2.results?.length ?? 0}');
      
      List<ChatMessage> messages = [];
      
      if (response1.success && response1.results != null) {
        messages.addAll(response1.results!
            .map((obj) => ChatMessage.fromParseObject(obj as ParseObject))
            .toList());
      }
      
      if (response2.success && response2.results != null) {
        messages.addAll(response2.results!
            .map((obj) => ChatMessage.fromParseObject(obj as ParseObject))
            .toList());
      }
      
      // Сортируем по времени создания (от старых к новым)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      print('📩 [CHAT] Всего сообщений: ${messages.length}');
      return messages;
    } catch (e, stackTrace) {
      print('❌ [CHAT] Ошибка загрузки сообщений: $e');
      print('❌ [CHAT] Stack trace: $stackTrace');
      return [];
    }
  }

  // Отправить сообщение
  static Future<ChatMessage?> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
  }) async {
    try {
      print('📤 [CHAT] Отправка сообщения от $senderId к $receiverId: $text');
      
      final obj = ParseObject(_className);
      obj.set('senderId', senderId);
      obj.set('receiverId', receiverId);
      obj.set('text', text);
      if (imageUrl != null) {
        obj.set('imageUrl', imageUrl);
      }
      obj.set('isDeleted', false);

      final response = await obj.save();
      
      print('🔍 [CHAT] Response success: ${response.success}');
      print('🔍 [CHAT] Response error: ${response.error}');
      print('🔍 [CHAT] Object objectId after save: ${obj.objectId}');
      print('🔍 [CHAT] Object createdAt after save: ${obj.get('createdAt')}');
      
      if (response.success && obj.objectId != null) {
        // После save() объект obj должен содержать objectId и createdAt
        final now = DateTime.now();
        final createdAt = obj.get('createdAt') as DateTime? ?? now;
        print('✅ [CHAT] Сообщение успешно отправлено, objectId: ${obj.objectId}');
        return ChatMessage(
          id: obj.objectId!,
          senderId: senderId,
          receiverId: receiverId,
          text: text,
          imageUrl: imageUrl,
          createdAt: createdAt,
        );
      } else {
        print('❌ [CHAT] Ошибка отправки: ${response.error?.message ?? "objectId is null"}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ [CHAT] Ошибка отправки сообщения: $e');
      print('❌ [CHAT] Stack trace: $stackTrace');
      return null;
    }
  }

  // Редактировать сообщение
  static Future<bool> editMessage(String messageId, String newText) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereEqualTo('objectId', messageId);
      final response = await query.query();

      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final obj = response.results!.first as ParseObject;
        obj.set('text', newText);
        obj.set('editedAt', DateTime.now());

        final saveResponse = await obj.save();
        return saveResponse.success;
      }
      return false;
    } catch (e) {
      print('Ошибка редактирования сообщения: $e');
      return false;
    }
  }

  // Удалить сообщение (мягкое удаление)
  static Future<bool> deleteMessage(String messageId) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereEqualTo('objectId', messageId);
      final response = await query.query();

      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final obj = response.results!.first as ParseObject;
        obj.set('isDeleted', true);
        obj.set('text', 'Сообщение удалено');

        final saveResponse = await obj.save();
        return saveResponse.success;
      }
      return false;
    } catch (e) {
      print('Ошибка удаления сообщения: $e');
      return false;
    }
  }

  // Загрузить фото в чат
  static Future<String?> uploadChatPhoto(XFile image, String userId) async {
    try {
      final file = File(image.path);
      final minio = Minio(
        endPoint: _endpoint,
        port: 443,
        useSSL: true,
        accessKey: _accessKey,
        secretKey: _secretKey,
        region: _region,
      );

      final key = 'chats/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileData = await file.readAsBytes();
      final stream = Stream.fromFuture(Future.value(fileData));
      await minio.putObject(
        _bucket,
        key,
        stream,
        metadata: {'Content-Type': 'image/jpeg'},
      );

      final photoUrl = 'https://$_endpoint/$_bucket/$key';
      print('✅ Фото чата загружено: $photoUrl');
      return photoUrl;
    } catch (e) {
      print('❌ Ошибка загрузки фото чата: $e');
      return null;
    }
  }

  // Получить последнего собеседника для пользователя
  static Future<List<Map<String, dynamic>>> getChatListForUser(String userId) async {
    try {
      // Получаем все сообщения где пользователь является отправителем
      final query1 = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereEqualTo('senderId', userId)
        ..orderByDescending('createdAt');

      final response1 = await query1.query();

      // Получаем все сообщения где пользователь является получателем
      final query2 = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereEqualTo('receiverId', userId)
        ..orderByDescending('createdAt');

      final response2 = await query2.query();

      final allMessages = <ParseObject>[];
      if (response1.success && response1.results != null) {
        allMessages.addAll(response1.results!.cast<ParseObject>());
      }
      if (response2.success && response2.results != null) {
        allMessages.addAll(response2.results!.cast<ParseObject>());
      }

      if (allMessages.isEmpty) {
        return [];
      }

      // Группируем по собеседнику
      Map<String, Map<String, dynamic>> chatMap = {};

      for (var obj in allMessages) {
        final senderId = obj.get('senderId') as String;
        final receiverId = obj.get('receiverId') as String;
        final otherUserId = senderId == userId ? receiverId : senderId;

        final messageText = obj.get('text') as String;
        final isDeleted = obj.get('isDeleted') as bool? ?? false;
        final createdAt = obj.get('createdAt') as DateTime? ?? DateTime.now();
        final imageUrl = obj.get('imageUrl') as String?;

        if (!chatMap.containsKey(otherUserId)) {
          chatMap[otherUserId] = {
            'userId': otherUserId,
            'lastMessage': isDeleted ? 'Сообщение удалено' : (imageUrl != null ? '📷 Фото' : messageText),
            'lastMessageTime': createdAt,
            'unreadCount': 0,
          };
        } else {
          // Обновляем только если сообщение новее
          if (createdAt.isAfter(chatMap[otherUserId]!['lastMessageTime'] as DateTime)) {
            chatMap[otherUserId]!['lastMessage'] = isDeleted ? 'Сообщение удалено' : (imageUrl != null ? '📷 Фото' : messageText);
            chatMap[otherUserId]!['lastMessageTime'] = createdAt;
          }
        }
      }

      return chatMap.values.toList();
    } catch (e) {
      print('Ошибка получения списка чатов: $e');
      return [];
    }
  }

  // Обновить статус онлайн
  static Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('_User'))
        ..whereEqualTo('objectId', userId);
      final response = await query.query();

      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final user = response.results!.first as ParseObject;
        user.set('isOnline', isOnline);
        if (!isOnline) {
          user.set('lastOnline', DateTime.now());
        }
        await user.save();
      }
    } catch (e) {
      print('Ошибка обновления статуса: $e');
    }
  }

  // Получить информацию о пользователе
  static Future<ChatParticipant?> getUserInfo(String userId) async {
    try {
      print('👤 [CHAT] Получение информации о пользователе: $userId');
      
      final query = QueryBuilder<ParseObject>(ParseObject('_User'))
        ..whereEqualTo('objectId', userId);
      final response = await query.query();

      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final user = response.results!.first as ParseObject;
        final participant = ChatParticipant.fromMap({
          'id': user.objectId,
          'firstname': user.get('firstname'),
          'surname': user.get('surname'),
          'photo': user.get('photo'),
          'lastOnline': user.get('lastOnline'),
          'isOnline': user.get('isOnline') ?? false,
        });
        print('✅ [CHAT] Информация получена: ${participant.fullName}');
        return participant;
      }
      print('⚠️ [CHAT] Пользователь не найден');
      return null;
    } catch (e, stackTrace) {
      print('❌ [CHAT] Ошибка получения информации о пользователе: $e');
      print('❌ [CHAT] Stack trace: $stackTrace');
      return null;
    }
  }
}