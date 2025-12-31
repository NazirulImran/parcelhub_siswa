import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../screens/auth_screen.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ParcelHub Siswa', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parcels')
            .where('recipient_email', isEqualTo: user?.email) // Assumes email matching
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var parcels = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: parcels.length,
            itemBuilder: (context, index) {
              var data = parcels[index].data() as Map<String, dynamic>;
              String docId = parcels[index].id;
              String status = data['status'];
              
              Color statusColor = Colors.grey;
              if (status == 'Arrived') statusColor = Colors.blue;
              if (status == 'Awaiting Payment') statusColor = Colors.orange;
              if (status == 'Ready for Pickup') statusColor = Colors.green;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['tracking_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(
                            label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: statusColor,
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Shelf: ${data['shelf_location']}"),
                      Text("Arrival: ${data['arrival_date']}"),
                      const SizedBox(height: 16),
                      
                      // Logic for Buttons based on Status
                      if (status == 'Awaiting Payment')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showPaymentModal(context, docId, data['tracking_number']),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text('Pay RM 5.00 Now'),
                          ),
                        ),
                      
                      if (status == 'Ready for Pickup')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              const Text("Your parcel is ready for collection!", style: TextStyle(color: Colors.green)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _showPickupQR(context, data['tracking_number'], data['shelf_location']),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA)),
                                  child: const Text('Show Collection QR Code'),
                                ),
                              ),
                            ],
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

  // 1. Payment Modal (Online or Cash)
  void _showPaymentModal(BuildContext context, String docId, String tracking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Complete Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Amount: RM 5.00", style: TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue),
              title: const Text("Pay Online"),
              subtitle: const Text("Scan DuitNow QR"),
              onTap: () {
                Navigator.pop(ctx);
                _showDuitNowQR(context, docId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text("Pay Cash"),
              subtitle: const Text("Pay at counter"),
              onTap: () {
                // Cash logic: Just update status to Ready for Pickup but mark as 'Cash Due'
                 FirebaseFirestore.instance.collection('parcels').doc(docId).update({
                  'status': 'Ready for Pickup',
                  'payment_method': 'Cash',
                  'payment_status': 'Pending at Counter'
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 2. DuitNow Logic
  void _showDuitNowQR(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/QR_code_for_mobile_English_Wikipedia.svg/1200px-QR_code_for_mobile_English_Wikipedia.svg.png', height: 200), // Placeholder QR
            const Text("Scan with Banking App"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Upload Receipt Logic
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                   // Convert to Base64 to save storage cost
                   File file = File(image.path);
                   List<int> bytes = await file.readAsBytes();
                   String base64Image = base64Encode(bytes);

                   await FirebaseFirestore.instance.collection('parcels').doc(docId).update({
                     'status': 'Ready for Pickup',
                     'payment_method': 'Online',
                     'receipt_image': base64Image,
                   });
                   Navigator.pop(ctx);
                }
              },
              child: const Text("I've Paid (Upload Receipt)"),
            )
          ],
        ),
      ),
    );
  }

  // 3. Pickup QR Logic
  void _showPickupQR(BuildContext context, String tracking, String shelf) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: 500,
        child: Column(
          children: [
            const Text("Collection QR Code", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6200EA))),
            const Text("Show this to staff", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            QrImageView(
              data: tracking, // The data staff scans
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                children: [
                   Text("Shelf: $shelf", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                   const Text("Please bring exact change if paying cash."),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}