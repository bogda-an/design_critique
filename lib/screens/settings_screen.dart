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
  bool _saving = false;

  Future<void> _editText({
    required String title,
    String initial = '',
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    required Future<void> Function(String) onSave,
  }) async {
    final c = TextEditingController(text: initial);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16),
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
        messenger.showSnackBar(const SnackBar(content: Text('Updated.')));
      } on FirebaseException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to update')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;
    final messenger = ScaffoldMessenger.of(context);

    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
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
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(url);
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
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: usersRef.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final name = (data['name'] as String?) ?? '';
            final username = (data['username'] as String?) ?? '';
            final phone = (data['phone'] as String?) ?? '';
            final email = user.email ?? '';
            final pendingEmail = (data['pendingEmail'] as String?) ?? '';
            final photoUrl = (data['photoUrl'] as String?) ?? '';
            final notifyPush = (data['notifyPush'] as bool?) ?? true;
            final notifyEmail = (data['notifyEmail'] as bool?) ?? true;

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Settings',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),

                // Profile header
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
                    title: Text(username.isEmpty ? (name.isEmpty ? 'No name' : name) : username,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(email),
                    trailing: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickAndUploadPhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Change'),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _SettingTile(
                  icon: Icons.person_outline,
                  title: 'Name',
                  subtitle: name.isEmpty ? 'Add your name' : name,
                  onTap: _saving
                      ? null
                      : () => _editText(
                            title: 'Your name',
                            initial: name,
                            onSave: (v) async {
                              await usersRef.update({'name': v});
                              await FirebaseAuth.instance.currentUser!.updateDisplayName(v);
                            },
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
                              await FirebaseAuth.instance.currentUser!.updateDisplayName(val);
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
                              // Your existing email change flow here
                              await usersRef.update({'pendingEmail': v});
                            },
                          ),
                ),

                _SettingTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  subtitle: phone.isEmpty ? 'Add phone' : phone,
                  trailingArrow: true,
                  onTap: _saving
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
