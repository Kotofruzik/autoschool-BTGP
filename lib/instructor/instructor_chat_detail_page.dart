import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:parse_live_query/parse_live_query.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';

class InstructorChatDetailPage extends StatefulWidget {
  final ChatParticipant participant;

  const InstructorChatDetailPage({Key? key, required this.participant}) : super(key: key);

  @override
  _InstructorChatDetailPageState createState() => _InstructorChatDetailPageState();
}

class _InstructorChatDetailPageState extends State<InstructorChatDetailPage> {
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ParseUser? _currentUser;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    _currentUser = auth.currentUser;

    if (_currentUser == null) {
      setState(() {
        _error = 'Пользователь не авторизован';
        _isLoading = false;
      });
      return;
    }

    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (_currentUser == null) return;
    
    final messages = await ChatService.getChatMessages(
      _currentUser!.objectId!,
      widget.participant.userId,
    );
    
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
      _subscribeToNewMessages();
    }
  }

  void _subscribeToNewMessages() {
    _messagesSubscription?.cancel();
    
    try {
      final client = ParseLiveQueryClient();
      
      final query1 = QueryBuilder<ParseObject>(ParseObject('ChatMessage'))
        ..whereEqualTo('senderId', _currentUser!.objectId!)
        ..whereEqualTo('receiverId', widget.participant.userId);
      
      final query2 = QueryBuilder<ParseObject>(ParseObject('ChatMessage'))
        ..whereEqualTo('senderId', widget.participant.userId)
        ..whereEqualTo('receiverId', _currentUser!.objectId!);
      
      client.subscribe(query1).then((subscription) {
        subscription.on(ParseLiveQueryEvent.create, (obj) {
          if (!mounted) return;
          final message = ChatMessage.fromParseObject(obj as ParseObject);
          if (!message.isDeleted && !_messages.any((m) => m.id == message.id)) {
            setState(() {
              _messages.add(message);
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _scrollToBottom();
          }
        });
      });
      
      client.subscribe(query2).then((subscription) {
        subscription.on(ParseLiveQueryEvent.create, (obj) {
          if (!mounted) return;
          final message = ChatMessage.fromParseObject(obj as ParseObject);
          if (!message.isDeleted && !_messages.any((m) => m.id == message.id)) {
            setState(() {
              _messages.add(message);
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
            _scrollToBottom();
          }
        });
      });
    } catch (e) {
      print('Ошибка подписки на LiveQuery: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    final message = await ChatService.sendMessage(
      senderId: _currentUser!.objectId!,
      receiverId: widget.participant.userId,
      text: text,
    );

    if (message != null && mounted) {
      setState(() {
        _messages.add(message);
      });
      _messageController.clear();
      _scrollToBottom();
    }
  }

  Future<void> _sendPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null || _currentUser == null) return;

    final imageUrl = await ChatService.uploadChatPhoto(image, _currentUser!.objectId!);
    
    if (imageUrl != null) {
      final message = await ChatService.sendMessage(
        senderId: _currentUser!.objectId!,
        receiverId: widget.participant.userId,
        text: '',
        imageUrl: imageUrl,
      );

      if (message != null && mounted) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    }
  }

  void _showMessageOptions(ChatMessage message, int index) {
    final isMyMessage = message.senderId == _currentUser?.objectId;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (isMyMessage) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message, index);
                },
              ),
            ],
            if (message.imageUrl != null)
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Открыть фото'),
                onTap: () {
                  Navigator.pop(ctx);
                  _viewPhoto(message.imageUrl!);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать сообщение'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Введите текст'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != message.text) {
      final success = await ChatService.editMessage(message.id, result);
      if (success && mounted) {
        setState(() {
          final msgIndex = _messages.indexWhere((m) => m.id == message.id);
          if (msgIndex != -1) {
            _messages[msgIndex] = ChatMessage(
              id: message.id,
              senderId: message.senderId,
              receiverId: message.receiverId,
              text: result,
              imageUrl: message.imageUrl,
              createdAt: message.createdAt,
              editedAt: DateTime.now(),
            );
          }
        });
      }
    }
  }

  Future<void> _deleteMessage(ChatMessage message, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ChatService.deleteMessage(message.id);
      if (success && mounted) {
        setState(() {
          _messages[index] = ChatMessage(
            id: message.id,
            senderId: message.senderId,
            receiverId: message.receiverId,
            text: 'Сообщение удалено',
            imageUrl: null,
            createdAt: message.createdAt,
            isDeleted: true,
          );
        });
      }
    }
  }

  void _viewPhoto(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatLastOnline(DateTime? lastOnline) {
    if (lastOnline == null) return 'был(а) недавно';
    final now = DateTime.now();
    final diff = now.difference(lastOnline);
    
    if (diff.inMinutes < 1) return 'в сети';
    if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч. назад';
    return 'был(а) ${_formatTime(lastOnline)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: widget.participant.photoUrl != null
                  ? CachedNetworkImageProvider(widget.participant.photoUrl!)
                  : null,
              child: widget.participant.photoUrl == null
                  ? Text(
                      widget.participant.fullName.isNotEmpty 
                          ? widget.participant.fullName[0] 
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.participant.fullName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.participant.isOnline 
                      ? 'в сети' 
                      : _formatLastOnline(widget.participant.lastOnline),
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.participant.isOnline ? Colors.greenAccent : Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'Нет сообщений\nНачните диалог с учеником!',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (ctx, index) {
                                  final message = _messages[index];
                                  final isMyMessage = message.senderId == _currentUser?.objectId;
                                  
                                  return GestureDetector(
                                    onLongPress: () => _showMessageOptions(message, index),
                                    child: Align(
                                      alignment: isMyMessage 
                                          ? Alignment.centerRight 
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.all(12),
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMyMessage 
                                              ? Colors.white 
                                              : Colors.white.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (message.imageUrl != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  message.imageUrl!,
                                                  width: 200,
                                                  height: 200,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (ctx, child, progress) {
                                                    if (progress == null) return child;
                                                    return const SizedBox(
                                                      width: 200,
                                                      height: 200,
                                                      child: Center(
                                                        child: CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            if (message.imageUrl != null && message.text.isNotEmpty)
                                              const SizedBox(height: 8),
                                            if (message.text.isNotEmpty)
                                              Text(
                                                message.isDeleted 
                                                    ? message.text 
                                                    : message.text,
                                                style: TextStyle(
                                                  color: message.isDeleted 
                                                      ? Colors.grey 
                                                      : Colors.black87,
                                                  fontStyle: message.editedAt != null 
                                                      ? FontStyle.italic 
                                                      : FontStyle.normal,
                                                ),
                                              ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _formatTime(message.createdAt),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                if (message.editedAt != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4),
                                                    child: Text(
                                                      '(ред.)',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.white,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.blue),
                              onPressed: _sendPhoto,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Введите сообщение...',
                                  border: InputBorder.none,
                                ),
                                maxLines: 4,
                                minLines: 1,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.blue),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
