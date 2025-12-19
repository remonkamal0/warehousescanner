import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaseUrlProvider with ChangeNotifier {
  static const _key = "base_url";

  String _baseUrl = "";

  String get baseUrl => _baseUrl;

  bool get isReady => _baseUrl.trim().isNotEmpty;

  /// ترجع baseUrl من غير / في الآخر
  String get normalizedBaseUrl {
    var b = _baseUrl.trim();
    b = b.replaceAll(RegExp(r'/+$'), '');
    return b;
  }

  /// تبني endpoint بأمان:
  /// apiUrl("api/SalesOrder/GetSalesOrderFSC/1")
  String apiUrl(String path) {
    final b = normalizedBaseUrl;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return "$b/$p";
  }

  Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_key) ?? "";
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _baseUrl);
    notifyListeners();
  }

  Future<void> clearBaseUrl() async {
    _baseUrl = "";
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}
