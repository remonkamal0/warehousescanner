import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'App/my_app.dart';
import 'core/constants/routes_managers.dart';
import 'providers/auth_provider.dart';
import 'providers/base_url_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) حضّر الـ providers
  final authProvider = AuthProvider();
  final baseUrlProvider = BaseUrlProvider();

  // 2) حمّل الداتا المخزنة قبل تشغيل التطبيق
  await Future.wait([
    authProvider.loadUser(),
    baseUrlProvider.loadBaseUrl(),
  ]);

  // 3) شغّل التطبيق
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<BaseUrlProvider>.value(value: baseUrlProvider),
      ],
      child: const MyApp(initialRoute: RoutesName.kLogin),
    ),
  );
}
