import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ReceiptScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 1. Format Date nicely
    String formattedDate = "Unknown Date";
    if (data['collected_at'] != null) {
      try {
        DateTime date = DateTime.parse(data['collected_at']);
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
      } catch (e) {
        formattedDate = data['collected_at'].toString();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: const Text("Transaction Receipt", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- RECEIPT CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Success Icon
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text("Collected Successfully", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 8),
                  Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(thickness: 1, color: Colors.grey),
                  ),

                  // Receipt Details
                  _buildDetailRow("Tracking No.", data['tracking_number'], isBold: true),
                  _buildDetailRow("Parcel Type", data['parcel_type'] ?? 'Standard'),
                  _buildDetailRow("Shelf Loc", data['shelf_location']),
                  
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow("Payment Method", data['payment_method']),
                        const SizedBox(height: 8),
                        _buildDetailRow("Amount", "RM 5.00", isBold: true),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(
                      thickness: 1, 
                      color: Colors.grey, 
                      //style: BorderStyle.none
                    ), 
                    // Note: Flutter doesn't have dashed lines built-in easily for Divider, solid is standard.
                  ),

                  // Footer
                  const Text("ParcelHub Siswa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text("Managed by University Logistics", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text("Thank you!", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF6200EA)),
                ),
                child: const Text("Close Receipt", style: TextStyle(fontSize: 16, color: Color(0xFF6200EA))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500, 
              fontSize: 15, 
              color: Colors.black87
            )
          ),
        ],
      ),
    );
  }
}