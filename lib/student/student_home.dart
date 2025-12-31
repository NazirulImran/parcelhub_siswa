import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../screens/auth_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  Map<String, dynamic>? _foundParcelData;
  String? _foundParcelId;
  bool _isSearching = false;
  String _statusMessage = "";

  // 1. Fetch User Name
  Future<String> _getUserName() async {
    if (currentUser == null) return "Student";
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      return userDoc['name'] ?? "Student";
    } catch (e) {
      return "Student";
    }
  }

  // 2. Search Logic
  Future<void> _searchParcel() async {
    if (_searchController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _statusMessage = "Searching...";
      _foundParcelData = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('parcels')
          .where('tracking_number', isEqualTo: _searchController.text.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _foundParcelId = snapshot.docs.first.id;
          _foundParcelData = snapshot.docs.first.data();
          _isSearching = false;
        });
      } else {
        setState(() {
          _statusMessage = "No parcel found with this tracking number.";
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("ParcelHub Siswa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6200EA),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header & Search (Same as before)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
              decoration: const BoxDecoration(
                color: Color(0xFF6200EA),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: FutureBuilder<String>(
                future: _getUserName(),
                builder: (context, snapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hello, ${snapshot.data ?? '...'}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text("Track your university parcels here.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  );
                }
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Enter Tracking Number...",
                        border: InputBorder.none,
                        suffixIcon: IconButton(icon: const Icon(Icons.search, color: Color(0xFF6200EA)), onPressed: _searchParcel),
                      ),
                      onSubmitted: (_) => _searchParcel(),
                    ),
                  ),
                ),
              ),
            ),

            // Parcel Card Area
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isSearching
                  ? const CircularProgressIndicator()
                  : _foundParcelData != null
                      ? _buildParcelCard(_foundParcelData!, _foundParcelId!)
                      : Container(
                          height: 150,
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Text(_statusMessage.isEmpty ? "Search to view details" : _statusMessage, style: TextStyle(color: Colors.grey[400])),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelCard(Map<String, dynamic> data, String docId) {
    String status = data['status'] ?? 'Unknown';
    Color statusColor = Colors.grey;
    if (status == 'Awaiting Payment') statusColor = Colors.orange;
    if (status == 'Pending Verification') statusColor = Colors.purple;
    if (status == 'Ready for Pickup') statusColor = Colors.green;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Status", style: TextStyle(color: Colors.white)),
                Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _detailRow("Tracking No", data['tracking_number']),
                const Divider(height: 24),
                _detailRow("Shelf Location", data['shelf_location']),
                const SizedBox(height: 20),
                
                // Logic for Buttons
                if (status == 'Awaiting Payment')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentChoiceModal(context, docId, data['tracking_number']), // <--- This is the key change!
                      icon: const Icon(Icons.payment),
                      label: const Text("Pay Now (RM 5.00)"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),

                if (status == 'Pending Verification')
                  const Text("Payment uploaded. Waiting for staff approval.", style: TextStyle(color: Colors.purple, fontStyle: FontStyle.italic)),

                if (status == 'Ready for Pickup')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToPickupQRPage(context, data['tracking_number'], data['shelf_location']),
                      icon: const Icon(Icons.qr_code),
                      label: const Text("View Pickup Ticket"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentChoiceModal(BuildContext context, String docId, String tracking) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Payment Method", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // OPTION 1: ONLINE
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.qr_code_2, color: Colors.purple),
              ),
              title: const Text("Pay Online (DuitNow)"),
              subtitle: const Text("Instant verification via Receipt"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(ctx); // Close modal
                _navigateToPaymentPage(context, docId, tracking); // Go to DuitNow Page
              },
            ),
            const Divider(),
            
            // OPTION 2: CASH
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.money, color: Colors.green),
              ),
              title: const Text("Pay Cash at Counter"),
              subtitle: const Text("Pay when you collect"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.pop(ctx); // Close modal
                
                // Update to Ready for Pickup immediately
                await FirebaseFirestore.instance.collection('parcels').doc(docId).update({
                  'status': 'Ready for Pickup',
                  'payment_method': 'Cash',
                  'student_id': currentUser?.uid,
                });
                
                // Refresh to show the 'View Pickup Ticket' button
                _searchParcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]);
  }

  // --- FULL PAGE: PAYMENT SCREEN ---
  void _navigateToPaymentPage(BuildContext context, String docId, String tracking) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(docId: docId, tracking: tracking)));
  }

  // --- FULL PAGE: PICKUP QR SCREEN ---
  void _navigateToPickupQRPage(BuildContext context, String tracking, String shelf) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PickupQRPage(tracking: tracking, shelf: shelf)));
  }
}

// --- NEW CLASS: FULL SCREEN PAYMENT PAGE ---
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

      // Update status to 'Pending Verification'
      await FirebaseFirestore.instance.collection('parcels').doc(widget.docId).update({
        'status': 'Pending Verification',
        'payment_method': 'Online',
        'receipt_image': base64Image,
        'student_id': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;
      Navigator.pop(context); // Go back home
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receipt Uploaded! Waiting for approval.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pay Online"), backgroundColor: const Color(0xFF6200EA)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Scan DuitNow QR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Amount to pay: RM 5.00", style: TextStyle(fontSize: 18, color: Colors.blue)),
            const SizedBox(height: 30),
            
            // Hardcoded QR Image (Replace with your own asset if you have one)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 2)),
              child: QrImageView(data: "00020101021226580014ID.LINK.BNM.QR01100000000000...", size: 280), // Fake DuitNow Data
            ),
            
            const SizedBox(height: 40),
            const Text("After paying, upload your receipt here:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadReceipt,
                icon: const Icon(Icons.cloud_upload),
                label: _isLoading ? const Text("Uploading...") : const Text("Upload Receipt & Submit"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EA)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW CLASS: FULL SCREEN PICKUP QR PAGE ---
class PickupQRPage extends StatelessWidget {
  final String tracking;
  final String shelf;
  const PickupQRPage({super.key, required this.tracking, required this.shelf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6200EA),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Collection Ticket", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Shelf: $shelf", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.purple)),
              const Divider(height: 40),
              QrImageView(data: tracking, size: 250),
              const SizedBox(height: 20),
              Text(tracking, style: const TextStyle(fontSize: 18, letterSpacing: 2)),
              const SizedBox(height: 10),
              const Text("Show this to the counter staff", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}