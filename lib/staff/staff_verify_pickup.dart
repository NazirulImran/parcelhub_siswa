import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Function called when QR is detected
  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && _isScanning) {
      setState(() => _isScanning = false); // Stop scanning momentarily
      String code = barcodes.first.rawValue ?? '';
      _fetchParcelDetails(code);
    }
  }

  // Find parcel in Firestore
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
      // Not found, resume scanning
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parcel not found!")));
      setState(() => _isScanning = true);
    }
  }

  // Mark as collected
  Future<void> _confirmCollection() async {
    if (_parcelDocId != null) {
      await FirebaseFirestore.instance.collection('parcels').doc(_parcelDocId).update({
        'status': 'Collected',
        'collected_at': DateTime.now().toString(),
      });
      Navigator.pop(context); // Go back to dashboard
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Collection Verified!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Student QR")),
      body: Column(
        children: [
          // Top Half: Camera Scanner
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
          
          // Bottom Half: Parcel Details
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
                        Text("Shelf Location: ${_parcelData!['shelf_location']}"),
                        Text("Payment Status: ${_parcelData!['payment_method']}"),
                        const SizedBox(height: 24),
                        
                        // Show Receipt if Online Payment
                        if (_parcelData!['payment_method'] == 'Online' && _parcelData!['receipt_image'] != null)
                           Expanded(
                             child: GestureDetector(
                               onTap: () {
                                 // Show full screen receipt
                               },
                               child: Container(
                                 decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                                 child: const Center(child: Text("Tap to view Receipt Image")),
                               ),
                             ),
                           ),
                        
                        if (_parcelData!['payment_method'] == 'Cash')
                           Container(
                             padding: const EdgeInsets.all(12),
                             color: Colors.orange.shade100,
                             child: const Row(
                               children: [
                                 Icon(Icons.warning, color: Colors.orange),
                                 SizedBox(width: 8),
                                 Expanded(child: Text("Collect RM 5.00 Cash from student!", style: TextStyle(fontWeight: FontWeight.bold))),
                               ],
                             ),
                           ),

                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _confirmCollection,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Confirm & Release Parcel"),
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
}