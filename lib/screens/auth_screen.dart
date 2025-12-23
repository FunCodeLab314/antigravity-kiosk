
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _isPasswordVisible = false;

  final _formKey = GlobalKey<FormState>();

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
    final auth = ref.read(firebaseAuthProvider);
    
    try {
      if (isLogin) {
        // --- LOGIN ---
        await auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        // Navigation handled by authState stream in main.dart
      } else {
        // --- SIGN UP ---
        UserCredential userCred = await auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );

        if (_nameCtrl.text.isNotEmpty) {
          await userCred.user!.updateDisplayName(_nameCtrl.text.trim());
        }

        // Sign out immediately so they have to log in manually
        await auth.signOut();

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Account Created")]),
              content: const Text("Your account has been successfully created.\nPlease log in."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      isLogin = true;
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
        if (e.toString().contains("email-already-in-use")) msg = "Email already used.";
        else if (e.toString().contains("weak-password")) msg = "Password is too weak.";
        else if (e.toString().contains("invalid-credential")) msg = "Invalid email or password.";
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Text(isLogin ? "Login" : "Sign Up"),
        centerTitle: true,
      ),
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
                      Text(isLogin ? "Welcome Back" : "Create Account", textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                      const SizedBox(height: 32),
                      
                      if (!isLogin) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? "Enter full name" : null,
                          decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty || !v.contains('@') ? "Enter valid email" : null,
                        decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email_outlined)),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_isPasswordVisible,
                        validator: isLogin ? (v) => v!.isEmpty ? "Required" : null : _validatePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          helperText: isLogin ? null : "Min 8 chars, Upper & Lowercase",
                          helperMaxLines: 2,
                        ),
                      ),
                      if (isLogin)
                         Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                               if(_emailCtrl.text.isEmpty) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter email to reset")));
                                 return;
                               }
                               try {
                                 await ref.read(firebaseAuthProvider).sendPasswordResetEmail(email: _emailCtrl.text.trim());
                                 if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset email sent!"), backgroundColor: Colors.green));
                               } catch(e) {
                                 // ignore
                               }
                            }, 
                            child: const Text("Forgot Password?")
                          ),
                        ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? "LOGIN" : "SIGN UP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                        child: Text(isLogin ? "Create an account" : "I already have an account", style: const TextStyle(fontWeight: FontWeight.bold)),
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
