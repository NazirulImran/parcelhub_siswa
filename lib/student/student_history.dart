import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // <--- ADDED IMPORT
import 'receipt_screen.dart';
import '../utils.dart';

class StudentHistoryScreen extends StatelessWidget {
  const StudentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Collection History", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('status', isEqualTo: 'Collected')
            .orderBy('collected_at', descending: true) // Sort by latest
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final myHistory = snapshot.data!.docs.where((doc) {
             final data = doc.data() as Map<String, dynamic>;
             return data['student_id'] == user?.uid || data['recipient_email'] == user?.email;
          }).toList();

          if (myHistory.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  Text("No collection history found.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myHistory.length,
            itemBuilder: (context, index) {
              var data = myHistory[index].data() as Map<String, dynamic>;
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                  title: Text(data['tracking_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  
                  // FIXED: Shows full time now
                  subtitle: Text("Collected: ${formatTimestamp(data['collected_at'])}"), 
                  
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow("Shelf", data['shelf_location']),
                          _infoRow("Type", data['parcel_type'] ?? 'N/A'),
                          _infoRow("Payment", data['payment_method']),
                          
                          const SizedBox(height: 10),
                          
                          if (data['payment_method'] == 'Online' && data['receipt_image'] != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Payment Proof Uploaded:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(context: context, builder: (_) => Dialog(child: Image.network(data['receipt_image'])));
                                  },
                                  child: Container(
                                    height: 100,
                                    width: 100,
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                                    child: Image.network(
                                      data['receipt_image'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (c,o,s) => const Center(child: Icon(Icons.broken_image)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(data: data)));
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text("View Official Receipt"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6200EA),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}