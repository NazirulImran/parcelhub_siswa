import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'staff_register_parcel.dart';
import 'staff_verify_pickup.dart';
import 'staff_approve_payment.dart';
import '../screens/auth_screen.dart';
import 'staff_parcel_details.dart';
import '../screens/profile_screen.dart'; // Import the shared ProfileScreen
import 'package:intl/intl.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  // --- Search Controller ---
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  String _selectedStatusFilter = 'All';
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Payment Pending', 
    'Ready for Pickup', 
    'Collected'
  ];

  String _formatDate(dynamic value) {
  if (value == null) return '-';
  if (value is Timestamp) {
    return DateFormat('dd/MM/yyyy').format(value.toDate());
  }
  return value.toString();
}


  @override
  void initState() {
    super.initState();
    // Listen to changes to update the UI in real-time
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to calculate fee
  double calculateParcelFee(double weightInKg) {
    if (weightInKg <= 2.0) return 0.50;
    if (weightInKg <= 3.0) return 1.00;
    if (weightInKg <= 5.0) return 2.00;
    return 3.00;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Portal', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        actions: [
          // --- NEW: Profile Button ---
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              // Navigate to the reusable ProfileScreen
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          // ---------------------------
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome, Staff Member!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // --- SEARCH BAR ---
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Tracking Number...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                  : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatusFilter,
                  isExpanded: true,
                  icon: const Icon(Icons.filter_list, color: Color(0xFF6200EA)),
                  items: _statusOptions.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status, style: const TextStyle(fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedStatusFilter = newValue;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Action Buttons ---
            Row(
              children: [
                Expanded(child: _ActionButton(icon: Icons.edit, label: "Register", color: Colors.blue, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffRegisterParcel())))),
                const SizedBox(width: 8),
                Expanded(child: _ActionButton(icon: Icons.attach_money, label: "Approvals", color: Colors.orange, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffApprovePayment())))), 
                const SizedBox(width: 8),
                Expanded(child: _ActionButton(icon: Icons.qr_code_scanner, label: "Release", color: Colors.green, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffVerifyPickup())))),
              ],
            ),
            const SizedBox(height: 24),

            const Text("Recent Parcels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // --- Parcel List ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('parcels').orderBy('arrival_date', descending: true).limit(50).snapshots(),
              builder: (context, snapshot) {
                 if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 
                 // --- UPDATED CLIENT SIDE FILTERING ---
                 var docs = snapshot.data!.docs.where((doc) {
                   var data = doc.data() as Map<String, dynamic>;
                   
                   // 1. Check Search Text
                   String tracking = (data['tracking_number'] ?? '').toString().toLowerCase();
                   bool matchesSearch = tracking.contains(_searchText);

                   // 2. Check Status Filter
                   String status = data['status'] ?? 'Pending';
                   bool matchesStatus = _selectedStatusFilter == 'All' || status == _selectedStatusFilter;
                   
                   // Return true only if BOTH match
                   return matchesSearch && matchesStatus; 
                 }).toList();

                 if (docs.isEmpty) {
                   return const Center(child: Padding(
                     padding: EdgeInsets.all(20.0),
                     child: Text("No parcels found matching your criteria.", style: TextStyle(color: Colors.grey)),
                   ));
                 }

                 return Column(
                   children: docs.map((doc) {
                     var data = doc.data() as Map<String, dynamic>;
                     return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffParcelDetailsPage(
                                  docId: doc.id,
                                  data: data,
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              data['tracking_number'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Status Row
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: data['status'] == 'Collected' ? Colors.green : Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['status'] ?? 'Pending',
                                        style: TextStyle(
                                          color: data['status'] == 'Collected' ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 4), // Spacing
                                  
                                  // 2. USE YOUR FUNCTION HERE
                                  Text(
                                    "Arrived: ${_formatDate(data['arrival_date'])}", 
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    _showEditParcelDialog(context, doc.id, data);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _confirmDelete(context, doc.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                   }).toList(),
                 );
              }
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Parcel"),
        content: const Text("Are you sure you want to remove this record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('parcels').doc(docId).delete();
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _showEditParcelDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final trackingCtrl = TextEditingController(text: data['tracking_number']);
    final shelfCtrl = TextEditingController(text: data['shelf_location']);
    final weightCtrl = TextEditingController(text: (data['weight'] ?? 0.0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Parcel Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: trackingCtrl, decoration: const InputDecoration(labelText: "Tracking Number")),
            const SizedBox(height: 10),
            TextField(controller: shelfCtrl, decoration: const InputDecoration(labelText: "Shelf Location")),
            const SizedBox(height: 10),
            TextField(
              controller: weightCtrl, 
              decoration: const InputDecoration(labelText: "Weight (kg)"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double? newWeight = double.tryParse(weightCtrl.text);
              if (newWeight == null || newWeight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Weight"), backgroundColor: Colors.red));
                return;
              }

              double newFee = calculateParcelFee(newWeight);

              await FirebaseFirestore.instance.collection('parcels').doc(docId).update({
                'tracking_number': trackingCtrl.text.trim(),
                'shelf_location': shelfCtrl.text.trim(),
                'weight': newWeight,
                'fee': newFee,
              });
              Navigator.pop(ctx);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}