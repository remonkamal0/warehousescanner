import 'package:flutter/material.dart';
import '../models/sales_order.dart';

class SalesOrderCard extends StatelessWidget {
  final SalesOrder so;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const SalesOrderCard({
    super.key,
    required this.so,
    required this.isSelected,
    required this.onTap,
    this.primaryColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 6 : 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected
                ? LinearGradient(
              colors: [
                primaryColor.withOpacity(0.08),
                primaryColor.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
          ),
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_off,
                color: isSelected ? primaryColor : Colors.grey,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "S.O.#${so.soNumber}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected ? primaryColor : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      so.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? primaryColor.withOpacity(0.8) : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor, width: 1),
                    ),
                    child: Text(
                      so.soStatus,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    so.soDate.split("T")[0],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
