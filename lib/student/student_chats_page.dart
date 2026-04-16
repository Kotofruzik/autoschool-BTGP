import 'package:flutter/material.dart';

class StudentChatsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue, Colors.lightBlueAccent],
        ),
      ),
      child: const Center(
        child: Text('Чаты (скоро)', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}