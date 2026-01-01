import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth_screen.dart';
import '../screens/profile_screen.dart'; 
import 'student_history.dart';           
import 'student_payment.dart'; // IMPORT PAYMENT PAGE
import 'student_qr.dart';      // IMPORT QR PAGE

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

  Future<String> _getUserName() async {
    if (currentUser == null) return "Student";
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      return userDoc['name'] ?? "Student";
    } catch (e) {
      return "Student";
    }
  }

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
                Navigator.pop(ctx);
                _navigateToPaymentPage(context, docId, tracking);
              },
            ),
            const Divider(),
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
                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('parcels').doc(docId).update({
                  'status': 'Ready for Pickup',
                  'payment_method': 'Cash',
                  'student_id': currentUser?.uid,
                });
                _searchParcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPaymentPage(BuildContext context, String docId, String tracking) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(docId: docId, tracking: tracking)));
  }

  void _navigateToPickupQRPage(BuildContext context, String tracking, String shelf, String arrival, String type) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PickupQRPage(
      tracking: tracking, 
      shelf: shelf,
      arrival: arrival,
      type: type,
    )));
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
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _MenuButton(
                    icon: Icons.history, 
                    label: "History", 
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentHistoryScreen())),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _MenuButton(
                    icon: Icons.help_outline, 
                    label: "Help", 
                    color: Colors.orange,
                    onTap: () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact parcelhub@siswa.edu.my for support.")));
                    },
                  )),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                const Divider(height: 24),
                _detailRow("Type", data['parcel_type'] ?? 'Standard'),
                const SizedBox(height: 20),
                
                if (status == 'Awaiting Payment')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentChoiceModal(context, docId, data['tracking_number']),
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
                      onPressed: () => _navigateToPickupQRPage(
                        context, 
                        data['tracking_number'], 
                        data['shelf_location'],
                        data['arrival_date'] ?? 'N/A',
                        data['parcel_type'] ?? 'Standard'
                      ),
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

  Widget _detailRow(String title, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]);
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))]),
        child: Column(
          children: [
            CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}