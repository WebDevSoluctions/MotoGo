import 'package:flutter/material.dart';

import 'screens/admin/admin_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminHomeScreen(),
    ),
  );
}
