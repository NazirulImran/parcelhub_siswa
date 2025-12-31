import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student/student_home.dart';
import '../staff/staff_dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  String _role = 'Student'; // Default role
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _matricController = TextEditingController();
  bool _isLoading = false;

  // Function to handle Auth
  Future<void> _submitAuthForm() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        // Login Logic
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        // Fetch role from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (userDoc.exists) {
          String role = userDoc['role'];
          if (role == 'Staff') {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StaffDashboard()));
          } else {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentHomeScreen()));
          }
        }
      } else {
        // Sign Up Logic
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Save User Data
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'matric_id': _matricController.text.trim(),
          'role': _role,
        });

        if (_role == 'Staff') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StaffDashboard()));
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentHomeScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Authentication failed')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6200EA), Color(0xFF90CAF9)], // Purple to Blue
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF6200EA)),
                    const SizedBox(height: 16),
                    const Text('ParcelHub Siswa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6200EA))),
                    const Text('University Parcel Management System', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    
                    // Toggle Login/Signup
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _isLogin = true),
                            style: TextButton.styleFrom(
                              backgroundColor: _isLogin ? const Color(0xFF6200EA) : Colors.grey[200],
                              foregroundColor: _isLogin ? Colors.white : Colors.black,
                            ),
                            child: const Text('Login'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _isLogin = false),
                            style: TextButton.styleFrom(
                              backgroundColor: !_isLogin ? const Color(0xFF6200EA) : Colors.grey[200],
                              foregroundColor: !_isLogin ? Colors.white : Colors.black,
                            ),
                            child: const Text('Sign Up'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Role Selection (Radio)
                    Row(
                      children: [
                        const Text('I am a: '),
                        Radio<String>(
                          value: 'Student',
                          groupValue: _role,
                          onChanged: (val) => setState(() => _role = val!),
                        ),
                        const Text('Student'),
                        Radio<String>(
                          value: 'Staff',
                          groupValue: _role,
                          onChanged: (val) => setState(() => _role = val!),
                        ),
                        const Text('Staff'),
                      ],
                    ),

                    if (!_isLogin) ...[
                      TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _matricController, decoration: const InputDecoration(labelText: 'Student/Staff ID')),
                      const SizedBox(height: 12),
                    ],
                    
                    TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitAuthForm,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isLogin ? 'Login' : 'Create Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}