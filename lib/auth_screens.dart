import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // Added Name Controller
  bool _loading = false;
  bool _isPasswordVisible = false;

  final _formKey = GlobalKey<FormState>();

  // --- VALIDATORS ---
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Required";
    if (value.length < 8) return "Min 8 characters";
    if (!value.contains(RegExp(r'[A-Z]'))) return "Need uppercase letter";
    if (!value.contains(RegExp(r'[a-z]'))) return "Need lowercase letter";
    return null;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (isLogin) {
        // --- LOGIN LOGIC ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        
        if (mounted) {
          // Fix: Explicitly confirm success and help navigation if needed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Logged in successfully!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
          // The StreamBuilder in main.dart handles the switch, 
          // but popping ensures we don't sit on this screen if it was pushed.
          // If this is the root, the StreamBuilder replaces it.
        }
      } else {
        // --- SIGN UP LOGIC ---
        UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );

        // Update Display Name
        if (_nameCtrl.text.isNotEmpty) {
          await userCred.user!.updateDisplayName(_nameCtrl.text.trim());
        }

        if (mounted) {
          // Show Success Placeholder/Dialog
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                   Icon(Icons.check_circle, color: Colors.green),
                   SizedBox(width: 10),
                   Text("Account Created"),
                ],
              ),
              content: const Text("Your account has been successfully created.\nPlease log in."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      isLogin = true; // Switch to Login mode
                      _passCtrl.clear();
                    });
                  }, 
                  child: const Text("Go to Login"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = "An error occurred";
        if (e.toString().contains("email-already-in-use")) {
          msg = "Email already used. Please login.";
        } else if (e.toString().contains("weak-password")) {
          msg = "Password is too weak.";
        } else {
          msg = e.toString().split('] ').last;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _forgotPassword() async {
    if (_emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email first")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reset link sent!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.medical_services_rounded, size: 64, color: Color(0xFF1565C0)),
                      const SizedBox(height: 24),
                      Text(
                        isLogin ? "Welcome Back" : "Create Account",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(height: 32),

                      // Full Name Field (Sign Up Only)
                      if (!isLogin) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? "Enter your full name" : null,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty || !v.contains('@') ? "Enter a valid email" : null,
                        decoration: const InputDecoration(
                          labelText: "Email Address",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_isPasswordVisible,
                        // Apply strict validation only on Sign Up
                        validator: isLogin ? (v) => v!.isEmpty ? "Required" : null : _validatePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          helperText: isLogin ? null : "Min 8 chars, Uppercase & Lowercase",
                          helperMaxLines: 2,
                        ),
                      ),

                      if (isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _forgotPassword, child: const Text("Forgot Password?")),
                        ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(isLogin ? "LOGIN" : "SIGN UP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Column(
                        children: [
                          Text(isLogin ? "No account yet?" : "Already have an account?", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isLogin = !isLogin;
                                _formKey.currentState?.reset();
                                _nameCtrl.clear();
                                _emailCtrl.clear();
                                _passCtrl.clear();
                              });
                            },
                            child: Text(isLogin ? "Sign Up" : "Login", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}