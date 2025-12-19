import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/base_url_provider.dart'; // ✅ استخدمنا الباز يوارال هنا

class ReScanScreen extends StatefulWidget {
  final String soNumber;
  final String txnID;

  const ReScanScreen({
    super.key,
    required this.soNumber,
    required this.txnID,
  });

  @override
  State<ReScanScreen> createState() => _ReScanScreenState();
}

class _ReScanScreenState extends State<ReScanScreen> {
  List<_SoLine> lines = [];
  bool isLoading = true;
  int? selectedIndex;

  _SoLine? get selectedLine =>
      (selectedIndex != null) ? lines[selectedIndex!] : null;

  // Manual entry for qty (user types here)
  final TextEditingController qtyCtrl = TextEditingController(text: '');
  // Hidden textfield to capture barcode
  final TextEditingController barcodeCtrl = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();

  /// Pending quantity used once on scan (then reset)
  int _pendingQty = 0;

  /// مفاتيح لكل صف في الجدول علشان نقدر نعمل Scrollable.ensureVisible
  List<GlobalKey> _rowKeys = [];

  /// اتجاه الترتيب: true = A→Z, false = Z→A
  bool _sortAscending = true;

  /// إظهار / إخفاء الأصناف اللي خلصت أو Over (Scanned >= OrderedQty)
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    fetchLines();

