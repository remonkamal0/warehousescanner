import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 استيراد البروفايدر
import 'App/my_app.dart';
import 'core/constants/routes_managers.dart';
import 'providers/auth_provider.dart'; // 👈 مكان ما هتحط ملف البروفايدر

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()), // 👈 بروفايدر اليوزر
      ],
      child: const MyApp(initialRoute: RoutesName.kLogin), // 👈 زي ما هو
    ),
  );
}
