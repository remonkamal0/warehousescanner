import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/base_url_provider.dart';

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

  final TextEditingController qtyCtrl = TextEditingController(text: '');
  final TextEditingController barcodeCtrl = TextEditingController();

  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();

  bool _processingBarcode = false;
  int _pendingQty = 0;

  List<GlobalKey> _rowKeys = [];
  final ScrollController _tableScrollController = ScrollController();

  bool _sortAscending = true;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    fetchLines();

    Future.delayed(const Duration(milliseconds: 300), _ensureFocus);

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
    _tableScrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _ensureFocus() {
    if (!mounted) return;
    try {
      if (_qtyFocus.hasFocus) _qtyFocus.unfocus();
    } catch (_) {}
    FocusScope.of(context).requestFocus(_barcodeFocus);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _consumePendingQty() {
    setState(() => _pendingQty = 0);
    _ensureFocus();
  }

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

  /// ✅✅✅ أهم تعديل هنا: GetOrderLinesWithBarcodesFSC/{ForderId}/{userid}
  Future<void> fetchLines() async {
    setState(() => isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.userID;

      if (userId == null) {
        setState(() => isLoading = false);
        _showSnackBar("User ID not found, please login again.");
        return;
      }

      final baseUrlProvider = context.read<BaseUrlProvider>();

      // لو انت عامل normalized/apiUrl (زي الكود اللي اتأكدنا عليه)
      if (baseUrlProvider.normalizedBaseUrl.trim().isEmpty) {
        setState(() => isLoading = false);
        _showSnackBar("Base URL is not set. Please go to Settings.");
        return;
      }

      final url = baseUrlProvider.apiUrl(
        "api/SalesOrderLine/GetOrderLinesWithBarcodesFSC/${Uri.encodeComponent(widget.txnID)}/${Uri.encodeComponent(userId.toString())}",
      );

      debugPrint("➡️ ScanScreen fetchLines URL = $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // أمان: لو السيرفر رجّع object بدل list
        final List data = (decoded is List) ? decoded : [];

        setState(() {
          lines = data.map((e) => _SoLine.fromJson(e)).toList();
          _rowKeys = List.generate(lines.length, (_) => GlobalKey());
          isLoading = false;
        });

        // لو انت مخفي الـ completed والـ over، ممكن يبان فاضي لو كله خلص
        if (lines.isNotEmpty && !_showCompleted) {
          final visible = lines.where((l) => (l.scanned + l.tempScanned) < l.orderedQty).length;
          debugPrint("ℹ️ Visible(not completed) rows: $visible / total: ${lines.length}");
        }

        Future.delayed(const Duration(milliseconds: 200), _ensureFocus);
      } else {
        debugPrint("❌ fetchLines Error ${response.statusCode}: ${response.body}");
        setState(() => isLoading = false);

        // رسالة أوضح بدل Failed وخلاص
        _showSnackBar("Error loading lines: HTTP ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Error loading lines: $e");
    }
  }

  void _selectRow(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void _savePendingQty() {
    final val = int.tryParse(qtyCtrl.text.trim());
    if (val == null || val <= 0) {
      FocusScope.of(context).requestFocus(_qtyFocus);
      return;
    }
    setState(() {
      _pendingQty = val;
    });
    qtyCtrl.clear();
    Future.delayed(const Duration(milliseconds: 120), _ensureFocus);
  }

  void _resetPendingQty() {
    setState(() {
      _pendingQty = 0;
    });
    _ensureFocus();
  }

  void _clearLine() {
    if (selectedLine == null) return;
    setState(() {
      selectedLine!.tempScanned = 0;
    });
    Future.delayed(const Duration(milliseconds: 70), _ensureFocus);
  }

  void _addQtyToSelectedLine() {
    if (selectedLine == null) {
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
    }

    setState(() {
      line.tempScanned += adding;
      final total = line.scanned + line.tempScanned;

      if (total >= line.orderedQty && !_showCompleted) {
        selectedIndex = null;
      }
    });

    if (selectedIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(selectedIndex!);
      });
    }

    qtyCtrl.clear();
    _consumePendingQty();
  }

  Future<void> _done() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userID = authProvider.userID;

    if (userID == null) {
      _showSnackBar("User ID not found, please login again.");
      return;
    }

    final baseUrlProvider = Provider.of<BaseUrlProvider>(context, listen: false);

    if (baseUrlProvider.normalizedBaseUrl.trim().isEmpty) {
      _showSnackBar("Base URL is not set. Please go to Settings.");
      return;
    }

    final url = baseUrlProvider.apiUrl(
      "api/SalesOrderLine/UpdateOrderDetailsFSC/${Uri.encodeComponent(widget.txnID)}/${Uri.encodeComponent(userID.toString())}",
    );

    debugPrint("➡️ ScanScreen DONE URL = $url");

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
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(
            "Transmission failed (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error while submitting: $e");
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

  bool _bootstrapPendingQtyIfSmall() {
    final raw = qtyCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _pendingQty = 1);
      return true;
    }
    final v = int.tryParse(raw);
    if (v != null && v >= 1 && v <= 3) {
      setState(() => _pendingQty = v);
      qtyCtrl.clear();
      return true;
    }
    return false;
  }

  void _applyScannedBarcode(String barcode) {
    if (_pendingQty <= 0) {
      final captured = _bootstrapPendingQtyIfSmall();
      if (!captured) {
        _ensureFocus();
        return;
      }
    }

    final index = lines.indexWhere((line) => line.barcodes.contains(barcode));
    if (index != -1) {
      final line = lines[index];
      final adding = _pendingQty;
      final current = line.scanned + line.tempScanned;
      final totalIfAdd = current + adding;

      if (totalIfAdd > line.orderedQty) {
        _showOverDialog(line.orderedQty, current, adding);
      }

      setState(() {
        line.tempScanned += adding;
        final total = line.scanned + line.tempScanned;

        if (total >= line.orderedQty && !_showCompleted) {
          selectedIndex = null;
        } else {
          selectedIndex = index;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(index);
      });

      _consumePendingQty();
    } else {
      _showInvalidBarcodeDialog(barcode);
    }

    _ensureFocus();
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

  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;

      if (_sortAscending) {
        lines.sort((a, b) => a.code.compareTo(b.code));
      } else {
        lines.sort((a, b) => b.code.compareTo(a.code));
      }

      _rowKeys = List.generate(lines.length, (_) => GlobalKey());
      selectedIndex = null;
    });
  }

  void _toggleShowCompleted() {
    setState(() {
      _showCompleted = !_showCompleted;

      if (!_showCompleted && selectedLine != null) {
        final total = selectedLine!.scanned + selectedLine!.tempScanned;
        if (total >= selectedLine!.orderedQty) {
          selectedIndex = null;
        }
      }
    });
  }

  void _scrollToIndex(int index) {
    if (index < 0 || index >= _rowKeys.length) return;

    final ctx = _rowKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
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
              onSubmitted: (_) => _savePendingQty(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isTablet ? 18 : 16,
              ),
              decoration: const InputDecoration(
                hintText: 'qty',
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: _savePendingQty,
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    final dataRows = <DataRow>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final total = line.scanned + line.tempScanned;

      final isCompleted = total == line.orderedQty;
      final isOver = total > line.orderedQty;
      final selected = i == selectedIndex;
      final rowKey = (i < _rowKeys.length) ? _rowKeys[i] : GlobalKey();

      if (!_showCompleted && (isCompleted || isOver)) {
        continue;
      }

      dataRows.add(
        DataRow(
          selected: selected,
          color: MaterialStateProperty.resolveWith<Color?>(
                (states) {
              if (selected) return const Color(0xFFE0ECFF);
              if (isOver) return const Color(0xFFFFE5E5);
              if (isCompleted) return const Color(0xFFE5FFE5);
              return null;
            },
          ),
          onSelectChanged: (_) {
            _selectRow(i);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToIndex(i);
            });
          },
          cells: [
            DataCell(
              Container(
                key: rowKey,
                child: Text(line.code),
              ),
            ),
            DataCell(Text('${line.orderedQty}')),
            DataCell(Text('$total')),
            DataCell(Text(line.unit)),
          ],
        ),
      );
    }

    return WillPopScope(
      onWillPop: _showExitConfirmDialog,
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _toggleSort,
              icon: Icon(
                _sortAscending ? Icons.arrow_downward : Icons.arrow_upward,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: _toggleShowCompleted,
              icon: Icon(
                _showCompleted ? Icons.check_circle : Icons.check_circle_outline,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    "Pending Qty (for scan): $_pendingQty",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFFEFEFF4),
                      ),
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('SOQ')),
                        DataColumn(label: Text('Scanned')),
                        DataColumn(label: Text('U/M')),
                      ],
                      rows: dataRows,
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
                    border: Border(
                      top: BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _chipButton('Clr', onTap: _clearLine),
                          ElevatedButton(
                            onPressed: (selectedLine == null)
                                ? null
                                : _addQtyToSelectedLine,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F76D2),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('+'),
                          ),
                          _qtyBox(isTablet: isTablet),
                          OutlinedButton(
                            onPressed: _resetPendingQty,
                            child: const Text('Rest'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _confirmCancel,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _confirmDone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFF2F76D2),
                              ),
                              child: const Text(
                                'Done',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
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
}

// ===== Model =====
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
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'PCS',
      scanned: first,
      tempScanned: second,
      barcodes: (json['barcodes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
