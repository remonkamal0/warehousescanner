import 'package:flutter/material.dart';

import '../ScanScreen/ScanScreen.dart';

class GetSOSScreen extends StatefulWidget {
  const GetSOSScreen({super.key});

  @override
  State<GetSOSScreen> createState() => _GetSOSScreenState();
}

class _GetSOSScreenState extends State<GetSOSScreen> {
  int? selectedIndex; // نخزن ال index بتاع الـ SO المختار

  final List<String> soList = [
    "S.O.1001",
    "S.O.1002",
    "S.O.1003",
    "S.O.1004",
    "S.O.1005",
    "S.O.1006",
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Get S.O.s",
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // ====== القائمة ======
          Expanded(
            child: ListView.builder(
              itemCount: soList.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue: selectedIndex,
                        onChanged: (val) {
                          setState(() {
                            selectedIndex = val;
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              soList[index],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Ahmed Gamal",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black54),
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
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Open",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Jan 15 ,2025",
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ====== زر Scan ======
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: isTablet ? 65 : 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  if (selectedIndex == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Please select an S.O first")),
                    );
                  } else {
                    // ✅ التنقل لصفحة Scan مع تمرير الـ SO
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanScreen(
                          soNumber: soList[selectedIndex!],
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  "Scan",
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
