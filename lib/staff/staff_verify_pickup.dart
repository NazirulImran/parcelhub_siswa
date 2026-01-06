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
  bool _isLoading = false;
  
  Map<String, dynamic>? _scannedData;
  String? _scannedDocId;

  // --- Helper: Calculate Fee (Same as in other files) ---
  double calculateParcelFee(double weightInKg) {
    if (weightInKg <= 2.0) return 0.50;
    if (weightInKg <= 3.0) return 1.00;
    if (weightInKg <= 5.0) return 2.00;
    return 3.00;
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return; // Prevent multiple triggers

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    setState(() {
      _isScanning = false; // Stop scanning momentarily
      _isLoading = true;
    });

    try {
      // 1. Search for parcel by Tracking Number
      final snapshot = await FirebaseFirestore.instance
          .collection('parcels')
          .where('tracking_number', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showError("Parcel not found!");
      } else {
        setState(() {
          _scannedDocId = snapshot.docs.first.id;
          _scannedData = snapshot.docs.first.data();
        });
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    setState(() => _isScanning = true); // Resume scanning
  }

  Future<void> _releaseParcel() async {
    if (_scannedDocId == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('parcels').doc(_scannedDocId).update({
        'status': 'Completed', // or 'Collected'
        'collected_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parcel Released Successfully!"), backgroundColor: Colors.green));
      
      // Reset to scanner
      setState(() {
        _scannedData = null;
        _scannedDocId = null;
        _isScanning = true;
        _isLoading = false;
      });

    } catch (e) {
      _showError("Failed to update status: $e");
      setState(() => _isLoading = false);
    }
  }

  void _cancelView() {
    setState(() {
      _scannedData = null;
      _scannedDocId = null;
      _isScanning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. If we have scanned data, show the FULL SCREEN Success Card
    if (_scannedData != null) {
      return _buildFullScreenSuccess();
    }

    // 2. Otherwise, show the Scanner (Half Screen style)
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan for Release", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Top Half: Scanner
          Expanded(
            flex: 5,
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : MobileScanner(onDetect: _onDetect),
          ),
          // Bottom Half: Instructions
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text("Align QR Code within the frame", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Scan the student's parcel QR code to verify details and release the item.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FULL SCREEN RESULT WIDGET ---
  Widget _buildFullScreenSuccess() {
    final data = _scannedData!;
    
    // Payment Logic
    String paymentMethod = data['payment_method'] ?? 'Unknown';
    double weight = (data['weight'] is int) ? (data['weight'] as int).toDouble() : (data['weight'] ?? 0.0);
    double fee = calculateParcelFee(weight);
    
    bool isCash = paymentMethod == 'Cash';
    bool isOnline = paymentMethod == 'Online' || paymentMethod == 'DuitNow';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify & Release", style: TextStyle(color: Colors.white)),
        backgroundColor: isCash ? Colors.orange : Colors.green, // Orange for Cash, Green for Online
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _cancelView,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 80, color: isCash ? Colors.orange : Colors.green),
                  const SizedBox(height: 10),
                  Text("Parcel Found!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isCash ? Colors.orange : Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Parcel Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow("Tracking No", data['tracking_number']),
                    const Divider(),
                    _infoRow("Shelf Location", data['shelf_location']),
                    const Divider(),
                    _infoRow("Student Name", data['student_name'] ?? 'N/A'), // Ensure this field exists or fetch user
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Details Card (The important part)
            Card(
              color: isCash ? Colors.orange.shade50 : Colors.green.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isCash ? Colors.orange : Colors.green, width: 1.5)
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Payment Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCash ? Colors.orange.shade800 : Colors.green.shade800)),
                    const SizedBox(height: 10),
                    
                    // Payment Type Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Payment Type:", style: TextStyle(fontSize: 16)),
                        Chip(
                          label: Text(paymentMethod.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: isCash ? Colors.orange : Colors.green,
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Payment Message
                    if (isCash) 
                       Row(
                         children: [
                           const Icon(Icons.monetization_on, color: Colors.orange, size: 30),
                           const SizedBox(width: 10),
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text("Collect Cash:", style: TextStyle(fontWeight: FontWeight.bold)),
                               Text("RM ${fee.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                             ],
                           )
                         ],
                       )
                    else 
                       const Row(
                         children: [
                           Icon(Icons.verified, color: Colors.green, size: 30),
                           SizedBox(width: 10),
                           Text("Payment has been done ✅", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                         ],
                       )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _releaseParcel,
                icon: const Icon(Icons.outbox, color: Colors.white),
                label: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("RELEASE PARCEL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6200EA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}