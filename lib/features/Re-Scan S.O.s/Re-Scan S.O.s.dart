import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:warehousescanner/features/Get%20S.O.s/widgets/sales_order_card.dart';

import '../Get S.O.s/models/sales_order.dart';
import '../ReScanScreen/ReScanScreen.dart';
import '../ScanScreen/ScanScreen.dart';

class ReScanSOSScreen extends StatefulWidget {
  const ReScanSOSScreen({super.key});

  @override
  State<ReScanSOSScreen> createState() => _ReScanSOSScreenState();
}

class _ReScanSOSScreenState extends State<ReScanSOSScreen> {
  int? selectedIndex;
  List<SalesOrder> soList = [];
  bool isLoading = true;


  /// ✅ API Call
  Future<void> fetchSalesOrders() async {
    const url = "http://irs.evioteg.com:8080/api/SalesOrder/GetSalesOrderSSC";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          soList = data.map((e) => SalesOrder.fromJson(e)).toList();
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load sales orders");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Error: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
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
          : Column(
        children: [
          /// ✅ Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isTablet) {
    return AppBar(
      backgroundColor: Color(0xFF27AE60),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Get ReScan S.O.s",
        style: TextStyle(
          color: Colors.white,
          fontSize: isTablet ? 24 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
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
            backgroundColor: Color(0xFF27AE60),
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

  void _onScanPressed() {
    if (selectedIndex == null) {
      _showSnackBar("Please select an S.O first");
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReScanScreen(
            soNumber: soList[selectedIndex!].soNumber,
            txnID: soList[selectedIndex!].txnID, // ✅ أضف txnID هنا
          ),
        ),
      );
    }
  }
}