    // Fallback للماسحات اللي مش بتبعت Enter
    barcodeCtrl.addListener(() {
      final s = barcodeCtrl.text.trim();
      if (s.isNotEmpty) {
        _applyScannedBarcode(s);
        barcodeCtrl.clear();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBarcodeFocus());
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  void _ensureBarcodeFocus() {
    if (!_barcodeFocus.hasFocus) {
      FocusScope.of(context).requestFocus(_barcodeFocus);
    }
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// ✅ جلب اللاينات باستخدام الـ Base URL
  Future<void> fetchLines() async {
    try {
      // نجيب الـ baseUrl من الـ Provider
      final baseUrlProvider =
      Provider.of<BaseUrlProvider>(context, listen: false);
      String? baseUrl = baseUrlProvider.baseUrl;

      if (baseUrl == null || baseUrl.trim().isEmpty) {
        setState(() => isLoading = false);
        _showSnackBar("Base URL is not set. Please go to Settings.");
        return;
      }

      // Normalize: نشيل المسافات و / الزيادة في الآخر
      baseUrl = baseUrl.trim();
      baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

      final url =
          "$baseUrl/api/SalesOrderLine/GetOrderLinesWithBarcodesSSC/${widget.txnID}";

      debugPrint("➡️ ReScanScreen fetchLines URL = $url");

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          lines = data.map((e) => _SoLine.fromJson(e)).toList();

          // إعادة المسح من الصفر
          for (final l in lines) {
            l.scanned = 0;
            l.tempScanned = 0;
          }
          _pendingQty = 0;
          qtyCtrl.clear();

          // تجهيز مفاتيح الصفوف للـ scroll
          _rowKeys = List.generate(lines.length, (_) => GlobalKey());

          isLoading = false;
        });

        _ensureBarcodeFocus();
      } else {
        debugPrint(
            "❌ ReScan fetchLines Error ${response.statusCode}: ${response.body}");
        throw Exception("Failed to load sales order lines");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar("Error loading lines: $e");
      _ensureBarcodeFocus();
    }
  }

  void _selectRow(int index) {
    setState(() {
      selectedIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(index);
    });

    _ensureBarcodeFocus();
  }

  /// Long-press to open details bottom sheet (اختياري)
  void _onRowLongPress(int index) {
    _selectRow(index);
    if (selectedLine != null) {
      _openLineDetailsSheet(selectedLine!);
    }
  }

  /// Save pending qty manually (OK button)
  void _savePendingQty() {
    final val = int.tryParse(qtyCtrl.text.trim());
    if (val == null || val <= 0) {
      FocusScope.of(context).requestFocus(_qtyFocus);
      return;
    }
    setState(() => _pendingQty = val);

    qtyCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), _ensureBarcodeFocus);
  }

  void _resetPendingQty() {
    setState(() => _pendingQty = 0);
    _ensureBarcodeFocus();
  }

  void _consumePendingQty() {
    setState(() => _pendingQty = 0);
    _ensureBarcodeFocus();
  }

  // ADD: add pending/typed qty to selected line (for items without barcode)
  void _addQtyToSelectedLine() {
    if (selectedLine == null) {
      _ensureBarcodeFocus();
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
      _showOverDialog(
        ordered: line.orderedQty,
        current: current,
        adding: adding,
      );
      // الزيادة مسموح بيها، مش بنمنعها
    }

    setState(() {
      line.tempScanned += adding;
      final total = line.scanned + line.tempScanned;

      // لو وصل أو عدّى الكمية المطلوبة → الرو يختفي لو _showCompleted = false
      if (total >= line.orderedQty && !_showCompleted) {
        selectedIndex = null;
      }
    });

    // Scroll للصف المختار لو لسه موجود
    if (selectedIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToIndex(selectedIndex!);
      });
    }

    qtyCtrl.clear();
    _consumePendingQty();
  }

  Future<void> _done() async {
    final confirm = await _showSubmitConfirmDialog();
    if (confirm != true) {
      _ensureBarcodeFocus();
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.userID;
    if (userId == null) {
      _showSnackBar("User ID not found, please login again.");
      _ensureBarcodeFocus();
      return;
    }

    // ✅ نجيب الـ Base URL برضه هنا
    final baseUrlProvider = context.read<BaseUrlProvider>();
    String? baseUrl = baseUrlProvider.baseUrl;

    if (baseUrl == null || baseUrl.trim().isEmpty) {
      _showSnackBar("Base URL is not set. Please go to Settings.");
      _ensureBarcodeFocus();
      return;
    }

    baseUrl = baseUrl.trim();
    baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

    final String salesOrderId =
    (lines.isNotEmpty && lines.first.txnid.isNotEmpty)
        ? lines.first.txnid
        : widget.txnID;

    final url =
        "$baseUrl/api/SalesOrderLine/UpdateOrderDetailsSSC/"
        "${Uri.encodeComponent(salesOrderId)}/"
        "${Uri.encodeComponent(userId.toString())}";

    debugPrint("➡️ ReScanScreen DONE URL = $url");

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
          "Transmission failed (${response.statusCode}): ${response.body}",
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Error while submitting: $e");
      }
    } finally {
      _ensureBarcodeFocus();
    }
  }

  Future<bool?> _showCancelConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Cancel',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel?',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: const StadiumBorder()),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2F76D2),
                shape: const StadiumBorder()),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSubmitConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Submission',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to submit this supply order?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: const StadiumBorder()),
            onPressed: () {
              Navigator.pop(context, false);
              Future.delayed(
                  const Duration(milliseconds: 50), _ensureBarcodeFocus);
            },
            child: const Text('No', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2F76D2),
                shape: const StadiumBorder()),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showOverDialog({
    required int ordered,
    required int current,
    required int adding,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Qty is Over',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
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
                backgroundColor: const Color(0xFF27AE60),
                shape: const StadiumBorder()),
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(
                  const Duration(milliseconds: 50), _ensureBarcodeFocus);
            },
            child: const Text('OK',
                style: TextStyle(color: Colors.white)),
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
        title: const Text('Invalid Barcode',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'The scanned barcode "$barcode" is not valid.\nPlease try again.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F76D2),
                shape: const StadiumBorder()),
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(
                  const Duration(milliseconds: 50), _ensureBarcodeFocus);
            },
            child: const Text('OK',
                style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
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
        _ensureBarcodeFocus();
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
        _showOverDialog(
          ordered: line.orderedQty,
          current: current,
          adding: adding,
        );
      }

      setState(() {
        line.tempScanned += adding;
        final total = line.scanned + line.tempScanned;

        // لو total >= orderedQty → يختفي لو _showCompleted = false
        if (total >= line.orderedQty && !_showCompleted) {
          selectedIndex = null;
        } else {
          selectedIndex = index;
        }
      });

      // Scroll لحد الصف لو لسه ظاهر
      if (selectedIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(selectedIndex!);
        });
      }

      _consumePendingQty();
    } else {
      _showInvalidBarcodeDialog(barcode);
    }

    _ensureBarcodeFocus();
  }

  /// Sort A→Z أو Z→A حسب الكود (SKU)
  void _toggleSort() {
    setState(() {
      _sortAscending = !_sortAscending;

      if (_sortAscending) {
        lines.sort((a, b) => a.code.compareTo(b.code)); // A → Z
      } else {
        lines.sort((a, b) => b.code.compareTo(a.code)); // Z → A
      }

      // بعد الترتيب نعيد بناء مفاتيح الصفوف
      _rowKeys = List.generate(lines.length, (_) => GlobalKey());
      selectedIndex = null;
    });
  }

  /// Toggle إظهار / إخفاء الأصناف اللي خلصت أو Over
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

  /// Scroll لصف معين في الجدول
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

  /// ===== Bottom Sheet: Line Details (اختياري) =====
  void _openLineDetailsSheet(_SoLine line) {
    final current = line.scanned + line.tempScanned;
    final remaining = (line.orderedQty - current).clamp(-999999, 999999);

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
                  Text("SKU: ${line.code}",
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text("U/M: ${line.unit}",
                      style: const TextStyle(color: Colors.black54)),
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
                  _pill(
                    "Remaining",
                    "${remaining < 0 ? 0 : remaining}",
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    ).whenComplete(_ensureBarcodeFocus);
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

  Future<bool> _confirmExit() async {
    final ok = await _showCancelConfirmDialog();
    if (ok != true) {
      Future.delayed(const Duration(milliseconds: 50), _ensureBarcodeFocus);
    }
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    // نبني DataRows حسب حالة كل لاين
    final List<DataRow> dataRows = [];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final total = line.scanned + line.tempScanned;

      final bool isCompleted = total == line.orderedQty;
      final bool isOver = total > line.orderedQty;

      // لو total >= orderedQty → نخفي الرو من الجدول لو مش مفعّل عرض الـ completed
      if (!_showCompleted && (isCompleted || isOver)) {
        continue;
      }

      final selected = i == selectedIndex;
      final rowKey = (i < _rowKeys.length) ? _rowKeys[i] : GlobalKey();

      dataRows.add(
        DataRow(
          selected: selected,
          color: MaterialStateProperty.resolveWith<Color?>(
                (states) {
              if (selected) return const Color(0xFFE0ECFF); // أزرق فاتح للمحدد
              if (isOver) return const Color(0xFFFFE5E5);   // أحمر فاتح لو Over
              if (isCompleted) return const Color(0xFFE5FFE5); // أخضر فاتح لو Completed
              return null;
            },
          ),
          onSelectChanged: (_) => _selectRow(i),
          cells: [
            DataCell(
              Container(
                key: rowKey,
                child: Text(line.code),
              ),
              onTap: () => _selectRow(i),
            ),
            DataCell(
              Text('${line.orderedQty}'),
              onTap: () => _selectRow(i),
            ),
            DataCell(
              Text('$total'),
              onTap: () => _selectRow(i),
            ),
            DataCell(
              Text(line.unit),
              onTap: () => _selectRow(i),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _ensureBarcodeFocus,
      child: WillPopScope(
        onWillPop: _confirmExit,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFF27AE60),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                if (await _confirmExit()) {
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
            title: Text(
              'ReScan - ${widget.soNumber}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: _toggleSort,
                icon: Icon(
                  _sortAscending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: Colors.white,
                ),
                tooltip: _sortAscending ? 'Sort A → Z' : 'Sort Z → A',
              ),
              IconButton(
                onPressed: _toggleShowCompleted,
                icon: Icon(
                  _showCompleted
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: Colors.white,
                ),
                tooltip: _showCompleted
                    ? 'Hide completed & over'
                    : 'Show completed & over',
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
                        horizontal: 16, vertical: 8),
                    child: Text(
                      "Pending Qty (for scan): $_pendingQty",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF27AE60)),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        showCheckboxColumn: true,
                        headingRowColor: MaterialStateProperty.all(
                            const Color(0xFFEFEFF4)),
                        columns: const [
                          DataColumn(
                              label: Text('SKU',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700))),
                          DataColumn(
                              label: Text('SOQ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700))),
                          DataColumn(
                              label: Text('Scanned',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700))),
                          DataColumn(
                              label: Text('U/M',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700))),
                        ],
                        rows: dataRows,
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal:
                      isTablet ? size.width * 0.06 : 16,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top:
                        BorderSide(color: Color(0xFFE6E6E6)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          crossAxisAlignment:
                          WrapCrossAlignment.center,
                          children: [
                            _chipButton('Clr', onTap: () {
                              if (selectedLine == null) return;
                              setState(() {
                                selectedLine!.tempScanned = 0;
                              });
                              _ensureBarcodeFocus();
                            }),
                            ElevatedButton.icon(
                              onPressed:
                              (selectedLine == null)
                                  ? null
                                  : _addQtyToSelectedLine,
                              icon:
                              const Icon(Icons.add_circle),
                              label: const Text(''),
                              style:
                              ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFF27AE60),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 14,
                                    vertical: 10),
                                shape:
                                RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                        8)),
                              ),
                            ),
                            _qtyBox(isTablet: isTablet),
                            OutlinedButton(
                              onPressed: _resetPendingQty,
                              child: const Text('Rest'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (selectedLine != null)
                          Text(
                            selectedLine!.desc.isEmpty
                                ? ''
                                : selectedLine!.desc,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.w600),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final ok =
                                  await _showCancelConfirmDialog();
                                  if (ok == true &&
                                      mounted) {
                                    Navigator.pop(
                                        context);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          10)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _done,
                                style: ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                  const Color(
                                      0xFF27AE60),
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                      vertical: 14),
                                  shape:
                                  RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          10)),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                      color:
                                      Colors.white,
                                      fontWeight:
                                      FontWeight.w700),
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
              Positioned(
                left: 0,
                top: 0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    controller: barcodeCtrl,
                    focusNode: _barcodeFocus,
                    autofocus: true,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (val) {
                      final s = val.trim();
                      if (s.isEmpty) return;
                      _applyScannedBarcode(s);
                      barcodeCtrl.clear();
                      _ensureBarcodeFocus();
                    },
                    decoration: const InputDecoration.collapsed(
                        hintText: ''),
                  ),
                ),
              ),
            ],
          ),
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
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _qtyBox({required bool isTablet}) {
    final tfWidth = isTablet ? 120.0 : 100.0;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _savePendingQty(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isTablet ? 18 : 16,
              ),
              decoration: const InputDecoration(
                hintText: 'qty',
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 3),
          ElevatedButton(
            onPressed: _savePendingQty,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              minimumSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('OK',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
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
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'PCS',
      scanned: first,
      tempScanned: second,
      barcodes: (json['barcodes'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }
}
