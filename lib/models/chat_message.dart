import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isDeleted;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    required this.createdAt,
    this.isDeleted = false,
    this.editedAt,
  });

  factory ChatMessage.fromParseObject(ParseObject obj) {
    return ChatMessage(
      id: obj.objectId ?? '',
      senderId: obj.get('senderId') ?? '',
      receiverId: obj.get('receiverId') ?? '',
      text: obj.get('text') ?? '',
      imageUrl: obj.get('imageUrl'),
      createdAt: obj.get('createdAt') ?? DateTime.now(),
      isDeleted: obj.get('isDeleted') ?? false,
      editedAt: obj.get('editedAt'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'isDeleted': isDeleted,
      'editedAt': editedAt,
    };
  }
}

class ChatParticipant {
  final String userId;
  final String firstname;
  final String surname;
  final String? photoUrl;
  final DateTime? lastOnline;
  final bool isOnline;

  ChatParticipant({
    required this.userId,
    required this.firstname,
    required this.surname,
    this.photoUrl,
    this.lastOnline,
    this.isOnline = false,
  });

  String get fullName => '$firstname $surname'.trim();

  factory ChatParticipant.fromMap(Map<String, dynamic> map) {
    return ChatParticipant(
      userId: map['id'] ?? map['objectId'] ?? '',
      firstname: map['firstname'] ?? '',
      surname: map['surname'] ?? '',
      photoUrl: map['photo'],
      lastOnline: map['lastOnline'],
      isOnline: map['isOnline'] ?? false,
    );
  }
}
