import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'create_lesson_page.dart';

class SelectStudentForLessonPage extends StatefulWidget {
  @override
  _SelectStudentForLessonPageState createState() => _SelectStudentForLessonPageState();
}

class _SelectStudentForLessonPageState extends State<SelectStudentForLessonPage> {
  List<ParseUser> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final function = ParseCloudFunction('getMyStudents');
      final response = await function.execute();

      if (response.success && response.result != null) {
        final List<dynamic> results = response.result as List<dynamic>;
        final List<ParseUser> students = results.map((json) {
          final user = ParseUser(null, null, null);
          user.objectId = json['id'];
          user.set('surname', json['surname']);
          user.set('firstname', json['firstname']);
          user.set('patronymic', json['patronymic']);
          user.set('email', json['email']);
          user.set('phone', json['phone']);
          user.set('photo', json['photo']);
          return user;
        }).toList();

        setState(() {
          _students = students;
        });
      } else {
        setState(() {
          _error = response.error?.message ?? 'Ошибка загрузки';
        });
      }
    } catch (e) {
      setState(() {
        _error = (e).toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите ученика'),
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка: $_error', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _loadStudents,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _students.isEmpty
              ? const Center(
                  child: Text(
                    'У вас пока нет учеников',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  itemBuilder: (ctx, index) {
                    final student = _students[index];
                    final name = _getFullName(student);
                    final photoUrl = student.get('photo') as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                          child: photoUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0] : '?',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(name),
                        subtitle: Text(student.get('email') ?? ''),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateLessonPage(student: student),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
