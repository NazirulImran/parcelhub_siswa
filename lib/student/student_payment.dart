import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:convert';

class PaymentPage extends StatefulWidget {
  final String docId;
  final String tracking;
  const PaymentPage({super.key, required this.docId, required this.tracking});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isLoading = false;

  Future<void> _uploadReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
    
    if (image != null) {
      setState(() => _isLoading = true);
      File file = File(image.path);
      List<int> bytes = await file.readAsBytes();
      String base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('parcels').doc(widget.docId).update({
        'status': 'Pending Verification',
        'payment_method': 'Online',
        'receipt_image': base64Image,
        'student_id': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receipt Uploaded! Waiting for approval.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Online", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Scan DuitNow QR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Ref: ${widget.tracking}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 2)),
              child: QrImageView(data: "00020101021226580014ID.LINK.BNM.QR01100000000000...", size: 280),
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadReceipt,
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: _isLoading 
                  ? const Text("Uploading...", style: TextStyle(color: Colors.white))
                  : const Text("Upload Receipt & Submit", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}