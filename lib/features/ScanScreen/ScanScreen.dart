// --- نفس الـ imports بتاعتك فوق ---
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ScanScreen extends StatefulWidget {
  final String soNumber;
  final String txnID;

  const ScanScreen({
    super.key,
    required this.soNumber,
    required this.txnID,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<_SoLine> lines = [];
  bool isLoading = true;
  int? selectedIndex;

  _SoLine? get selectedLine =>
      (selectedIndex != null) ? lines[selectedIndex!] : null;

  final TextEditingController qtyCtrl = TextEditingController(text: '0');
  final TextEditingController barcodeCtrl = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();

  int get qty => int.tryParse(qtyCtrl.text) ?? 0;
  set qty(int v) => qtyCtrl.text = v.toString();

  @override
  void initState() {
    super.initState();
    fetchLines();

    barcodeCtrl.addListener(() {
      final barcode = barcodeCtrl.text.trim();
      if (barcode.isNotEmpty) {
        _applyScannedBarcode(barcode);
        barcodeCtrl.clear();
      }
    });
  }

  Future<void> fetchLines() async {
    final url =
        "http://irs.evioteg.com:8080/api/SalesOrderLine/GetOrderLinesWithBarcodesFSC/${widget.txnID}";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          lines = data.map((e) => _SoLine.fromJson(e)).toList();
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load sales order lines");
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _selectRow(int index) {
    setState(() {
      selectedIndex = index;
      qty = 0;
    });
  }

  void _incQty() {
    if (selectedLine == null) return;
    final next = qty + 1;
    final totalIfNext = selectedLine!.scanned + selectedLine!.tempScanned + next;

    if (totalIfNext > selectedLine!.orderedQty) {
      _showOverDialog(
        selectedLine!.orderedQty,
        selectedLine!.scanned + selectedLine!.tempScanned,
        next, // ✅ ابعت الكمية الجديدة اللي بتحاول تضيفها
      );
    }

    qty = next;
    setState(() {});
  }



  void _decQty() {
    if (selectedLine == null) return;
    final next = (qty - 1).clamp(0, 1 << 31);
    qty = next;
    setState(() {});
  }

  void _onQtyChanged(String v) {
    if (selectedLine == null) return;
    final val = int.tryParse(v) ?? 0;
    final totalIfVal =
        selectedLine!.scanned + selectedLine!.tempScanned + val;

    if (totalIfVal > selectedLine!.orderedQty) {
      _showOverDialog(
        selectedLine!.orderedQty,
        selectedLine!.scanned + selectedLine!.tempScanned,
        val,
      );
    }

    qty = val;
    setState(() {});
  }

  void _addQty() {
    if (selectedLine == null || qty == 0) return;

    final totalIfAdd =
        selectedLine!.scanned + selectedLine!.tempScanned + qty;

    if (totalIfAdd > selectedLine!.orderedQty) {
      _showOverDialog(
        selectedLine!.orderedQty,
        selectedLine!.scanned + selectedLine!.tempScanned,
        qty,
      );
    }

    setState(() {
      selectedLine!.tempScanned += qty;
      qty = 0;
    });
  }

  void _clearLine() {
    if (selectedLine == null) return;
    setState(() {
      selectedLine!.tempScanned = 0;
      qty = 0;
    });
  }

  Future<void> _done() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userID = authProvider.userID;

    if (userID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ User not logged in")),
      );
      return;
    }

    final url =
        "http://irs.evioteg.com:8080/api/SalesOrderLine/UpdateOrderDetailsFSC/${widget.txnID}/$userID";

    try {
      final payload = lines
          .map((l) => {
        "itemCode": l.code,
        "quantity": l.scanned + l.tempScanned,
      })
          .toList();

      final response = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("The data has been sent successfully. ✅")),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(
            "Transmission failed (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _confirmDone() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Submission',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to submit this supply order?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2F76D2),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      _done();
    }
  }

  Future<void> _showOverDialog(int ordered, int current, int adding) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Qty is Over',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Ordered Qty: $ordered"),
            Text("Current Qty: $current"),
            Text("Trying to Add: $adding"),
            const SizedBox(height: 8),
            const Text(
              "⚠️ The quantity will still be added.",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F76D2),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _applyScannedBarcode(String barcode) {
    final index = lines.indexWhere((line) => line.barcodes.contains(barcode));
    if (index != -1) {
      final line = lines[index];
      final adding = 1; // لو بعدين هتخليها أكتر من 1 غيّرها هنا
      final totalIfAdd = line.scanned + line.tempScanned + adding;

      if (totalIfAdd > line.orderedQty) {
        _showOverDialog(
          line.orderedQty,
          line.scanned + line.tempScanned,
          adding, // ✅ مش دايماً 1
        );
      }

      setState(() {
        selectedIndex = index;
        line.tempScanned += adding;
        qty = 0;
      });
    } else {
      _showInvalidBarcodeDialog(barcode);
    }
  }


  Future<void> _showInvalidBarcodeDialog(String barcode) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Invalid Barcode',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'The scanned barcode "$barcode" is not valid.\nPlease try again.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F76D2),
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), () {
                FocusScope.of(context).requestFocus(_barcodeFocus);
              });
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F76D2),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan - ${widget.soNumber}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all(const Color(0xFFEFEFF4)),
                    columns: const [
                      DataColumn(
                          label: Text('SKU',
                              style:
                              TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(
                          label: Text('SOQ',
                              style:
                              TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(
                          label: Text('Sc',
                              style:
                              TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(
                          label: Text('U/M',
                              style:
                              TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: List.generate(lines.length, (i) {
                      final line = lines[i];
                      final selected = i == selectedIndex;
                      return DataRow(
                        selected: selected,
                        color: MaterialStateProperty.resolveWith<Color?>(
                                (states) => selected
                                ? const Color(0xFFE0ECFF)
                                : null),
                        onSelectChanged: (_) => _selectRow(i),
                        cells: [
                          DataCell(Text(line.code)),
                          DataCell(Text('${line.orderedQty}')),
                          DataCell(
                              Text('${line.scanned + line.tempScanned}')),
                          DataCell(Text(line.unit)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? size.width * 0.06 : 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border:
                  Border(top: BorderSide(color: Color(0xFFE6E6E6))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chipButton('Clr Line', onTap: _clearLine),
                        _chipButton('Add', onTap: _addQty),
                        const Text('Qty:',
                            style:
                            TextStyle(fontWeight: FontWeight.w600)),
                        _qtyBox(isTablet: isTablet),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedLine != null
                          ? '${selectedLine!.desc}'
                          : 'Select a row from the table…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                      const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmDone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F76D2),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50)
                  ],
                ),
              ),
            ],
          ),
          // ✅ TextField الباركود المخفي من غير كيبورد
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: 0,
              height: 0,
              child: TextField(
                controller: barcodeCtrl,
                focusNode: _barcodeFocus,
                autofocus: false,
                enableInteractiveSelection: false,
                showCursor: false,
                readOnly: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, {required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: selectedLine == null ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF5F6F8),
        foregroundColor: Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _qtyBox({required bool isTablet}) {
    final tfWidth = isTablet ? 90.0 : 70.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1E1E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: selectedLine == null ? null : _decQty,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.remove, size: 20),
            ),
          ),
          SizedBox(
            width: tfWidth,
            child: TextField(
              controller: qtyCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onQtyChanged,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 18 : 16),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              enabled: selectedLine != null,
            ),
          ),
          InkWell(
            onTap: selectedLine == null ? null : _incQty,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.add, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoLine {
  final String txnid;
  final String code;
  final String desc;
  final int orderedQty;
  final double rate;
  final String unit;

  int scanned;
  int tempScanned;

  List<String> barcodes;

  _SoLine({
    required this.txnid,
    required this.code,
    required this.desc,
    required this.orderedQty,
    required this.rate,
    this.unit = "PCS",
    this.scanned = 0,
    this.tempScanned = 0,
    List<String>? barcodes,
  }) : barcodes = barcodes ?? [];

  factory _SoLine.fromJson(Map<String, dynamic> json) {
    final first = (json['firstScan'] as num?)?.toInt() ??
        (json['firstscan'] as num?)?.toInt() ??
        0;
    final second = (json['secondScan'] as num?)?.toInt() ??
        (json['secondscan'] as num?)?.toInt() ??
        (json['scondScan'] as num?)?.toInt() ??
        0;

    return _SoLine(
      txnid: json['txnid']?.toString() ?? '',
      code: json['item']?.toString() ?? '',
      desc: json['description']?.toString() ?? '',
      orderedQty: (json['orderdQty'] as num?)?.toInt() ??
          (json['orderedQty'] as num?)?.toInt() ??
          0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'PCS',
      scanned: first,
      tempScanned: second,
      barcodes: (json['barcodes'] as List?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }
}
