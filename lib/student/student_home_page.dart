import 'package:autoschool_btgp/student/student_my_lessons_page.dart';
import 'package:flutter/material.dart';
import 'student_my_lessons_page.dart';
import 'student_chats_page.dart';
import 'student_profile_page.dart';

class StudentHomePage extends StatefulWidget {
  @override
  _StudentHomePageState createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _selectedIndex = 0;

  // Ключ для пересоздания страницы занятий при необходимости
  Key _lessonsPageKey = UniqueKey();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onProfileChanged(bool? changed) {
    if (changed == true && mounted) {
      // Обновляем страницу занятий после открепления от инструктора
      setState(() {
        _selectedIndex = 0;
        _lessonsPageKey = UniqueKey(); // Создаём новый ключ для пересоздания виджета
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      StudentMyLessonsPage(key: _lessonsPageKey),
      StudentChatsPage(),
      StudentProfilePage(onDetach: _onProfileChanged),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
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
    );
  }
}