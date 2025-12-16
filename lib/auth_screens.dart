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
  bool _loading = false;

  // NEW: State for password visibility
  bool _isPasswordVisible = false;

  final _formKey = GlobalKey<FormState>();

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(e.toString().split('] ').last)),
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
        const SnackBar(
          content: Text("Please enter your email first"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset link sent to your email!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      const Icon(
                        Icons.medical_services_rounded,
                        size: 64,
                        color: Color(0xFF1565C0),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isLogin ? "Welcome Back" : "Create Account",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLogin
                            ? "Sign in to manage kiosk"
                            : "Get started with PillPal",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),

                      // Fields
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty || !v.contains('@')
                            ? "Enter a valid email"
                            : null,
                        decoration: const InputDecoration(
                          labelText: "Email Address",
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        // Update this to use the state variable
                        obscureText: !_isPasswordVisible,
                        validator: (v) =>
                            v!.length < 6 ? "Password must be 6+ chars" : null,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          // Add the Eye Icon here
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),

                      if (isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: const Text("Forgot Password?"),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isLogin ? "LOGIN" : "SIGN UP",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FIXED: Toggle - Stacked vertically
                      Column(
                        children: [
                          Text(
                            isLogin
                                ? "No account yet?"
                                : "Already have an account?",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isLogin = !isLogin;
                                _formKey.currentState?.reset();
                              });
                            },
                            child: Text(
                              isLogin ? "Sign Up" : "Login",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
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
