import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:warehousescanner/features/Get%20S.O.s/widgets/sales_order_card.dart';
import '../ScanScreen/ScanScreen.dart';
import 'models/sales_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/base_url_provider.dart';

class GetSOSScreen extends StatefulWidget {
  const GetSOSScreen({super.key});

  @override
  State<GetSOSScreen> createState() => _GetSOSScreenState();
}

class _GetSOSScreenState extends State<GetSOSScreen> {
  int? selectedIndex;
  List<SalesOrder> soList = [];
  bool isLoading = true;

  /// ✅ API Call – باستخدام baseUrl + userID
  Future<void> fetchSalesOrders() async {
    try {
      // نجيب اليوزر ID من AuthProvider
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userID;

      if (userId == null) {
        setState(() => isLoading = false);
        _showSnackBar("User ID not found, please login again.");
        return;
      }

      // نجيب الـ Base URL من BaseUrlProvider
      final baseUrl =
          Provider.of<BaseUrlProvider>(context, listen: false).baseUrl;

      final url = "$baseUrl/api/SalesOrder/GetSalesOrderFSC/$userId";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          soList = data.map((e) => SalesOrder.fromJson(e)).toList();
          isLoading = false;
        });
      } else {
        throw Exception(
            "Failed to load sales orders (${response.statusCode})");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Error: $e");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    // ينفع نستخدم Provider في initState مع listen:false
    fetchSalesOrders();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(isTablet),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : soList.isEmpty
          ? const Center(
        child: Text(
          "No Sales Orders found",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      )
          : Column(
        children: [
          /// ✅ Header Row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "Sales Order",
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// ✅ List
          Expanded(child: _buildListView()),

          /// ✅ Button
          _buildScanButton(isTablet),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isTablet) {
    return AppBar(
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
      // لو عايز تزود زر settings هنا:
      // actions: [
      //   IconButton(
      //     icon: const Icon(Icons.settings, color: Colors.white),
      //     onPressed: () {
      //       Navigator.push(
      //         context,
      //         MaterialPageRoute(builder: (_) => const SettingsScreen()),
      //       );
      //     },
      //   ),
      // ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: soList.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        final so = soList[index];
        return SalesOrderCard(
          so: so,
          isSelected: selectedIndex == index,
          onTap: () => setState(() => selectedIndex = index),
        );
      },
    );
  }

  Widget _buildScanButton(bool isTablet) {
    return Padding(
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
          onPressed: _onScanPressed,
          child: Text(
            "Get",
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ لما يختار S.O ويدوس Get → يروح ScanScreen
  /// و ScanScreen أصلاً بتاخد userID من AuthProvider في _done()
  void _onScanPressed() async {
    if (selectedIndex == null) {
      _showSnackBar("Please select an S.O first");
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanScreen(
            soNumber: soList[selectedIndex!].soNumber,
            txnID: soList[selectedIndex!].txnID,
          ),
        ),
      );

      // ✅ لو رجع true من ScanScreen، نعمل refresh للقائمة
      if (result == true) {
        setState(() {
          isLoading = true;
        });
        await fetchSalesOrders();
      }
    }
  }
}
