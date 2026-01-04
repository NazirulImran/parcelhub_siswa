import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'staff_register_parcel.dart';
import 'staff_verify_pickup.dart';
import 'staff_approve_payment.dart';
import '../screens/auth_screen.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Portal', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6200EA),
        actions: [
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
            const Text("Manage incoming parcels and verify collections", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // --- Action Buttons Row ---
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

            // --- Statistics Cards ---
            Row(
              children: [
                Expanded(child: _StatCard(title: "Today's Arrivals", count: "12", icon: Icons.inventory_2, color: Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _StatCard(title: "Pending Collection", count: "5", icon: Icons.access_time, color: Colors.orange)),
              ],
            ),
            
            const SizedBox(height: 24),
            const Text("Recent Parcels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            
            // --- Recent List Stream ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('parcels').orderBy('arrival_date', descending: true).limit(10).snapshots(),
              builder: (context, snapshot) {
                 if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 
                 return Column(
                   children: snapshot.data!.docs.map((doc) {
                     var data = doc.data() as Map<String, dynamic>;
                     return Card(
                       margin: const EdgeInsets.only(bottom: 8),
                       elevation: 2,
                       child: ListTile(
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         title: Text(data['tracking_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("Shelf: ${data['shelf_location']}"),
                             Text("Weight: ${data['weight']?.toString() ?? '0.0'} kg  •  Fee: RM ${(data['fee'] ?? 0).toStringAsFixed(2)}"),
                           ],
                         ),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             // --- EDIT BUTTON ---
                             IconButton(
                               icon: const Icon(Icons.edit, color: Colors.blue),
                               onPressed: () => _showEditParcelDialog(context, doc.id, data),
                             ),
                             // --- DELETE BUTTON ---
                             IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () {
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
                                           await FirebaseFirestore.instance.collection('parcels').doc(doc.id).delete();
                                         }, 
                                         child: const Text("Delete", style: TextStyle(color: Colors.red))
                                       ),
                                     ],
                                   ),
                                 );
                               },
                             ),
                           ],
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

  // --- EDIT DIALOG ---
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
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Weight must be a positive number!"), backgroundColor: Colors.red)
                );
                return; 
              }

              double newFee = calculateParcelFee(newWeight); // Recalculate fee

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

// --- Helper Functions ---
double calculateParcelFee(double weightInKg) {
  if (weightInKg <= 2.0) return 0.50;
  if (weightInKg <= 3.0) return 1.00;
  if (weightInKg <= 5.0) return 2.00;
  return 3.00;
}

// --- Helper Widgets ---
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, this.isOutlined = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.white : const Color(0xFF6200EA),
          border: isOutlined ? Border.all(color: Colors.grey.shade300) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isOutlined ? Colors.black54 : Colors.white),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isOutlined ? Colors.black54 : Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Icon(icon, color: color),
          ]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}