import 'package:flutter/material.dart';
import 'instructor_lessons_page.dart';
import 'instructor_students_page.dart';
import 'instructor_chats_page.dart';
import 'instructor_profile_page.dart';
import 'calendar_schedule_page.dart';

class InstructorHomePage extends StatefulWidget {
  @override
  _InstructorHomePageState createState() => _InstructorHomePageState();
}

class _InstructorHomePageState extends State<InstructorHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    InstructorLessonsPage(),
    InstructorStudentsPage(),
    InstructorChatsPage(),
    InstructorProfilePage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Занятия'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Ученики'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чаты'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'instructor_calendar',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CalendarSchedulePage(isInstructor: true)),
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