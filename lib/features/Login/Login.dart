import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/color_managers.dart';
import '../../providers/auth_provider.dart';
import '../Home/HomeScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? selectedUser;
  final TextEditingController passwordController = TextEditingController();
  List<dynamic> users = []; // ✅ هنخزن اليوزر كامل علشان ناخد userID
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  /// جلب المستخدمين من الـ API
  Future<void> fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("http://irs.evioteg.com:8080/api/user"));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          users = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch users: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching users: $e")),
      );
    }
    setState(() => isLoading = false);
  }

  /// تسجيل الدخول
  Future<void> login() async {
    if (selectedUser != null && passwordController.text.isNotEmpty) {
      try {
        final user = users.firstWhere(
              (u) =>
          u["userName"] == selectedUser &&
              u["loginPassWord"] == passwordController.text &&
              u["inactive"] == 0,
          orElse: () => null,
        );

        if (user != null) {
          // ✅ خزن الـ userID في AuthProvider
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          authProvider.setUserID(user["userID"]);

          // ✅ تسجيل دخول ناجح → روح للهوم
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid username or password")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a user and enter password")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorManagers.kDarkBlue,
        centerTitle: true,
        title: Text(
          "Login",
          style: TextStyle(
            color: ColorManagers.kWhite,
            fontSize: isTablet ? 26 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? size.width * 0.2 : 20,
            vertical: 20,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ===== User Buttons =====
              ...users.map((u) {
                String userName = u["userName"].toString();
                bool isSelected = selectedUser == userName;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? Colors.blue.shade100
                          : Colors.white,
                      foregroundColor: Colors.blue.shade900,
                      side: const BorderSide(color: Colors.blue),
                      minimumSize:
                      Size(double.infinity, isTablet ? 60 : 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedUser = userName;
                      });
                    },
                    child: Text(
                      userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 20 : 16,
                        color: isSelected
                            ? Colors.blue.shade900
                            : Colors.blue,
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // ===== Password Field (only if user selected) =====
              if (selectedUser != null) ...[
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  obscuringCharacter: '•',
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: false, signed: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    // LengthLimitingTextInputFormatter(6),
                  ],
                  style: TextStyle(fontSize: isTablet ? 20 : 16),
                  decoration: InputDecoration(
                    hintText: "Password",
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: isTablet ? 18 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ===== Login Button =====
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    minimumSize:
                    Size(double.infinity, isTablet ? 60 : 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: login,
                  child: Text(
                    "Sign in",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 20 : 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
