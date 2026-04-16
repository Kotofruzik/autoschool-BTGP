import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import 'package:autoschool_btgp/admin/admin_profile_page.dart';
import 'package:autoschool_btgp/admin/users_page.dart'; // убедитесь, что файл существует

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    UsersPage(),
    const Center(child: Text('Чаты (скоро)')),
    const Center(child: Text('Статистика (скоро)')),
    AdminProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Пользователи'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Чаты'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Статистика'),
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