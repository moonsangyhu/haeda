import 'package:flutter/material.dart';

class NotificationsPlaceholderScreen extends StatelessWidget {
  const NotificationsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('알림 (준비 중)'),
      ),
    );
  }
}
