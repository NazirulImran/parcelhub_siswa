import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class StaffApprovePayment extends StatelessWidget {
  const StaffApprovePayment({super.key});

  void _approvePayment(BuildContext context, String docId) {
    FirebaseFirestore.instance.collection('parcels').doc(docId).update({
      'status': 'Ready for Pickup',
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Approved!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Approve Payments"), backgroundColor: Colors.orange),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('status', isEqualTo: 'Pending Verification')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No pending payments."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String docId = snapshot.data!.docs[index].id;
              String? base64Image = data['receipt_image'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tracking: ${data['tracking_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text("Receipt Image:"),
                      const SizedBox(height: 8),
                      
                      // Display Receipt
                      if (base64Image != null && base64Image.isNotEmpty)
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                          child: Image.memory(base64Decode(base64Image), fit: BoxFit.cover),
                        )
                      else
                        const Text("No Image (Error)", style: TextStyle(color: Colors.red)),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _approvePayment(context, docId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Approve Payment & Generate QR"),
                        ),
                      ),
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