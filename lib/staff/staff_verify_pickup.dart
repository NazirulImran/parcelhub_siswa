import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  // Calculate Fee (needed for display before release)
  double calculateParcelFee(double weightInKg) {
    if (weightInKg <= 2.0) return 0.50;
    if (weightInKg <= 3.0) return 1.00;
    if (weightInKg <= 5.0) return 2.00;
    return 3.00;
  }

  //detect qr code/barcode
  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && _isScanning) {
      setState(() => _isScanning = false); 
      
      final String rawCode = barcodes.first.rawValue ?? '';
      String extractedTracking = rawCode;

      //use regular expression to isolate the tracking number only to query in database
      //regex will ignore extra text and find specific id
      final RegExp trackingRegex = RegExp(r"Tracking:\s*(.*)");
      //check if scanned text is matches the pattern we find (in trackingRegex)
      final Match? match = trackingRegex.firstMatch(rawCode);

      //if the pattern found, we grab specific tracking id out of full text
      //group 1 = Tracking: \s*(.*) .. the '.' is group (we ignore the "Tracking" label)
      if (match != null) {
        extractedTracking = match.group(1)?.trim() ?? extractedTracking; // if extraction fails. it will call the ori value
      }

      _fetchParcelDetails(extractedTracking);
    }
  }

  Future<void> _fetchParcelDetails(String trackingNumber) async {
    setState(() => _isLoading = true); //show spinning loading circle
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('parcels') 
          .where('tracking_number', isEqualTo: trackingNumber) //find tracking number
          .limit(1) //tracking number should be unique
          .get();

      if (snapshot.docs.isEmpty) {
        _showError("Parcel not found!"); //if tracking is not found
      } else {
        setState(() {
          _scannedDocId = snapshot.docs.first.id; //saves parcel unique id
          _scannedData = snapshot.docs.first.data(); //saves parcel data
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    setState(() {
      _isScanning = true;
      _isLoading = false;
    });
  }

  Future<void> _releaseParcel() async {
  if (_scannedDocId == null) return;

  setState(() => _isLoading = true);

  try {
    String formattedDate =
        DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now()); //set collected parcel date format

    await FirebaseFirestore.instance
        .collection('parcels')
        .doc(_scannedDocId)
        .update({ //update the parcel details
      'status': 'Collected',
      'collected_at': formattedDate, //set collected parcel date 
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Parcel Released Successfully!"),
        backgroundColor: Colors.green,
      ),
    );

    await Future.delayed(const Duration(seconds: 1));

    Navigator.pop(context); // BACK TO DASHBOARD
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
    if (_scannedData != null) {
      return _buildFullScreenSuccess();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan to Release Parcel", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : MobileScanner(onDetect: _onDetect),
          ),
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
                  const Text("Scan the student's parcel QR code to verify details.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenSuccess() {
    final data = _scannedData!;
    
    String paymentMethod = data['payment_method'] ?? 'Unknown';
    double weight = (data['weight'] is int) ? (data['weight'] as int).toDouble() : (data['weight'] ?? 0.0);
    double fee = calculateParcelFee(weight);
    
    bool isCash = paymentMethod == 'Cash';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify & Release", style: TextStyle(color: Colors.white)),
        backgroundColor: isCash ? Colors.orange : Colors.green,
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
                    _infoRow("Weight", "${weight} kg"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

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