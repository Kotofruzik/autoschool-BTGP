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

  // Подписка на новые сообщения в реальном времени (не используется, polling вместо LiveQuery)
  // static dynamic _subscription;
  
  // Получить чат между двумя пользователями
  static Future<List<ChatMessage>> getChatMessages(String userId1, String userId2, {int limit = 50}) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject(_className))
        ..whereContainedIn('senderId', [userId1, userId2])
        ..whereContainedIn('receiverId', [userId1, userId2])
        ..orderByDescending('createdAt')
        ..setLimit(limit);

      final response = await query.query();
      if (response.success && response.results != null) {
        final messages = response.results!
            .map((obj) => ChatMessage.fromParseObject(obj as ParseObject))
            .toList();
        return messages.reversed.toList();
      }
      return [];
    } catch (e) {
      print('Ошибка загрузки сообщений: $e');
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
      final obj = ParseObject(_className);
      obj.set('senderId', senderId);
      obj.set('receiverId', receiverId);
      obj.set('text', text);
      if (imageUrl != null) {
        obj.set('imageUrl', imageUrl);
      }
      obj.set('isDeleted', false);
      obj.set('createdAt', DateTime.now());

      final response = await obj.save();
      if (response.success) {
        return ChatMessage(
          id: obj.objectId ?? '',
          senderId: senderId,
          receiverId: receiverId,
          text: text,
          imageUrl: imageUrl,
          createdAt: obj.get('createdAt') ?? DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Ошибка отправки сообщения: $e');
      return null;
    }
  }

  // Подписаться на новые сообщения в реальном времени
  static Future<void> subscribeToMessages({
    required String userId1,
    required String userId2,
    required Function(ChatMessage) onNewMessage,
  }) async {
    try {
      // LiveQuery не поддерживается в текущей версии parse_server_sdk
      // Используем polling как временное решение
      print('ℹ️ LiveQuery недоступен, используем периодическую проверку');
      
      // Запускаем периодическую проверку новых сообщений каждые 3 секунды
      Timer.periodic(const Duration(seconds: 3), (timer) async {
        final messages = await getChatMessages(userId1, userId2, limit: 1);
        if (messages.isNotEmpty) {
          onNewMessage(messages.last);
        }
      });

      print('✅ Подписка на сообщения активирована для $userId1 <-> $userId2');
    } catch (e) {
      print('❌ Ошибка подписки на сообщения: $e');
    }
  }

  // Отписаться от сообщений
  static void unsubscribeFromMessages() {
    print('🔕 Подписка на сообщения отменена');
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
      final query = QueryBuilder<ParseObject>(ParseObject('_User'))
        ..whereEqualTo('objectId', userId);
      final response = await query.query();

      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final user = response.results!.first as ParseObject;
        return ChatParticipant.fromMap({
          'id': user.objectId,
          'firstname': user.get('firstname'),
          'surname': user.get('surname'),
          'photo': user.get('photo'),
          'lastOnline': user.get('lastOnline'),
          'isOnline': user.get('isOnline') ?? false,
        });
      }
      return null;
    } catch (e) {
      print('Ошибка получения информации о пользователе: $e');
      return null;
    }
  }
}