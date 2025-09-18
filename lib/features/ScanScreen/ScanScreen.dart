import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
  int get qty => int.tryParse(qtyCtrl.text) ?? 0;
  set qty(int v) => qtyCtrl.text = v.toString();

  @override
  void initState() {
    super.initState();
    fetchLines();

    // Listener للباركود
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
        "http://irs.evioteg.com:8080/api/SalesOrderLine/${widget.txnID}";
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
    qty = next;
    setState(() {});
    final maxCanAdd = selectedLine!.remaining - selectedLine!.tempScanned;
    if (next > maxCanAdd) _showOverDialog();
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
    if (val < 0) {
      qty = 0;
      setState(() {});
      return;
    }
    setState(() {});
    final maxCanAdd = selectedLine!.remaining - selectedLine!.tempScanned;
    if (val > maxCanAdd) _showOverDialog();
  }

  void _addQty() {
    if (selectedLine == null || qty == 0) return;
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

  void _done() async {
    // تحديث الـ scanned بالداتا بيز لكل العناصر
    for (var line in lines) {
      if (line.tempScanned > 0) {
        final url =
            "http://irs.evioteg.com:8080/api/SalesOrderLine/${line.id}";
        try {
          await http.put(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: json.encode({"scanned": line.tempScanned}),
          );
          line.scanned = line.tempScanned; // تحديث محلي
        } catch (e) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
    Navigator.pop(context);
  }

  Future<void> _showOverDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'Qty is Over',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F76D2),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  void _applyScannedBarcode(String barcode) {
    final index = lines.indexWhere((line) => line.barcodes.contains(barcode));
    if (index != -1) {
      setState(() {
        selectedIndex = index;
        qty = 1;
      });
      _addQty();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcode not found')));
    }
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
                    headingRowColor: MaterialStateProperty.all(
                        const Color(0xFFEFEFF4)),
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
                                (states) =>
                            selected ? const Color(0xFFE0ECFF) : null),
                        onSelectChanged: (_) => _selectRow(i),
                        cells: [
                          DataCell(Text(line.code)),
                          DataCell(Text('${line.remaining}')),
                          DataCell(Text('${line.tempScanned}')),
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
                            style: TextStyle(fontWeight: FontWeight.w600)),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                            onPressed: _done,
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
          // TextField مخفي لاستقبال الباركود
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: 0,
              height: 0,
              child: TextField(
                controller: barcodeCtrl,
                autofocus: true,
                enableInteractiveSelection: false,
                showCursor: false,
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
                  fontWeight: FontWeight.w700, fontSize: isTablet ? 18 : 16),
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
  final String id;
  final String code;
  final String desc;
  final String unit;
  final int remaining;
  int scanned;
  int tempScanned;
  List<String> barcodes;

  _SoLine({
    required this.id,
    required this.code,
    required this.desc,
    required this.remaining,
    required this.scanned,
    required this.unit,
    int? tempScanned,
    List<String>? barcodes,
  })  : tempScanned = tempScanned ?? 0,
        barcodes = barcodes ?? [];

  factory _SoLine.fromJson(Map<String, dynamic> json) {
    return _SoLine(
      id: json['lineID']?.toString() ?? '',
      code: json['item']?.toString() ?? '',
      desc: json['description']?.toString() ?? '',
      remaining: (json['orderdQty'] ?? 0).toInt(),
      scanned: 0,
      unit: json['unit']?.toString() ?? 'PCS',
      tempScanned: 0,
      barcodes: List<String>.from(json['barcodes'] ?? []),
    );
  }
}
