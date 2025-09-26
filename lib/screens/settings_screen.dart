import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_bottom_nav.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool saving = false;

  Future<void> _pickAndUploadPhoto() async {
    final fa.User user = fa.FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;

    setState(() => saving = true);
    try {
      final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');

      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: x.mimeType ?? 'image/jpeg'));
      } else {
        await ref.putFile(File(x.path));
      }

      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoUrl': url});
      await user.updatePhotoURL(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to upload photo')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _editText({
    required String title,
    String initial = '',
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    required Future<void> Function(String) onSave,
  }) async {
    final c = TextEditingController(text: initial);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              keyboardType: keyboardType,
              obscureText: obscure,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (ok != true) return;

    setState(() => saving = true);
    try {
      await onSave(c.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to update')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changeEmailDirect() async {
    final usersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(fa.FirebaseAuth.instance.currentUser!.uid);

    final emailC = TextEditingController(
      text: fa.FirebaseAuth.instance.currentUser!.email ?? '',
    );
    final passC = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Change email', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passC,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update'))),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final newEmail = emailC.text.trim();
    final password = passC.text;
    if (newEmail.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email and password.')));
      return;
    }

    setState(() => saving = true);
    try {
      final fa.User current = fa.FirebaseAuth.instance.currentUser!;
      final cred = fa.EmailAuthProvider.credential(email: current.email!, password: password);
      await current.reauthenticateWithCredential(cred);

      await current.verifyBeforeUpdateEmail(newEmail);

      await usersRef.update({
        'pendingEmail': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification sent to $newEmail. Check your inbox.')),
      );
    } on fa.FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = e.message ?? 'Failed to start email change.';
      if (e.code == 'requires-recent-login') msg = 'Please sign in again and retry (recent login required).';
      if (e.code == 'email-already-in-use') msg = 'That email is already in use.';
      if (e.code == 'invalid-email') msg = 'Invalid email address.';
      if (e.code == 'wrong-password') msg = 'Incorrect password.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _resendVerificationForPendingEmail(String pendingEmail) async {
    final fa.User current = fa.FirebaseAuth.instance.currentUser!;
    setState(() => saving = true);
    try {
      await current.verifyBeforeUpdateEmail(pendingEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification re-sent to $pendingEmail.')),
      );
    } on fa.FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to resend verification.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  
  Future<void> _confirmAndLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be signed out of this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await fa.FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
      }
    }
  }
  Future<void> _cancelPendingEmailChange(
    DocumentReference<Map<String, dynamic>> usersRef) async {
    setState(() => saving = true);
    try {
      await usersRef.update({'pendingEmail': FieldValue.delete()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pending email change canceled.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to cancel.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fa.User? user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: usersRef.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final name = (data['name'] as String?) ?? '';
            final username = (data['username'] as String?) ?? '';
            final phone = (data['phone'] as String?) ?? '';
            final photoUrl = (data['photoUrl'] as String?) ?? '';
            final notifyPush = (data['notifyPush'] as bool?) ?? true;
            final notifyEmail = (data['notifyEmail'] as bool?) ?? true;
            final pendingEmail = (data['pendingEmail'] as String?) ?? '';

            final email = user.email ?? '';

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const Expanded(
                      child: Text('Settings', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),

                Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    title: Text(
                      username.isEmpty ? (name.isEmpty ? 'No name' : name) : username,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(email),
                    trailing: OutlinedButton.icon(
                      onPressed: saving ? null : _pickAndUploadPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Change'),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (pendingEmail.isNotEmpty) ...[
                  Material(
                    color: Colors.white,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.mark_email_read_outlined),
                      title: const Text('Email change pending', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Check $pendingEmail for a verification link.'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: saving ? null : () => _resendVerificationForPendingEmail(pendingEmail),
                            child: const Text('Resend'),
                          ),
                          TextButton(
                            onPressed: saving ? null : () => _cancelPendingEmailChange(usersRef),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _SettingTile(
                  icon: Icons.person_outline,
                  title: 'Name',
                  subtitle: name.isEmpty ? 'Add your name' : name,
                  onTap: saving
                      ? null
                      : () => _editText(
                            title: 'Your name',
                            initial: name,
                            onSave: (v) async {
                              await usersRef.update({'name': v});
                              await fa.FirebaseAuth.instance.currentUser!.updateDisplayName(v);
                            },
                          ),
                ),

                _SettingTile(
                  icon: Icons.badge_outlined,
                  title: 'Username',
                  subtitle: username.isEmpty ? 'Add username' : username,
                  trailingArrow: true,
                  onTap: saving
                      ? null
                      : () => _editText(
                            title: 'Username',
                            initial: username,
                            onSave: (val) async {
                              final fa.User authUser = fa.FirebaseAuth.instance.currentUser!;
                              final usernames = FirebaseFirestore.instance.collection('usernames');

                              final newLower = val.trim().toLowerCase();
                              if (newLower.isEmpty) {
                                throw FirebaseException(plugin: 'firestore', message: 'Username cannot be empty.');
                              }

                              await FirebaseFirestore.instance.runTransaction((tx) async {
                                final meSnap = await tx.get(usersRef);
                                final me = meSnap.data() ?? {};
                                final oldLower = (me['usernameLower'] as String?) ?? '';

                                if (oldLower == newLower) return;

                                final taken = await tx.get(usernames.doc(newLower));
                                if (taken.exists) {
                                  throw FirebaseException(plugin: 'firestore', message: 'Username already taken.');
                                }

                                if (oldLower.isNotEmpty) {
                                  final oldDoc = await tx.get(usernames.doc(oldLower));
                                  if (oldDoc.exists) tx.delete(usernames.doc(oldLower));
                                }

                                tx.set(usernames.doc(newLower), {
                                  'uid': authUser.uid,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                tx.update(usersRef, {
                                  'username': val.trim(),
                                  'usernameLower': newLower,
                                });
                              });

                              await fa.FirebaseAuth.instance.currentUser!.updateDisplayName(val.trim());
                            },
                          ),
                ),

                _SettingTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: email,
                  trailingArrow: true,
                  onTap: saving ? null : _changeEmailDirect,
                ),

                _SettingTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  subtitle: phone.isEmpty ? 'Add phone' : phone,
                  trailingArrow: true,
                  onTap: saving
                      ? null
                      : () => _editText(
                            title: 'Phone number',
                            initial: phone,
                            keyboardType: TextInputType.phone,
                            onSave: (v) => usersRef.update({'phone': v}),
                          ),
                ),

                _ToggleTile(
                  icon: Icons.notifications_none,
                  title: 'Push Notifications',
                  subtitle: 'Get important updates',
                  value: notifyPush,
                  onChanged: saving ? null : (v) => usersRef.update({'notifyPush': v}),
                ),
                _ToggleTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Email Updates',
                  subtitle: 'Receive email newsletters',
                  value: notifyEmail,
                  onChanged: saving ? null : (v) => usersRef.update({'notifyEmail': v}),
                ),

                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Material(
                    color: Colors.white,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Sign out of your account'),
                      onTap: saving ? null : _confirmAndLogout,
                    ),
                  ),
                ),
if (saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: BottomTab.profile),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingArrow = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool trailingArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: trailingArrow ? const Icon(Icons.chevron_right) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: Switch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}
