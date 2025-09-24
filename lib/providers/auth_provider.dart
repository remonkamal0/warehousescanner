import 'package:flutter/foundation.dart';

class AuthProvider with ChangeNotifier {
  int? _userID;

  int? get userID => _userID;

  void setUserID(int id) {
    _userID = id;
    notifyListeners(); // علشان أي widget سامعة تتحدث
  }

  void clearUser() {
    _userID = null;
    notifyListeners();
  }
}
