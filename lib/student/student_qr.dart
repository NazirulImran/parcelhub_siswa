import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PickupQRPage extends StatelessWidget {
  final String tracking;
  final String shelf;
  final String arrival;
  final String type;


  const PickupQRPage({
    super.key, 
    required this.tracking, 
    required this.shelf,
    required this.arrival,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    // Combine all data into a single string for the QR Code
    final String qrPayload = "Tracking: $tracking\nShelf: $shelf\nType: $type\nArrival: $arrival";

    return Scaffold(
      backgroundColor: const Color(0xFF6200EA),
      appBar: AppBar(
        title: const Text("Pickup Ticket", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Scan at Counter", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Shelf: $shelf", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.purple)),
                const Divider(height: 40),
                
                // QR Code with encoded data
                QrImageView(data: qrPayload, size: 220),
                
                const SizedBox(height: 20),
                
                // Detailed Information
                _infoRow("Tracking No", tracking),
                const SizedBox(height: 8),
                _infoRow("Category", type),
                const SizedBox(height: 8),
                _infoRow("Arrival Time", arrival),
                
                const SizedBox(height: 30),
                const Text("Please present this to the staff at the counter.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}