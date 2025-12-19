import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'App/my_app.dart';
import 'core/constants/routes_managers.dart';
import 'providers/auth_provider.dart';
import 'providers/base_url_provider.dart'; // 👈 استيراد البروفايدر الجديد

void main() async {
  // ضروري علشان نستخدم SharedPreferences قبل تشغيل الابلكيشن
  WidgetsFlutterBinding.ensureInitialized();

  // تحميل الـ Base URL المحفوظ
  final baseUrlProvider = BaseUrlProvider();
  await baseUrlProvider.loadBaseUrl();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),  // بروفايدر اليوزر
        ChangeNotifierProvider(create: (_) => baseUrlProvider), // 👈 بروفايدر الـ Base URL
      ],
      child: const MyApp(initialRoute: RoutesName.kLogin),
    ),
  );
}
