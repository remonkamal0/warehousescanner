import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  int? _userID;

  int? get userID => _userID;
  bool get isLoggedIn => _userID != null;

  /// تحميل اليوزر من التخزين
  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userID = prefs.getInt('user_id');
    notifyListeners();
  }

  /// حفظ اليوزر
  Future<void> setUserID(int id) async {
    _userID = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', id);
    notifyListeners();
  }

  /// تسجيل خروج
  Future<void> clearUser() async {
    _userID = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }
}
