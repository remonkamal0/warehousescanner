import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReScanScreen extends StatefulWidget {
  final String soNumber; // رقم الـ S.O اللي جاي من الشاشة السابقة
  const ReScanScreen({super.key, required this.soNumber});

  @override
  State<ReScanScreen> createState() => _ReScanScreenState();
}

class _ReScanScreenState extends State<ReScanScreen> {
  // بيانات تجريبية (بدلها ببيانات API لاحقًا)
  final List<_SoLine> lines = [
    _SoLine(code: 'GLCWC1', desc: 'GAME LEAF CIGARILLOS WHITE CHOC', remaining: 3, scanned: 1, unit: 'ea'),
    _SoLine(code: 'SLRC',   desc: 'Desc SLRC',  remaining: 2, scanned: 0, unit: 'ea'),
    _SoLine(code: 'SLV',    desc: 'Desc SLV',   remaining: 4, scanned: 2, unit: 'ea'),
    _SoLine(code: 'SSLDL',  desc: 'Desc SSLDL', remaining: 5, scanned: 5, unit: 'ea'),
  ];

  int? selectedIndex;
  _SoLine? get selectedLine => (selectedIndex != null) ? lines[selectedIndex!] : null;

  final TextEditingController qtyCtrl = TextEditingController(text: '0');
  int get qty => int.tryParse(qtyCtrl.text) ?? 0;
  set qty(int v) => qtyCtrl.text = v.toString();

  @override
  void dispose() {
    qtyCtrl.dispose();
    super.dispose();
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
    final maxCanAdd = selectedLine!.remaining - selectedLine!.scanned;
    if (next > maxCanAdd) _showOverDialog(); // warning فقط
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
    final maxCanAdd = selectedLine!.remaining - selectedLine!.scanned;
    if (val > maxCanAdd) _showOverDialog(); // warning فقط
  }

  void _addQty() {
    if (selectedLine == null || qty == 0) return;

    setState(() {
      selectedLine!.scanned += qty;
      qty = 0;
    });

    final maxAllowed = selectedLine!.remaining;
    if (selectedLine!.scanned > maxAllowed) {
      _showOverDialog(); // warning فقط
    }
  }

  void _clearLine() {
    if (selectedLine == null) return;
    setState(() {
      selectedLine!.scanned = 0;
      qty = 0;
    });
  }

  void _done() {
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
              backgroundColor: Colors.green, // نفس اللون بتاعك
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Re-Scan - ${widget.soNumber}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // ===== جدول قابل للتمرير أفقياً ورأسياً (يحمي من overflow) =====
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFEFEFF4)),
                  columns: const [
                    DataColumn(label: Text('Product Code', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Remaining',    style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Sc',           style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('U/M',          style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                  rows: List.generate(lines.length, (i) {
                    final line = lines[i];
                    final selected = i == selectedIndex;
                    return DataRow(
                      selected: selected,
                      color: MaterialStateProperty.resolveWith<Color?>(
                            (states) => selected ? const Color(0xFFE0F7E9) : null,
                      ),
                      onSelectChanged: (_) => _selectRow(i),
                      cells: [
                        DataCell(
                          SizedBox(
                            width: isTablet ? 220 : 120,
                            child: Text(
                              line.code,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text('${line.remaining}')),
                        DataCell(Text('${line.scanned}')),
                        DataCell(Text(line.unit)),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

          // ===== اللوحة السفلية (Scroll أفقي لحماية overflow على شاشات صغيرة) =====
          Container(
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _chipButton('Clr Line', onTap: _clearLine),
                      const SizedBox(width: 10),
                      _chipButton('Add', onTap: _addQty),
                      const SizedBox(width: 12),
                      const Text('Qty:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      _qtyBox(isTablet: isTablet),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  selectedLine != null
                      ? '${selectedLine!.desc}\n${selectedLine!.code}'
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _done,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton(String label, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ElevatedButton(
        onPressed: selectedLine == null ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF5F6F8),
          foregroundColor: Colors.black87,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
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
          // Flexible حوالين SizedBox عشان المربع ما يعملش overflow
          Flexible(
            child: SizedBox(
              width: tfWidth,
              child: TextField(
                controller: qtyCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onQtyChanged,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 18 : 16,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                enabled: selectedLine != null,
              ),
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
  final String code;
  final String desc;
  final String unit;
  final int remaining;
  int scanned;

  _SoLine({
    required this.code,
    required this.desc,
    required this.remaining,
    required this.scanned,
    required this.unit,
  });
}
