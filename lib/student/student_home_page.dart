import 'package:autoschool_btgp/student/student_my_lessons_page.dart';
import 'package:flutter/material.dart';
import 'student_my_lessons_page.dart';
import 'student_chats_page.dart';
import 'student_profile_page.dart';
import '../instructor/calendar_schedule_page.dart';

class StudentHomePage extends StatefulWidget {
  @override
  _StudentHomePageState createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    StudentMyLessonsPage(),
    StudentChatsPage(),
    StudentProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Мои занятия'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чаты'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'student_calendar',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CalendarSchedulePage(isInstructor: false)),
          );
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        icon: const Icon(Icons.calendar_today),
        label: const Text('Календарь'),
      ),
    );
  }
}