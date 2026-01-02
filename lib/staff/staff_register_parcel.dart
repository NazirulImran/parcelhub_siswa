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
  
  // 1. RENAMED CONTROLLER (Old: _recipientController)
  final _remarkController = TextEditingController(); 
  
  final _otherTypeController = TextEditingController();
  
  bool _isManualMode = false;
  bool _isLoading = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String? _selectedType;
  final List<String> _parcelTypes = [
    'Box',
    'Bulky/Large Item',
    'Documents',
    'Soft Package',
    'Others'
  ];

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

  Future<void> _saveParcel() async {
    if (_trackingController.text.isEmpty || _shelfController.text.isEmpty || _selectedType == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields!"), backgroundColor: Colors.red));
      return;
    }

    String finalParcelType = _selectedType!;
    if (_selectedType == 'Others') {
      if (_otherTypeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please specify the type."), backgroundColor: Colors.red));
        return;
      }
      finalParcelType = _otherTypeController.text.trim();
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('parcels').add({
        'tracking_number': _trackingController.text.trim(),
        'shelf_location': _shelfController.text.trim(),
        
        // 2. UPDATED DATABASE FIELD
        // Changed key from 'recipient_email' to 'remark'
        'remark': _remarkController.text.trim(), 
        
        'parcel_type': finalParcelType,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 30),
              decoration: const BoxDecoration(
                color: Color(0xFF6200EA),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: FutureBuilder<String>(
                future: _getStaffName(),
                builder: (context, snapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hi, ${snapshot.data ?? '...'}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text("Select mode to register new items.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  );
                }
              ),
            ),

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

                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: "Parcel Type",
                            prefixIcon: const Icon(Icons.category, color: Color(0xFF6200EA)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          items: _parcelTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                          onChanged: (val) => setState(() => _selectedType = val),
                        ),
                        
                        if (_selectedType == 'Others') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _otherTypeController,
                            decoration: InputDecoration(
                              labelText: "Please specify type",
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // 3. UPDATED INPUT FIELD UI
                        // Replaced Email input with Remark input
                        TextFormField(
                          controller: _remarkController, // Uses the renamed controller
                          decoration: InputDecoration(
                            labelText: "Remark (Optional)", // New Label
                            prefixIcon: const Icon(Icons.note, color: Colors.grey), // New Icon
                            filled: true,
                            fillColor: Colors.grey.shade50,
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveParcel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6200EA),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isLoading ? Container() : const Icon(Icons.check_circle, color: Colors.white),
                            label: _isLoading 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : const Text("Register Parcel Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
              Text(title, style: TextStyle(color: isActive ? const Color(0xFF6200EA) : Colors.grey.shade600, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedInputField({required TextEditingController controller, required String label, required IconData icon, required bool isManual, required VoidCallback onTapScan}) {
    return GestureDetector(
      onTap: isManual ? null : onTapScan,
      child: AbsorbPointer(
        absorbing: !isManual,
        child: TextFormField(
          controller: controller,
          readOnly: !isManual,
          decoration: InputDecoration(
            labelText: label,
            hintText: isManual ? "Enter $label" : "Tap to scan...",
            prefixIcon: Icon(icon, color: isManual ? Colors.grey : const Color(0xFF6200EA)),
            suffixIcon: isManual ? null : const Icon(Icons.qr_code_scanner, color: Color(0xFF6200EA)),
            filled: true,
            fillColor: isManual ? Colors.grey.shade50 : const Color(0xFF6200EA).withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }
}