import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';
import 'instructor_chat_detail_page.dart';

class InstructorChatsPage extends StatefulWidget {
  @override
  _InstructorChatsPageState createState() => _InstructorChatsPageState();
}

class _InstructorChatsPageState extends State<InstructorChatsPage> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _error;
  ParseUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    _currentUser = auth.currentUser;

    if (_currentUser == null) {
      setState(() {
        _error = 'Пользователь не авторизован';
        _isLoading = false;
      });
      return;
    }

    try {
      final chatList = await ChatService.getChatListForUser(_currentUser!.objectId!);
      
      // Получаем информацию о каждом собеседнике
      final chatsWithInfo = <Map<String, dynamic>>[];
      for (var chat in chatList) {
        final userId = chat['userId'] as String;
        final userInfo = await ChatService.getUserInfo(userId);
        if (userInfo != null) {
          chatsWithInfo.add({
            'user': userInfo,
            'lastMessage': chat['lastMessage'],
            'lastMessageTime': chat['lastMessageTime'],
          });
        }
      }

      // Сортируем по времени последнего сообщения
      chatsWithInfo.sort((a, b) {
        final timeA = a['lastMessageTime'] as DateTime;
        final timeB = b['lastMessageTime'] as DateTime;
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _chats = chatsWithInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'только что';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин. назад';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ч. назад';
    } else if (diff.inDays < 7) {
      const days = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      return days[time.weekday % 7];
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ошибка: $_error',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _loadChats,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : _chats.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет чатов\nЗдесь появятся диалоги с учениками',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        color: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _chats.length,
                          itemBuilder: (ctx, index) {
                            final chat = _chats[index];
                            final user = chat['user'] as ChatParticipant;
                            final lastMessage = chat['lastMessage'] as String;
                            final lastMessageTime = chat['lastMessageTime'] as DateTime;

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white24,
                                backgroundImage: user.photoUrl != null
                                    ? CachedNetworkImageProvider(user.photoUrl!)
                                    : null,
                                child: user.photoUrl == null
                                    ? Text(
                                        user.fullName.isNotEmpty 
                                            ? user.fullName[0] 
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatLastMessageTime(lastMessageTime),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                lastMessage,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InstructorChatDetailPage(
                                      participant: user,
                                    ),
                                  ),
                                ).then((_) => _loadChats());
                              },
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}