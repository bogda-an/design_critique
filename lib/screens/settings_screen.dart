import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _picker = ImagePicker();
  bool _saving = false;

  // ---- edit one text value helper ----
  Future<void> _editText({
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = TextEditingController(text: initial);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            top: 16, left: 16, right: 16,
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
        );
      },
    );

    if (ok == true) {
      setState(() => _saving = true);
      try {
        await onSave(c.text.trim());
        messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      } on FirebaseAuthException catch (e) {
        final msg = switch (e.code) {
          'requires-recent-login' => 'Please log out and sign in again to change this.',
          'invalid-email' => 'That email address is not valid.',
          'email-already-in-use' => 'That email is already in use.',
          _ => e.message ?? 'Could not save. Try again.'
        };
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      } on FirebaseException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Could not save. Try again.')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  // ---- upload profile photo (web + mobile) ----
  Future<void> _pickAndUploadPhoto(String uid) async {
    final messenger = ScaffoldMessenger.of(context);

    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (x == null) return;

    setState(() => _saving = true);
    try {
      // Use compatible form on all plugin versions
      final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');

      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        final mime = x.mimeType ?? 'image/jpeg';
        await ref.putData(bytes, SettableMetadata(contentType: mime));
      } else {
        await ref.putFile(File(x.path));
      }

      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoUrl': url});
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated.')));
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to upload photo')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      body: SafeArea(
        // FIX: remove extra '>' here – should be >>> not >>>>
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: usersRef.snapshots(),
          builder: (context, snap) {
            final m = snap.data?.data() ?? {};
            final photoUrl = (m['photoUrl'] as String?) ?? '';
            final name = (m['name'] as String?) ?? '';
            final username = (m['username'] as String?) ?? '';
            final email = user.email ?? (m['email'] as String? ?? '');
            final pendingEmail = (m['pendingEmail'] as String?) ?? '';
            final phone = (m['phone'] as String?) ?? '';
            final notifyPush = (m['notifyPush'] as bool?) ?? true;
            final notifyEmail = (m['notifyEmail'] as bool?) ?? true;

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const Expanded(
                      child: Text('Back to Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),

                // Avatar
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Icon(Icons.person, size: 44, color: Colors.grey.shade700)
                            : null,
                      ),
                      TextButton(
                        onPressed: _saving ? null : () => _pickAndUploadPhoto(user.uid),
                        child: const Text('Edit photo'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),

                _SettingTile(
                  icon: Icons.person_outline,
                  title: 'Name',
                  subtitle: name.isEmpty ? 'Add your name' : name,
                  onTap: _saving
                      ? null
                      : () => _editText(
                            title: 'Your name',
                            initial: name,
                            onSave: (v) => usersRef.update({'name': v}),
                          ),
                ),

                _SettingTile(
                  icon: Icons.badge_outlined,
                  title: 'Username',
                  subtitle: username.isEmpty ? 'Add username' : username,
                  trailingArrow: true,
                  onTap: _saving
                      ? null
                      : () => _editText(
                            title: 'Username',
                            initial: username,
                            onSave: (val) async {
                              final newLower = val.toLowerCase();
                              final usernames = FirebaseFirestore.instance.collection('usernames');

                              await FirebaseFirestore.instance.runTransaction((tx) async {
                                final takenSnap = await tx.get(usernames.doc(newLower));
                                if (takenSnap.exists) {
                                  throw FirebaseException(plugin: 'firestore', message: 'Username already taken.');
                                }
                                final oldLower = username.toLowerCase();
                                if (oldLower.isNotEmpty) {
                                  tx.delete(usernames.doc(oldLower));
                                }
                                tx.set(usernames.doc(newLower), {
                                  'ownerId': user.uid,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                tx.update(usersRef, {
                                  'username': val,
                                  'usernameLower': newLower,
                                });
                              });
                            },
                          ),
                ),

                _SettingTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: pendingEmail.isNotEmpty ? 'Pending verification: $pendingEmail' : email,
                  trailingArrow: true,
                  onTap: _saving
                      ? null
                      : () => _editText(
                            title: 'Email',
                            initial: email,
                            keyboardType: TextInputType.emailAddress,
                            onSave: (v) async {
                              final messenger = ScaffoldMessenger.of(context);
                              await user.verifyBeforeUpdateEmail(v);
                              await usersRef.update({'pendingEmail': v});
                              messenger.showSnackBar(const SnackBar(
                                content: Text('Verification link sent. Check your new email.'),
                              ));
                            },
                          ),
                ),

                _SettingTile(
                  icon: Icons.lock_outline,
                  title: 'Password',
                  subtitle: '************',
                  trailingArrow: true,
                  onTap: _saving
                      ? null
                      : () => _editText(
                            title: 'New password',
                            initial: '',
                            obscure: true,
                            onSave: (v) => user.updatePassword(v),
                          ),
                ),

                _SettingTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  subtitle: phone.isEmpty ? 'Enter your phone no:' : phone,
                  trailingArrow: true,
                  onTap: _saving
                      ? null
                      : () => _editText(
                            title: 'Phone',
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
                  onChanged: _saving ? null : (v) => usersRef.update({'notifyPush': v}),
                ),
                _ToggleTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Email Updates',
                  subtitle: 'Receive email newsletters',
                  value: notifyEmail,
                  onChanged: _saving ? null : (v) => usersRef.update({'notifyEmail': v}),
                ),

                if (_saving)
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

// ---- UI tiles ----
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailingArrow = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
      padding: const EdgeInsets.only(bottom: 8),
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
