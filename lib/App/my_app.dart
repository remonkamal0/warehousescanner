import 'package:flutter/material.dart';
import '../core/constants/routes_managers.dart';

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: RoutesManagers.routes,
    );
  }
}
