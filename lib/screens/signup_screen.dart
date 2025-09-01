import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      );

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _email.text.trim();
    final pass = _password.text;
    final uname = _username.text.trim();
    final unameLower = uname.toLowerCase();

    setState(() => _loading = true);

    try {
      // 1) Create auth user
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user!.uid;

      // 2) Reserve username + create profile atomically
      final db = FirebaseFirestore.instance;
      await db.runTransaction((txn) async {
        final unameRef = db.collection('usernames').doc(unameLower);
        final taken = await txn.get(unameRef);
        if (taken.exists) {
          throw 'USERNAME_TAKEN';
        }

        // Reserve the username: { uid: <owner uid> }
        txn.set(unameRef, {'uid': uid});

        // Public user profile
        final userRef = db.collection('users').doc(uid);
        txn.set(userRef, {
          'username': uname,
          'usernameLower': unameLower,
          'email': email,
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(_snack('Welcome, $uname!'));
      // Go to home and clear back stack
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on FirebaseAuthException catch (e) {
      String msg = 'Sign up failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already in use.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email.';
      } else if (e.code == 'weak-password') {
        msg = 'Password is too weak (min 6 chars).';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(_snack(msg));
      }
    } catch (e) {
      final msg = e == 'USERNAME_TAKEN'
          ? 'That username is taken. Try another.'
          : 'Could not create your account. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(_snack(msg));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFD9C63F);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Welcome to\nDesign Critique',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text('Create your new account',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),

            // FORM
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _Field(
                    controller: _username,
                    hint: 'Username',
                    icon: Icons.person_rounded,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Please enter a username';
                      if (t.length < 3) return 'Username is too short';
                      if (!RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(t)) {
                        return 'Only letters, numbers, _ and .';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _email,
                    hint: 'Email',
                    icon: Icons.mail_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Please enter your email';
                      if (!t.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    hint: 'Password',
                    icon: Icons.lock_rounded,
                    obscure: _obscure,
                    trailing: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                    ),
                    validator: (v) {
                      final t = v ?? '';
                      if (t.isEmpty) return 'Please enter a password';
                      if (t.length < 6) return 'Min 6 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Sign up button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: yellow,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SIGN UP'),
              ),
            ),
            const SizedBox(height: 12),

            // Link to login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? "),
                InkWell(
                  onTap: _loading
                      ? null
                      : () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.trailing,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black54),
          suffixIcon: trailing,
          hintText: hint,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
