import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffRegisterParcel extends StatefulWidget {
  const StaffRegisterParcel({super.key});

  @override
  State<StaffRegisterParcel> createState() => _StaffRegisterParcelState();
}

class _StaffRegisterParcelState extends State<StaffRegisterParcel> {
  final _trackingController = TextEditingController();
  final _shelfController = TextEditingController();
  final _recipientController = TextEditingController();
  bool _isManualMode = false; // Default to Scan mode
  bool _isLoading = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // 1. Fetch Staff Name for Greeting
  Future<String> _getStaffName() async {
    if (currentUser == null) return "Staff";
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      return userDoc['name'] ?? "Staff member";
    } catch (e) {
      return "Staff member";
    }
  }

  // 2. Barcode Scanner Logic
  void _scanBarcode(bool isShelf) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(isShelf ? "Scan Shelf Code" : "Scan Tracking Label", 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: MobileScanner(
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Scanned: ${barcodes.first.rawValue}"), backgroundColor: Colors.green)
                    );
                  }
                },
              ),
            ),
             TextButton.icon(
               onPressed: () => Navigator.pop(ctx), 
               icon: const Icon(Icons.close, color: Colors.white), 
               label: const Text("Cancel", style: TextStyle(color: Colors.white))
             )
          ],
        ),
      ),
    );
  }

  // 3. Save to Firebase Logic
  Future<void> _saveParcel() async {
    if (_trackingController.text.isEmpty || _shelfController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tracking & Shelf are required!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('parcels').add({
        'tracking_number': _trackingController.text.trim(),
        'shelf_location': _shelfController.text.trim(),
        'recipient_email': _recipientController.text.trim(), // Optional link to student
        'status': 'Awaiting Payment', 
        'arrival_date': DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now()),
        'payment_method': 'Pending',
        'registered_by': currentUser?.uid,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parcel Registered Successfully!"), backgroundColor: Colors.green));
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Register Incoming", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
             // --- SECTION 1: HEADER & GREETING ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 30),
              decoration: const BoxDecoration(
                color: Color(0xFF6200EA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: FutureBuilder<String>(
                future: _getStaffName(),
                builder: (context, snapshot) {
                  String name = snapshot.data ?? "...";
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hi, $name", 
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      const SizedBox(height: 4),
                      const Text("Select mode to register new items.", 
                        style: TextStyle(color: Colors.white70, fontSize: 14)
                      ),
                    ],
                  );
                }
              ),
            ),

             // --- SECTION 2: MAIN CONTENT CARD ---
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // --- MODE SELECTION TOGGLE ---
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              _buildModeToggle(title: "Scan Mode", icon: Icons.qr_code_scanner, isActive: !_isManualMode, onTap: () => setState(() => _isManualMode = false)),
                              _buildModeToggle(title: "Manual Key-in", icon: Icons.keyboard, isActive: _isManualMode, onTap: () => setState(() => _isManualMode = true)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text("Parcel Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        // --- CONDITIONAL INPUT FIELDS ---
                        // If SCAN Mode: Fields are read-only and open scanner on tap.
                        // If MANUAL Mode: Fields are standard text inputs.
                        
                        _buildAnimatedInputField(
                          controller: _trackingController, 
                          label: "Tracking Number", 
                          icon: Icons.local_shipping,
                          isManual: _isManualMode,
                          onTapScan: () => _scanBarcode(false)
                        ),

                        const SizedBox(height: 16),

                         _buildAnimatedInputField(
                          controller: _shelfController, 
                          label: "Shelf Location", 
                          icon: Icons.inventory,
                          isManual: _isManualMode,
                          onTapScan: () => _scanBarcode(true)
                        ),

                        const SizedBox(height: 16),

                        // Email is always manual entry
                        TextFormField(
                          controller: _recipientController,
                          decoration: InputDecoration(
                            labelText: "Student Email (Optional Link)",
                            prefixIcon: const Icon(Icons.email, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        
                        const SizedBox(height: 24),

                        // --- SUBMIT BUTTON ---
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveParcel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6200EA),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: _isLoading ? 0 : 4,
                            ),
                            icon: _isLoading ? Container() : const Icon(Icons.check_circle, color: Colors.white),
                            label: _isLoading 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text("Register Parcel Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for Mode Toggle Buttons
  Widget _buildModeToggle({required String title, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? const Color(0xFF6200EA) : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(
                color: isActive ? const Color(0xFF6200EA) : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal
              )),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for Conditional Input Fields
  Widget _buildAnimatedInputField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required bool isManual, 
    required VoidCallback onTapScan
  }) {
    return GestureDetector(
      onTap: isManual ? null : onTapScan, // If Scan mode, tapping opens scanner
      child: AbsorbPointer(
        absorbing: !isManual, // If Scan mode, block keyboard input
        child: TextFormField(
          controller: controller,
          readOnly: !isManual,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: isManual ? FloatingLabelBehavior.auto : FloatingLabelBehavior.always,
            hintText: isManual ? "Enter $label" : "Tap to scan...",
            prefixIcon: Icon(icon, color: isManual ? Colors.grey : const Color(0xFF6200EA)),
            suffixIcon: isManual 
                ? null // No icon in manual mode
                : Icon(Icons.qr_code_scanner, color: const Color(0xFF6200EA)), // Scan icon in scan mode
            filled: true,
            fillColor: isManual ? Colors.grey.shade50 : const Color(0xFF6200EA).withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: isManual ? Colors.transparent : const Color(0xFF6200EA).withOpacity(0.3))
            ),
          ),
        ),
      ),
    );
  }
}