import 'package:flutter/material.dart';
import '../../core/constants/color_managers.dart';
import '../Home/HomeScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? selectedUser;
  final TextEditingController passwordController = TextEditingController();

  final List<String> users = ["User 01", "User 02", "User 03", "User 04"];

  void login() {
    if (selectedUser != null && passwordController.text.isNotEmpty) {
      // ✅ لو الباسورد موجود واليوزر متحدد
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a user and enter password")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size; // أبعاد الشاشة
    final isTablet = size.width > 600; // لو العرض أكبر من 600 يبقى تابلت

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorManagers.kDarkBlue,
        centerTitle: true, // يخلي العنوان في النص
        title: Text(
          "Login",
          style: TextStyle(
            color: ColorManagers.kWhite,
            fontSize: isTablet ? 26 : 20, // حجم الخط حسب الشاشة
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? size.width * 0.2 : 20, // مسافة جانبية نسبية
            vertical: 20,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ===== User Buttons =====
              ...users.map((user) {
                bool isSelected = selectedUser == user;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      isSelected ? Colors.blue.shade100 : Colors.white,
                      foregroundColor: Colors.blue.shade900,
                      side: const BorderSide(color: Colors.blue),
                      minimumSize: Size(double.infinity, isTablet ? 60 : 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedUser = user;
                      });
                    },
                    child: Text(
                      user,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 20 : 16,
                        color: isSelected ? Colors.blue.shade900 : Colors.blue,
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
                    minimumSize: Size(double.infinity, isTablet ? 60 : 50),
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
