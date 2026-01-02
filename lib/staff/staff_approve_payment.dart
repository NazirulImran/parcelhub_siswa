import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffApprovePayment extends StatelessWidget {
  const StaffApprovePayment({super.key});

  void _approvePayment(BuildContext context, String docId) {
    // 1. Update Status to 'Ready for Pickup'
    // 2. Ensure Payment Method is marked as Online
    FirebaseFirestore.instance.collection('parcels').doc(docId).update({
      'status': 'Ready for Pickup',
      'payment_status': 'Paid (Verified)',
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Verified! Student can now see the Pickup QR.")));
  }

  void _rejectPayment(BuildContext context, String docId) {
    FirebaseFirestore.instance.collection('parcels').doc(docId).update({
      'status': 'Awaiting Payment', // Revert status so student can upload again
      'payment_status': 'Rejected',
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Rejected. Student must upload again."), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Online Payments", style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('status', isEqualTo: 'Pending Verification')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No pending payments.", style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String docId = snapshot.data!.docs[index].id;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['tracking_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                            child: const Text("Online Payment", style: TextStyle(color: Colors.purple, fontSize: 12)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Shelf: ${data['shelf_location']}", style: const TextStyle(color: Colors.grey)),
                      const Divider(height: 24),
                      const Text("Receipt Proof:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      // Receipt Image Viewer (Network URL)
                      if (data['receipt_image'] != null && data['receipt_image'].toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 400, // Taller to see details
                            width: double.infinity,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                            child: Image.network(
                              data['receipt_image'], // Load URL
                              fit: BoxFit.contain, // Show full receipt
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (c, o, s) => const Center(child: Text("Error loading image")),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 100, 
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text("No Image Uploaded", style: TextStyle(color: Colors.grey))),
                        ),

                      const SizedBox(height: 20),
                      
                      // Action Buttons (Approve & Reject)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rejectPayment(context, docId),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              child: const Text("Reject"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approvePayment(context, docId),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text("Approve"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}