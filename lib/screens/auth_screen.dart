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

  // 1. Helper: Show Error Toast
  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 2. Helper: Show Success Popup
  void _showSuccessDialog(String message, VoidCallback onOk) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Success", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onOk();
            },
            child: const Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- NEW: FORGOT PASSWORD LOGIC ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Forgot Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email. We will check if you are registered.", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => _handlePasswordResetCheck(resetEmailController.text.trim(), ctx),
            child: const Text("Reset Password"),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordResetCheck(String email, BuildContext dialogContext) async {
    if (email.isEmpty) {
      _showToast("Please enter an email address.");
      return;
    }

    // 1. Check if email exists in Database
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // CASE A: Email NOT found -> Show "Register First" Dialog
        Navigator.pop(dialogContext); // Close reset dialog
        _showNotRegisteredDialog(email);
      } else {
        // CASE B: Email found -> Send Reset Link
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        Navigator.pop(dialogContext); // Close reset dialog
        _showSuccessDialog("A password reset link has been sent to $email. Please check your inbox to update your password.", () {});
      }
    } catch (e) {
      Navigator.pop(dialogContext);
      _showToast("Error verifying email: $e");
    }
  }

  void _showNotRegisteredDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Email Not Registered", style: TextStyle(color: Colors.red)),
        content: const Text("We could not find an account with this email. Please register first."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              // Redirect to Register Page Logic
              setState(() {
                _isLogin = false; // Switch to Sign Up
                _emailController.text = email; // Pre-fill the email they typed
              });
            },
            child: const Text("Register Now"),
          ),
        ],
      ),
    );
  }
  // ----------------------------------

  Future<void> _submitAuthForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final matric = _matricController.text.trim();

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

    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (!mounted) return;

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (userDoc.exists) {
          String role = userDoc['role'];
          String userName = (userDoc.data() as Map<String, dynamic>).containsKey('name') ? userDoc['name'] : 'User';

          if (mounted) {
            setState(() => _isLoading = false);
            _showSuccessDialog("Welcome back $userName!", () {
              if (role == 'Staff') {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StaffDashboard()));
              } else {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentHomeScreen()));
              }
            });
          }
        }
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'name': name,
          'matric_id': matric,
          'role': _role,
        });

        if (mounted) {
          setState(() => _isLoading = false);
          _showSuccessDialog("Welcome $name to ParcelHub Siswa!", () {
            if (_role == 'Staff') {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StaffDashboard()));
            } else {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const StudentHomeScreen()));
            }
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String errorMessage = 'Authentication failed';
      if (e.code == 'email-already-in-use') errorMessage = 'This email is already registered.';
      else if (e.code == 'user-not-found') errorMessage = 'No user found with this email.';
      else if (e.code == 'wrong-password') errorMessage = 'Incorrect password.';
      _showToast(errorMessage);
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast("An error occurred. Please try again.");
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
            colors: [Color(0xFF6200EA), Color(0xFF90CAF9)],
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
                      TextFormField(
                        controller: _nameController, 
                        decoration: const InputDecoration(labelText: 'Full Name *'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _matricController, 
                        decoration: const InputDecoration(labelText: 'Student/Staff ID *'),
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
                    
                    // --- NEW: FORGOT PASSWORD BUTTON (Only in Login Mode) ---
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text("Forgot Password?", style: TextStyle(color: Colors.blue)),
                        ),
                      ),
                    // --------------------------------------------------------

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