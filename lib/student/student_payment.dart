import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Storage
import 'dart:io';

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
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Quality 50 is good for storage
    
    if (image != null) {
      setState(() => _isLoading = true);
      
      try {
        File file = File(image.path);
        
        // 1. Create a reference to Firebase Storage
        // Naming format: receipts/parcelID_timestamp.jpg
        String fileName = 'receipts/${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

        // 2. Upload the file
        await storageRef.putFile(file);

        // 3. Get the Download URL
        String downloadUrl = await storageRef.getDownloadURL();

        // 4. Save the URL to Firestore (instead of base64)
        await FirebaseFirestore.instance.collection('parcels').doc(widget.docId).update({
          'status': 'Pending Verification',
          'payment_method': 'Online',
          'receipt_image': downloadUrl, // Saving URL now
          'student_id': FirebaseAuth.instance.currentUser?.uid,
        });

        if (!mounted) return;
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receipt Uploaded! Waiting for approval.")));

      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading: $e")));
      }
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
            
            // --- UPDATED: DISPLAY YOUR STATIC IMAGE ---
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 2)),
              child: Image.asset(
                'assets/images/duitnow.png', // Ensure this matches your file path
                width: 280,
                height: 350,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 280, 
                  width: 280, 
                  child: Center(child: Text("QR Image Not Found\nCheck assets folder", textAlign: TextAlign.center))
                ),
              ),
            ),
            // ------------------------------------------
            
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