import 'package:flutter/material.dart';

class SendSOSScreen extends StatefulWidget {
  const SendSOSScreen({super.key});

  @override
  State<SendSOSScreen> createState() => _SendSOSScreenState();
}

class _SendSOSScreenState extends State<SendSOSScreen> {
  // حالة التشيك بوكس
  List<bool> selected = List.generate(10, (_) => false);

  // بيانات تجريبية: الحالة (Open / Sent)
  List<String> status = [
    "Open",
    "Open",
    "Open",
    "Sent",
    "Open",
    "Open",
    "Open",
    "Open",
    "Open",
    "Open",
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Send S.O.s",
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // ===== القائمة =====
          Expanded(
            child: ListView.builder(
              itemCount: selected.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final isSent = status[index] == "Sent";
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: selected[index],
                        onChanged: (val) {
                          setState(() {
                            selected[index] = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "S.O.1001",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Ahmed Gamal",
                              style:
                              TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSent ? Colors.blue : Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status[index],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Jan 15 ,2025",
                            style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ===== زر Send S.O.s =====
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: isTablet ? 65 : 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  // TODO: منطق إرسال S.O.s
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Send S.O.s button pressed")),
                  );
                },
                child: Text(
                  "Send S.O.s",
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
