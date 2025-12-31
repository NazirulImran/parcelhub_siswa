import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // For Scanning
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffRegisterParcel extends StatefulWidget {
  const StaffRegisterParcel({super.key});

  @override
  State<StaffRegisterParcel> createState() => _StaffRegisterParcelState();
}

class _StaffRegisterParcelState extends State<StaffRegisterParcel> {
  final _trackingController = TextEditingController();
  final _shelfController = TextEditingController();
  final _recipientController = TextEditingController();
  bool _isManual = false;

  void _scanBarcode(bool isShelf) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            setState(() {
              if (isShelf) {
                _shelfController.text = barcodes.first.rawValue ?? '';
              } else {
                _trackingController.text = barcodes.first.rawValue ?? '';
              }
            });
            Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  Future<void> _saveParcel() async {
    if (_trackingController.text.isEmpty || _shelfController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('parcels').add({
      'tracking_number': _trackingController.text,
      'shelf_location': _shelfController.text,
      'recipient_email': _recipientController.text, // Using email to link to student
      'status': 'Awaiting Payment', // Default Flow
      'arrival_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'payment_method': 'Pending',
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parcel Registered!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Parcel")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Entry Mode:"),
            Row(
              children: [
                Radio(value: false, groupValue: _isManual, onChanged: (v) => setState(() => _isManual = false)),
                const Text("Scan Barcode"),
                Radio(value: true, groupValue: _isManual, onChanged: (v) => setState(() => _isManual = true)),
                const Text("Manual Entry"),
              ],
            ),
            const SizedBox(height: 16),

            // Tracking Input
            TextFormField(
              controller: _trackingController,
              decoration: InputDecoration(
                labelText: "Tracking Number",
                suffixIcon: !_isManual 
                  ? IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanBarcode(false)) 
                  : null,
              ),
            ),
            const SizedBox(height: 16),

            // Shelf Input
            TextFormField(
              controller: _shelfController,
              decoration: InputDecoration(
                labelText: "Shelf Location",
                suffixIcon: !_isManual 
                  ? IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _scanBarcode(true)) 
                  : null,
              ),
            ),
            const SizedBox(height: 16),

            // Recipient (Email to link account)
            TextFormField(
              controller: _recipientController,
              decoration: const InputDecoration(labelText: "Student Email (for linking)"),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveParcel,
                child: const Text("Register Parcel"),
              ),
            )
          ],
        ),
      ),
    );
  }
}