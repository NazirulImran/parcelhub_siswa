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

  // Helper to show "Toast" messages
  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing to show new one immediately
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Function to handle Auth
  Future<void> _submitAuthForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final matric = _matricController.text.trim();

    // --- 1. Validation Logic ---
    
    // Check Required Fields for Registration
    if (!_isLogin) {
      if (name.isEmpty) {
        _showToast("Full Name is required.");
        return;
      }
      if (matric.isEmpty) {
        _showToast("Student/Staff ID is required.");
        return;
      }
    }

    // Check Email field if it is empty
    if (email.isEmpty) {
      _showToast("Email field is empty. Please input your email");
      return;
    }

    // Check Email Format
    if (!email.contains('@') || !email.contains('.')) {
      _showToast("Invalid email format. Please check your email.");
      return;
    }

    // Check if password field is empty
    if (password.isEmpty) {
      _showToast("Password field is empty. Please input your password");
      return;
    }

    // Check Password Length (Must be > 8 characters)
    if (password.length < 8) {
      _showToast("Password too short. It must be at least 8 characters.");
      return;
    }

    

    // --- 2. Firebase Processing ---
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        // Login Logic
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (!mounted) return;

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
          email: email,
          password: password,
        );

        // Save User Data
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'name': name,
          'matric_id': matric,
          'role': _role,
        });

        if (!mounted) return;

        if (_role == 'Staff') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StaffDashboard()));
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentHomeScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Authentication failed';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password.';
      }
      _showToast(errorMessage);
    } catch (e) {
      _showToast("An error occurred. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

                    // Registration Fields (Only show if Sign Up)
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nameController, 
                        decoration: const InputDecoration(labelText: 'Full Name *'), // Added * to indicate required
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _matricController, 
                        decoration: const InputDecoration(labelText: 'Student/Staff ID *'), // Added * to indicate required
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    TextFormField(
                      controller: _emailController, 
                      decoration: const InputDecoration(labelText: 'Email Address'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController, 
                      decoration: const InputDecoration(labelText: 'Password (min 8 chars)'),
                      obscureText: true,
                    ),
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