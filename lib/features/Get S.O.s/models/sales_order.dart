class SalesOrder {
  final int soID;
  final String soNumber;
  final String customerName;
  final String soDate;
  final String soStatus;
  final double amount;
  final int itemsCount;
  final String soGUID;
  final String txnNumber;
  final String txnID; // مهم علشان ندخل بيه على المنتجات

  const SalesOrder({
    required this.soID,
    required this.soNumber,
    required this.customerName,
    required this.soDate,
    required this.soStatus,
    required this.amount,
    required this.itemsCount,
    required this.soGUID,
    required this.txnNumber,
    required this.txnID,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      soID: json['soID'],
      soNumber: json['soNumber'],
      customerName: json['customerName'],
      soDate: json['soDate'],
      soStatus: json['soStatus'],
      amount: (json['amount'] as num).toDouble(),
      itemsCount: json['itemsCount'],
      soGUID: json['soGUID'],
      txnNumber: json['txnNumber'],
      txnID: json['txnID'].toString(), // لو رجع int هنحوّله نص
    );
  }
}
