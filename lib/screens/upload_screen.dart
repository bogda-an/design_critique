import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final Map<String, double> _progress = {}; // file.path -> 0..1
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
      ..showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  Future<void> _pickImages() async {
    // multi pick works on web + mobile
    final imgs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
    if (imgs.isNotEmpty) {
      setState(() {
        final left = 3 - _files.length; // cap to 3
        if (left > 0) _files.addAll(imgs.take(left));
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
    final postRef = db.collection('posts').doc();
    final postId = postRef.id;

    // get author name from users/{uid}
    final userDoc = await db.collection('users').doc(uid).get();
    final authorName = (userDoc.data() ?? {})['username'] ?? 'Anonymous';

    final List<String> imageUrls = [];

    try {
      for (var i = 0; i < _files.length; i++) {
        final xf = _files[i];
        final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = storage.ref('user_uploads/$uid/$postId/$fileName');

        UploadTask task;

        if (kIsWeb) {
          final bytes = await xf.readAsBytes();
          task = ref.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          final file = io.File(xf.path);
          task = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
        }

        task.snapshotEvents.listen((snap) {
          final prog = snap.bytesTransferred /
              (snap.totalBytes == 0 ? 1 : snap.totalBytes);
          setState(() => _progress[xf.path] = prog.clamp(0, 1));
        });

        final snap = await task.whenComplete(() {});
        final url = await snap.ref.getDownloadURL();
        imageUrls.add(url);
      }

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
    const yellow = Color(0xFFD9C63F);

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
                const SizedBox(width: 48),
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

            GestureDetector(
              onTap: _files.length >= 3 ? null : _pickImages,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black26, width: 1),
                  color: Colors.white,
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 44, color: yellow),
                      SizedBox(height: 8),
                      Text('Click to upload', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('JPG, JPEG, PNG', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ),

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
                    for (final f in _files)
                      _Thumb(path: f.path, xfile: f, progress: _progress[f.path]),
                    if (_files.length < 3)
                      _AddTile(onTap: _pickImages),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ==== Buttons row (match Feedback screen) ====
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64330A), // cancel color
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(), // pill
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: .25,
                    ),
                  ),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE1D145), // submit color
                    foregroundColor: Colors.white, // white text
                    elevation: 3,
                    shadowColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(), // pill
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: .25,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SUBMIT'),
                ),
              ],
            ),
          ],
        ),
      ),

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
                _NavItem(icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
                const _NavItem(icon: Icons.add_circle, label: 'Upload', active: true),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', onTap: () => Navigator.pushNamed(context, '/profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.xfile, this.progress});
  final String path;
  final XFile xfile;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (kIsWeb) {
      // On web path is a blob: URL; Image.network can render it.
      img = Image.network(path, width: 90, height: 90, fit: BoxFit.cover);
    } else {
      img = Image.file(io.File(path), width: 90, height: 90, fit: BoxFit.cover);
    }

    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: img),
        if (progress != null && progress! < 1.0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text('${(progress! * 100).floor()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
