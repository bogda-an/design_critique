import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 140),
        ),
      );
  }

  Future<void> _signUp() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    final pass = _password.text;

    // Basic client-side checks
    if (username.isEmpty || email.isEmpty || pass.isEmpty) {
      _showMessage('Please fill all fields');
      return;
    }
    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters');
      return;
    }
    if (pass.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }

    // Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final unameLower = username.toLowerCase();
    String? createdUid;
    bool usernameReserved = false;

    try {
      // 1) Create auth user
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      createdUid = cred.user!.uid;

      // 2) Reserve username atomically (unique) inside a transaction
      await db.runTransaction((tx) async {
        final unameRef = db.collection('usernames').doc(unameLower);
        final snap = await tx.get(unameRef);
        if (snap.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'username-taken',
            message: 'That username is already taken.',
          );
        }
        tx.set(unameRef, {'uid': createdUid});
      });
      usernameReserved = true;

      // 3) Create user profile document
      await db.collection('users').doc(createdUid).set({
        'username': username,
        'usernameLower': unameLower,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // close loading
      Navigator.pushReplacementNamed(context, '/home'); // navigate ONLY after success
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Email already in use.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'weak-password':
          msg = 'Password is too weak.';
          break;
        default:
          msg = e.message ?? 'Sign up failed. Please try again.';
      }
      _showMessage(msg);
      // Clean up auth user if partially created but not saved
      if (createdUid != null) {
        try {
          await auth.currentUser?.delete();
        } catch (_) {}
      }
    } on FirebaseException catch (e) {
      // Firestore failures (e.g., username taken, write errors)
      if (mounted) Navigator.pop(context);
      String msg = e.message ?? 'Could not save your account. Please try again.';
      if (e.code == 'username-taken') {
        msg = 'That username is already taken.';
      }
      _showMessage(msg);

      // Clean up: delete reserved username (if any) and delete auth user so you’re not “logged in”
      if (usernameReserved) {
        try {
          await db.collection('usernames').doc(unameLower).delete();
        } catch (_) {}
      }
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
    } catch (_) {
      if (mounted) Navigator.pop(context);
      _showMessage('Something went wrong. Please try again.');
      // Clean up as a safety net
      if (usernameReserved) {
        try {
          await db.collection('usernames').doc(unameLower).delete();
        } catch (_) {}
      }
      try {
        await auth.currentUser?.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fixed button + footer (same placement as Login)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _signUp,
                child: const Text(
                  'SIGN UP',
                  style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () => Navigator.popAndPushNamed(context, '/login'),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // HERO IMAGE (edge to edge, same crop as Login)
            SizedBox(
              height: 320,
              width: double.infinity,
              child: Image.asset(
                'assets/images/pencils.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.35),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text('Welcome to',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text('Design Critique',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text('Create your new account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 24),

                  // Username
                  Material(
                    elevation: 2,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(32),
                    child: TextField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 12, right: 6),
                          child: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  Material(
                    elevation: 2,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(32),
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 12, right: 6),
                          child: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  Material(
                    elevation: 2,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(32),
                    child: TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 6),
                          child: Icon(Icons.lock_outline),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
