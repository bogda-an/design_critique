import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onOpenSettings});
  final VoidCallback? onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // background status only (does not block UI)
  bool _isMigrating = false;

  @override
  void initState() {
    super.initState();
    // fire-and-forget: make sure old feedback docs have reviewerUid
    WidgetsBinding.instance.addPostFrameCallback((_) => _softBackfillReviewerUid());
  }

  Future<void> _softBackfillReviewerUid() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // If at least one doc already has reviewerUid, skip.
      final hasAny = await _db
          .collectionGroup('feedback')
          .where('reviewerUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (hasAny.docs.isNotEmpty) return;

      setState(() => _isMigrating = true);

      // Only touch docs where the doc-id == uid (per your rules)
      // Scan posts (keep light; commit in batches)
      final posts = await _db.collection('posts').get();
      var batch = _db.batch();
      var pending = 0;

      for (final p in posts.docs) {
        final ref = p.reference.collection('feedback').doc(uid);
        final snap = await ref.get();
        if (snap.exists && (snap.data()?['reviewerUid'] == null)) {
          batch.set(ref, {'reviewerUid': uid}, SetOptions(merge: true));
          if (++pending >= 400) {
            await batch.commit();
            batch = _db.batch();
            pending = 0;
          }
        }
      }
      if (pending > 0) await batch.commit();
    } catch (e) {
      // swallow – this should never block UI
      // You can print(e) for local debugging.
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    final uid = user.uid;

    // Streams (UI never blocks on these)
    final userDocStream = _db.collection('users').doc(uid).snapshots();

    final myPostsQ = _db
        .collection('posts')
        .where('authorId', isEqualTo: uid) // <-- ensure your create code writes this
        .orderBy('createdAt', descending: true);

    final myCritiquesQ = _db
        .collectionGroup('feedback')
        .where('reviewerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    const accent = Color(0xFFD6C433);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, profileSnap) {
            final profile = profileSnap.data?.data();
            final displayName = profile?['username'] ?? user.displayName ?? 'user';
            final photoUrl = profile?['photoUrl'] ?? user.photoURL;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header + gear
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null ? const Icon(Icons.person, size: 28) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Text(displayName,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: myPostsQ.snapshots(),
                              builder: (context, s1) {
                                final designs = s1.data?.size ?? 0;
                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: myCritiquesQ.snapshots(),
                                  builder: (context, s2) {
                                    final critiques = s2.data?.size ?? 0;
                                    return Text('  $designs Designs  $critiques Critiques',
                                        style: const TextStyle(fontSize: 16, color: Colors.grey));
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                        onPressed: widget.onOpenSettings ??
                            () => Navigator.of(context).pushNamed('/settings'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('Your Designs',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  // Designs grid
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: myPostsQ.snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: CircularProgressIndicator(),
                        );
                      }
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("You didn’t post any designs yet."),
                          ],
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1,
                        ),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final thumb = d['thumbnailUrl'] ?? d['imageUrl'];
                          final title = d['title'] ?? 'Untitled';
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                thumb != null
                                    ? Image.network(thumb, fit: BoxFit.cover)
                                    : Container(color: Colors.black12, alignment: Alignment.center, child: const Text('No image')),
                                Positioned(
                                  left: 8, right: 8, bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text('Your Critiques',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  if (_isMigrating)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Syncing your previous critiques…',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),

                  // Critiques list
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: myCritiquesQ.snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: CircularProgressIndicator(),
                        );
                      }
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const Text("You haven’t critiqued any design yet.");
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final data = doc.data();
                          final comment = data['comment'] ?? '(no text)';
                          final rating = data['rating'];
                          final postId = doc.reference.parent.parent?.id ?? 'unknown';
                          return ListTile(
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.mode_comment_outlined),
                            ),
                            title: Text(comment),
                            subtitle: Text('On post: $postId${rating != null ? " • Rating: $rating" : ""}'),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const _NavBar(current: 2, accent: accent),
    );
  }
}

// ---- Bottom nav (placeholder) ----
class _NavBar extends StatelessWidget {
  final int current;
  final Color accent;
  const _NavBar({required this.current, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavBtn(icon: Icons.home_rounded, label: 'Home', selected: current == 0, onTap: () {}),
          _NavBtn(icon: Icons.add_circle, label: 'Upload', selected: current == 1, onTap: () {}),
          _NavBtn(icon: Icons.person_rounded, label: 'Profile', selected: current == 2, onTap: () {}, selectedColor: accent),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? (selectedColor ?? Theme.of(context).colorScheme.primary) : Colors.black87;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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
