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

  Future<void> fetchSalesOrders() async {
    setState(() => isLoading = true);

    try {
      final userId = context.read<AuthProvider>().userID;
      if (userId == null) {
        setState(() => isLoading = false);
        _showSnackBar("User ID not found, please login again.");
        return;
      }

      final baseUrlProvider = context.read<BaseUrlProvider>();
      if (baseUrlProvider.normalizedBaseUrl.trim().isEmpty) {
        setState(() => isLoading = false);
        _showSnackBar("Base URL is not set. Please go to Settings.");
        return;
      }

      final url = baseUrlProvider.apiUrl(
        "api/SalesOrder/GetSalesOrderFSC/${Uri.encodeComponent(userId.toString())}",
      );

      debugPrint("➡️ GetSOS URL = $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List data = (decoded is List) ? decoded : [];

        setState(() {
          soList = data.map((e) => SalesOrder.fromJson(e)).toList();
          selectedIndex = null;
          isLoading = false;
        });
      } else {
        debugPrint("❌ GetSOS Error ${response.statusCode}: ${response.body}");
        setState(() => isLoading = false);
        _showSnackBar("Failed to load sales orders: HTTP ${response.statusCode}");
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
          Expanded(child: _buildListView()),
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
      actions: [
        // IconButton(
        //   tooltip: "Refresh",
        //   onPressed: fetchSalesOrders,
        //   icon: const Icon(Icons.refresh, color: Colors.white),
        // ),
      ],
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

  void _onScanPressed() async {
    if (selectedIndex == null) {
      _showSnackBar("Please select an S.O first");
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          soNumber: soList[selectedIndex!].soNumber,
          txnID: soList[selectedIndex!].txnID,
        ),
      ),
    );

    if (result == true) {
      await fetchSalesOrders();
    }
  }
}
