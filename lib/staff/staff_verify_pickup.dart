import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class StaffVerifyPickup extends StatefulWidget {
  const StaffVerifyPickup({super.key});

  @override
  State<StaffVerifyPickup> createState() => _StaffVerifyPickupState();
}

class _StaffVerifyPickupState extends State<StaffVerifyPickup> {
  bool _isScanning = true;
  String? _scannedCode;
  Map<String, dynamic>? _parcelData;
  String? _parcelDocId;

  // 1. Intelligent Parsing Logic
  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && _isScanning) {
      setState(() => _isScanning = false); 
      
      String rawCode = barcodes.first.rawValue ?? '';
      String extractedTracking = rawCode;

      // Check if it's the new "Rich Data" QR code
      if (rawCode.contains("Tracking: ")) {
        // Split by newline and look for the tracking line
        List<String> lines = rawCode.split('\n');
        for (String line in lines) {
          if (line.startsWith("Tracking: ")) {
            extractedTracking = line.replaceAll("Tracking: ", "").trim();
            break;
          }
        }
      }

      // Proceed with the clean tracking number
      _fetchParcelDetails(extractedTracking);
    }
  }

  Future<void> _fetchParcelDetails(String trackingNumber) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('parcels')
        .where('tracking_number', isEqualTo: trackingNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _scannedCode = trackingNumber;
        _parcelDocId = snapshot.docs.first.id;
        _parcelData = snapshot.docs.first.data();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parcel not found in database!")));
      setState(() => _isScanning = true);
    }
  }

  Future<void> _confirmCollection() async {
    if (_parcelDocId != null) {
      await FirebaseFirestore.instance.collection('parcels').doc(_parcelDocId).update({
        'status': 'Collected',
        'collected_at': DateTime.now().toString(),
      });
      if(!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Collection Verified!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Student QR"), backgroundColor: const Color(0xFF6200EA), foregroundColor: Colors.white),
      body: Column(
        children: [
          // Camera Scanner
          Expanded(
            flex: 2,
            child: _isScanning
                ? MobileScanner(onDetect: _onDetect)
                : Container(
                    color: Colors.black87,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 50),
                        onPressed: () => setState(() {
                          _isScanning = true;
                          _parcelData = null;
                        }),
                      ),
                    ),
                  ),
          ),
          
          // Parcel Details
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: _parcelData == null
                  ? const Center(child: Text("Scan a collection QR code to verify details"))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Parcel Found!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        Text("Tracking: $_scannedCode", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        // Added Extra Details for Staff Verification
                        _detailRow("Type", _parcelData!['parcel_type'] ?? 'Standard'),
                        _detailRow("Arrival", _parcelData!['arrival_date'] ?? 'N/A'),
                        _detailRow("Shelf", _parcelData!['shelf_location']),
                        
                        const SizedBox(height: 16),
                        
                        // Show Receipt if Online Payment
                        if (_parcelData!['payment_method'] == 'Online' && _parcelData!['receipt_image'] != null)
                           Expanded(
                             child: GestureDetector(
                               onTap: () {
                                 showDialog(context: context, builder: (_) => Dialog(child: Image.network(_parcelData!['receipt_image'])));
                               },
                               child: Container(
                                 margin: const EdgeInsets.symmetric(vertical: 10),
                                 decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                                 child: Image.network(
                                    _parcelData!['receipt_image'], 
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image)),
                                 ),
                               ),
                             ),
                           ),

                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _confirmCollection,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Confirm & Release Parcel", style: TextStyle(color: Colors.white)),
                          ),
                        )
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}