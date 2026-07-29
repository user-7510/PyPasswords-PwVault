import 'package:flutter/material.dart';

import 'screens/profile_screen.dart';

void main() {
  runApp(const PwVaultApp());
}

class PwVaultApp extends StatelessWidget {
  const PwVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '密碼管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ProfileScreen(),
    );
  }
}
