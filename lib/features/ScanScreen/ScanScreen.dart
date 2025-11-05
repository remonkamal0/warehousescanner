// --- same imports as yours above ---
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

  // Manual entry for qty
  final TextEditingController qtyCtrl = TextEditingController(text: '');
  // Hidden textfield to capture barcode
  final TextEditingController barcodeCtrl = TextEditingController();

  // focus nodes
  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();

  bool _processingBarcode = false;

  /// Pending quantity stored "outside" and used only on scan
  int _pendingQty = 0;

  @override
  void initState() {
    super.initState();
    fetchLines();
    // Focus barcode after screen opens
    Future.delayed(const Duration(milliseconds: 300), _ensureFocus);

    // Fallback listener for scanners that don't send Enter
    barcodeCtrl.addListener(() {
      final text = barcodeCtrl.text.trim();
      if (text.isNotEmpty) {
        _processBarcode(text);
      }
    });
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  // Focus barcode + hide keyboard
  void _ensureFocus() {
    if (!mounted) return;
    try {
      if (_qtyFocus.hasFocus) _qtyFocus.unfocus();
    } catch (_) {}
    FocusScope.of(context).requestFocus(_barcodeFocus);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  // consume & reset pending qty after it’s used
  void _consumePendingQty() {
    setState(() => _pendingQty = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Pending Qty consumed and reset to 0")),
    );
    _ensureFocus();
  }

  // Normalize + prevent double-processing
  void _processBarcode(String raw) {
    if (_processingBarcode) return;
    final barcode = raw.replaceAll('\n', '').replaceAll('\r', '').trim();
    if (barcode.isEmpty) return;

    _processingBarcode = true;
    try {
      _applyScannedBarcode(barcode);
    } catch (e) {
      debugPrint('Error processing barcode: $e');
    } finally {
      barcodeCtrl.clear();
      Future.delayed(const Duration(milliseconds: 120), () {
        _ensureFocus();
        _processingBarcode = false;
      });
    }
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
        Future.delayed(const Duration(milliseconds: 200), _ensureFocus);
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
    });
  }

  /// فتح التفاصيل بالضغط المطوّل
  void _onRowLongPress(int index) {
    _selectRow(index);
    final line = selectedLine;
    if (line != null) _openLineDetailsSheet(line);
  }

  /// Save pending qty manually (OK button)
  void _savePendingQty() {
    final val = int.tryParse(qtyCtrl.text.trim());
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Enter a valid quantity (> 0) then press OK")),
      );
      FocusScope.of(context).requestFocus(_qtyFocus);
      return;
    }
    setState(() {
      _pendingQty = val;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Pending Qty saved: $_pendingQty")),
    );
    qtyCtrl.clear(); // leave the field
    Future.delayed(const Duration(milliseconds: 120), _ensureFocus);
  }

  /// Reset pending qty to zero
  void _resetPendingQty() {
    setState(() {
      _pendingQty = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pending Qty reset to 0")),
    );
    _ensureFocus();
  }

  void _clearLine() {
    if (selectedLine == null) return;
    setState(() {
      selectedLine!.tempScanned = 0;
    });
    Future.delayed(const Duration(milliseconds: 70), _ensureFocus);
  }

  // ✅ ADD now ADDS to current quantity (+=)
  void _addQtyToSelectedLine() {
    if (selectedLine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Select a line first")),
      );
      return;
    }

    int? typed = int.tryParse(qtyCtrl.text.trim());
    int adding;
    if (typed != null && typed > 0) {
      adding = typed;
    } else if (_pendingQty > 0) {
      adding = _pendingQty;
    } else {
      final captured = _bootstrapPendingQtyIfSmall();
      if (!captured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Enter qty then press ADD")),
        );
        FocusScope.of(context).requestFocus(_qtyFocus);
        return;
      }
      adding = _pendingQty;
    }

    final line = selectedLine!;
    final current = line.scanned + line.tempScanned;
    final totalIfAdd = current + adding;

    if (totalIfAdd > line.orderedQty) {
      _showOverDialog(line.orderedQty, current, adding);
      // لو عايز تمنع الإضافة عند الزيادة: اعمل return هنا
      // return;
    }

    setState(() {
      line.tempScanned += adding; // ← الإضافة بدل التعيين
    });

    qtyCtrl.clear();
    _consumePendingQty(); // reset pending + focus + snackbar

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Added $adding to ${line.code}")),
    );
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
            const SnackBar(content: Text("The data has been sent successfully. ✅")),
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

  Future<void> _confirmCancel() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Cancel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel?',
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
      Navigator.pop(context);
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Exit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to exit this screen?',
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
    return result ?? false;
  }

  /// Auto-capture a small qty on first scan:
  /// - If input is 1..3 → use it.
  /// - If input is empty → default to 1.
  /// Returns true if _pendingQty was set.
  bool _bootstrapPendingQtyIfSmall() {
    final raw = qtyCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _pendingQty = 1); // default when empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Pending Qty auto-set to 1")),
      );
      return true;
    }
    final v = int.tryParse(raw);
    if (v != null && v >= 1 && v <= 3) {
      setState(() => _pendingQty = v);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Pending Qty auto-set to $_pendingQty")),
      );
      qtyCtrl.clear(); // optional
      return true;
    }
    return false;
  }

  /// Scan adds the saved pending qty to the matched line
  void _applyScannedBarcode(String barcode) {
    // If no pending qty yet, try to bootstrap from the input (small or empty)
    if (_pendingQty <= 0) {
      final captured = _bootstrapPendingQtyIfSmall();
      if (!captured) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Enter quantity and press OK first")),
        );
        _ensureFocus();
        return;
      }
      // now _pendingQty is set (1..3 or default 1)
    }

    final index = lines.indexWhere((line) => line.barcodes.contains(barcode));
    if (index != -1) {
      final line = lines[index];
      final adding = _pendingQty;
      final totalIfAdd = line.scanned + line.tempScanned + adding;

      if (totalIfAdd > line.orderedQty) {
        _showOverDialog(
          line.orderedQty,
          line.scanned + line.tempScanned,
          adding,
        );
      }

      setState(() {
        selectedIndex = index;
        line.tempScanned += adding; // ← إضافة بالباركود كذلك
      });

      _consumePendingQty(); // reset after adding
    } else {
      _showInvalidBarcodeDialog(barcode);
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
              Future.delayed(const Duration(milliseconds: 100), _ensureFocus);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  /// ===== Bottom Sheet: Line Details =====
  void _openLineDetailsSheet(_SoLine line) {
    final current = line.scanned + line.tempScanned;
    final remaining = (line.orderedQty - current);
    final safeRemaining = remaining < 0 ? 0 : remaining;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SKU: ${line.code}", style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text("U/M: ${line.unit}", style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                line.desc.isEmpty ? "No description" : line.desc,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _pill("Ordered", "${line.orderedQty}"),
                  _pill("Scanned", "$current"),
                  _pill("Remaining", "$safeRemaining"),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    ).whenComplete(_ensureFocus);
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ",
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return WillPopScope(
      onWillPop: _showExitConfirmDialog, // confirmation on system back
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2F76D2),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final confirm = await _showExitConfirmDialog();
              if (confirm && mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            'Scan - ${widget.soNumber}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: Stack(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
              children: [
                // Pending qty banner
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Pending Qty (for scan): $_pendingQty",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8)),
                  ),
                ),
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
                            label: Text('Scanned',
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
                            DataCell(
                              Text(line.code),
                              onLongPress: () => _onRowLongPress(i),
                            ),
                            DataCell(
                              Text('${line.orderedQty}'),
                              onLongPress: () => _onRowLongPress(i),
                            ),
                            DataCell(
                              Text('${line.scanned + line.tempScanned}'),
                              onLongPress: () => _onRowLongPress(i),
                            ),
                            DataCell(
                              Text(line.unit),
                              onLongPress: () => _onRowLongPress(i),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),

                // === Footer controls (Qty/ADD/Details/Reset/Cancel/Done) ===
                Container
                  (
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? size.width * 0.06 : 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _chipButton('Clear Line', onTap: _clearLine),
                          const Text('Qty:',
                              style:
                              TextStyle(fontWeight: FontWeight.w600)),
                          _qtyBox(isTablet: isTablet), // manual field + OK
                          // ADD button (adds to current now)
                          ElevatedButton.icon(
                            onPressed: (selectedLine == null)
                                ? null
                                : _addQtyToSelectedLine,
                            icon: const Icon(Icons.add_circle),
                            label: const Text('ADD'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F76D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          // Details button opens bottom sheet
                          OutlinedButton.icon(
                            onPressed: (selectedLine == null)
                                ? null
                                : () => _openLineDetailsSheet(selectedLine!),
                            icon: const Icon(Icons.info_outline),
                            label: const Text('Details'),
                          ),
                          OutlinedButton(
                            onPressed: _resetPendingQty,
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final ok = await _showExitConfirmDialog();
                                if (ok && mounted) Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
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
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
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
            // Hidden TextField for barcode input
            Positioned(
              left: -100,
              top: -100,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: barcodeCtrl,
                  focusNode: _barcodeFocus,
                  autofocus: false,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  readOnly: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  onSubmitted: (v) => _processBarcode(v),
                ),
              ),
            ),
          ],
        ),
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

  /// Manual qty box + OK to save
  Widget _qtyBox({required bool isTablet}) {
    final tfWidth = isTablet ? 120.0 : 100.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1E1E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: tfWidth,
            child: TextField(
              controller: qtyCtrl,
              focusNode: _qtyFocus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _savePendingQty(), // Enter = OK
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isTablet ? 18 : 16,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter qty',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: _savePendingQty, // save only
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F76D2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        (json['firstscan'] as num?)?.toInt() ?? 0;
    final second = (json['secondScan'] as num?)?.toInt() ??
        (json['secondscan'] as num?)?.toInt() ??
        (json['scondScan'] as num?)?.toInt() ?? 0;

    return _SoLine(
      txnid: json['txnid']?.toString() ?? '',
      code: json['item']?.toString() ?? '',
      desc: json['description']?.toString() ?? '',
      orderedQty: (json['orderdQty'] as num?)?.toInt() ??
          (json['orderedQty'] as num?)?.toInt() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'PCS',
      scanned: first,
      tempScanned: second,
      barcodes:
      (json['barcodes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
