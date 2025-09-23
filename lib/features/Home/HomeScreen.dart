import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Get S.O.s/Get S.O.s.dart';
import '../Re-Scan S.O.s/Re-Scan S.O.s.dart';
// import '../SendSOSScreen/SendSOSScreen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    // قياسات مرنة
    final btnHeight = isTablet ? 64.0 : 56.0;
    final btnRadius = isTablet ? 18.0 : 16.0;
    final fontSize = isTablet ? 22.0 : 18.0;
    final gap = isTablet ? 22.0 : 18.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E4A86), // الأزرق الغامق
        centerTitle: true,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 👈 يخليهم في نص الشاشة
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? size.width * 0.18 : 32.0,
              ),
              child: _ActionButton(
                label: 'Get S.O.s',
                bg: const Color(0xFF2F76D2),
                shadow: const Color(0x332F76D2),
                height: btnHeight,
                radius: btnRadius,
                fontSize: fontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GetSOSScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: gap),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? size.width * 0.18 : 32.0,
              ),
              child: _ActionButton(
                label: 'Re-Scan S.O.s',
                bg: const Color(0xFF27AE60),
                shadow: const Color(0x3327AE60),
                height: btnHeight,
                radius: btnRadius,
                fontSize: fontSize,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReScanSOSScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: gap),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? size.width * 0.18 : 32.0,
              ),
              child: _ActionButton(
                label: 'Exit',
                bg: const Color(0xFFE74C3C),
                shadow: const Color(0x33E74C3C),
                height: btnHeight,
                radius: btnRadius,
                fontSize: fontSize,
                onTap: () {
                  _showExitDialog(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Exit"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // يقفل الدايالوج
            },
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              SystemNavigator.pop(); // يخرج من الابلكيشن
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color shadow;
  final double height;
  final double radius;
  final double fontSize;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.bg,
    required this.shadow,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
