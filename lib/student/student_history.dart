import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

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
            .where('status', isEqualTo: 'Collected') // Only show collected items
            // Note: In a real app, you might want to filter by 'recipient_email' or 'student_id' too
            // .where('student_id', isEqualTo: user?.uid) 
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Filter locally if needed (e.g., if you don't have composite indexes setup)
          final myHistory = snapshot.data!.docs.where((doc) {
             // Logic: Check if it belongs to this user (either by ID or Email match)
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
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                  title: Text(data['tracking_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Collected: ${data['collected_at']?.toString().substring(0,10) ?? 'N/A'}"),
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
                                const Text("Receipt:", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                                  child: Image.network(
                                    data['receipt_image'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (c,o,s) => const Center(child: Text("Image Error")),
                                  ),
                                ),
                              ],
                            )
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