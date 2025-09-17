import 'package:flutter/material.dart';
import '../../features/Get S.O.s/Get S.O.s.dart';
import '../../features/Home/HomeScreen.dart';
import '../../features/Login/Login.dart';
import '../../features/Re-Scan S.O.s/Re-Scan S.O.s.dart';
import '../../features/ReScanScreen/ReScanScreen.dart';
import '../../features/ScanScreen/ScanScreen.dart';
import '../../features/SendSOSScreen/SendSOSScreen.dart';


class RoutesName {
  static const String kLogin = '/login';
  static const String kHomeScreen = '/HomeScreen';
  static const String kGetSOSScreen = '/GetSOSScreen';
  static const String kSendSOSScreen = '/SendSOSScreen';
  static const String kScanScreen = '/ScanScreen';
  static const String kReScanScreen = '/ReScanScreen';
  static const String kReScanSOSScreen = '/ReScanSOSScreen';


}

class RoutesManagers {
  static final Map<String, WidgetBuilder> routes = {
    RoutesName.kLogin: (_) => const LoginScreen(),
    RoutesName.kHomeScreen: (_) => const HomeScreen(),
    RoutesName.kGetSOSScreen: (_) => const GetSOSScreen(),
    RoutesName.kSendSOSScreen: (_) => const SendSOSScreen(),
    RoutesName.kReScanSOSScreen: (_) => const ReScanSOSScreen(),
    RoutesName.kReScanScreen: (_) => const ReScanScreen(soNumber: '',),
    RoutesName.kScanScreen: (_) =>  ScanScreen(soNumber: 'soNumber', txnID: '',),


  };
}