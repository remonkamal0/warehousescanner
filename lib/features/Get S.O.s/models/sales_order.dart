class SalesOrder {
  final int soID;
  final String soNumber;
  final String customerName;
  final String soDate;
  final String soStatus;

  const SalesOrder({
    required this.soID,
    required this.soNumber,
    required this.customerName,
    required this.soDate,
    required this.soStatus,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      soID: json['soID'],
      soNumber: json['soNumber'],
      customerName: json['customerName'],
      soDate: json['soDate'],
      soStatus: json['soStatus'],
    );
  }
}
