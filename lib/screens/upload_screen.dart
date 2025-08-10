import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  final _picker = ImagePicker();
  final List<XFile> _files = [];
  final Map<String, double> _progress = {}; // filePath -> 0..1
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _showMsg(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        ),
      );
  }

  Future<void> _pickImages() async {
    final imgs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
    if (imgs.isNotEmpty) {
      setState(() {
        // Cap to 3 for now (you can raise this)
        final left = 3 - _files.length;
        _files.addAll(imgs.take(left));
      });
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMsg('Please log in first.');
      return;
    }
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      _showMsg('Please add project name and description.');
      return;
    }
    if (_files.isEmpty) {
      _showMsg('Please upload at least one image.');
      return;
    }

    setState(() => _submitting = true);

    final db = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;
    final uid = user.uid;
    final postRef = db.collection('posts').doc(); // new id
    final postId = postRef.id;

    // get author name from users/{uid}
    final userDoc = await db.collection('users').doc(uid).get();
    final authorName = (userDoc.data() ?? {})['username'] ?? 'Anonymous';

    final List<String> imageUrls = [];

    try {
      // Upload images sequentially (simpler progress UI)
      for (var i = 0; i < _files.length; i++) {
        final f = _files[i];
        final file = File(f.path);
        final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = storage.ref().child('user_uploads/$uid/$postId/$fileName');
        final task = ref.putFile(file);

        task.snapshotEvents.listen((snap) {
          final prog = snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
          setState(() => _progress[f.path] = prog.clamp(0, 1));
        });

        await task.whenComplete(() {});
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // Create Firestore post doc
      await postRef.set({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'authorId': uid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'coverUrl': imageUrls.first,
        'images': imageUrls,
        'likes': 0,
        'comments': 0,
      });

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _files.clear();
        _progress.clear();
        _title.clear();
        _desc.clear();
      });
      Navigator.pushReplacementNamed(context, '/postThanks');
    } catch (e) {
      setState(() => _submitting = false);
      _showMsg('Upload failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final yellow = const Color(0xFFD9C63F);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Back to home',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 48), // balance the leading icon space
              ],
            ),
            const SizedBox(height: 8),

            const Text('Project name:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Material(
              elevation: 2,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(
                  hintText: 'Add project name',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Description:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Material(
              elevation: 2,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _desc,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Add project description',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Your design:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),

            // Upload drop area
            GestureDetector(
              onTap: _files.length >= 3 ? null : _pickImages,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black26, width: 1),
                  color: Colors.white,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 44, color: yellow),
                      const SizedBox(height: 8),
                      const Text('Click to upload', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('JPG, JPEG, PNG', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),

            // Thumbnails / progress
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final f in _files) _Thumb(path: f.path, progress: _progress[f.path]),
                    if (_files.length < 3)
                      _AddTile(onTap: _pickImages),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            setState(() {
                              _files.clear();
                              _progress.clear();
                              _title.clear();
                              _desc.clear();
                            });
                            Navigator.pop(context);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.brown),
                      shape: const StadiumBorder(),
                      foregroundColor: Colors.brown,
                    ),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yellow,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('SUBMIT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // Bottom nav (visual)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', onTap: () {
                  Navigator.pop(context);
                }),
                const _NavItem(icon: Icons.add_circle, label: 'Upload', active: true),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', onTap: () {
                  // TODO: push to profile when you build it
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, this.progress});
  final String path;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(path),
            width: 90,
            height: 90,
            fit: BoxFit.cover,
          ),
        ),
        if (progress != null && progress! < 1.0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${(progress! * 100).floor()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black26),
          color: Colors.white,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFD9C63F) : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
