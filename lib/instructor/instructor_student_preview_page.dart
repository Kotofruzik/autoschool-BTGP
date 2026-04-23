import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InstructorStudentPreviewPage extends StatelessWidget {
  final ParseUser student;
  const InstructorStudentPreviewPage({Key? key, required this.student}) : super(key: key);

  String _getFullName(ParseUser user) {
    String surname = user.get('surname') ?? '';
    String firstname = user.get('firstname') ?? '';
    String patronymic = user.get('patronymic') ?? '';
    List<String> parts = [surname, firstname, patronymic].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return user.get('email')?.split('@')[0] ?? 'Ученик';
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = student.get('photo') as String?;
    final phone = student.get('phone') as String? ?? 'Не указан';
    final email = student.get('email') as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль ученика'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 60, color: Colors.blue)
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  _getFullName(student),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(phone, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(email, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: чат
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Чат'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/create-lesson',
                          arguments: {'student': student, 'skipStudentStep': true},
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Назначить занятие'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}