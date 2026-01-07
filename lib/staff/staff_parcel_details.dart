import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 

class StaffParcelDetailsPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const StaffParcelDetailsPage({super.key, required this.docId, required this.data});

  // --- UPDATED Helper to safely format date ---
  String _formatDate(dynamic value) {
    if (value == null) return 'Not collected yet';
    
    // 1. If it's a Firestore Timestamp (Old Data)
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd hh:mm a').format(value.toDate());
    }
    
    // 2. If it's already a String (New Data)
    if (value is String) {
      return value;
    }

    return 'Invalid Date';
  }

  @override
  Widget build(BuildContext context) {
    // Extract Data safely
    String tracking = data['tracking_number'] ?? 'N/A';
    String shelf = data['shelf_location'] ?? 'N/A';
    String status = data['status'] ?? 'Unknown';
    String type = data['parcel_type'] ?? 'Standard';
    String arrival = data['arrival_date'] ?? 'N/A';
    
    // Use helper to format collected_at (Handles both formats now)
    String collectedAt = _formatDate(data['collected_at']); 
    
    String remark = data['remark'] ?? 'No remarks';
    
    // Numbers
    double weight = (data['weight'] is int) ? (data['weight'] as int).toDouble() : (data['weight'] ?? 0.0);
    double fee = (data['fee'] is int) ? (data['fee'] as int).toDouble() : (data['fee'] ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parcel Details", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Card: Tracking & Status
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text("Tracking Number", style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(tracking, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: status == 'Collected' ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text("Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Details List
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _detailRow(Icons.inventory, "Shelf Location", shelf),
                    _divider(),
                    _detailRow(Icons.category, "Parcel Type", type),
                    _divider(),
                    _detailRow(Icons.scale, "Weight", "$weight kg"),
                    _divider(),
                    _detailRow(Icons.attach_money, "Fee", "RM ${fee.toStringAsFixed(2)}"),
                    _divider(),
                    _detailRow(Icons.calendar_today, "Arrival Date", arrival),
                    _divider(),
                    _detailRow(Icons.check_circle_outline, "Collected At", collectedAt), 
                     _divider(),
                    _detailRow(Icons.note, "Remark", remark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6200EA), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(color: Colors.grey.shade200, height: 1);
  }
}