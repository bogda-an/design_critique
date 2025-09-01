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

  // Simple UI guard so server errors are visible (no more “shows then disappears”).
  Widget _guard<T>(AsyncSnapshot<T> snap, Widget Function() build) {
    if (snap.hasError) {
      debugPrint('Firestore error: ${snap.error}');
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)),
      );
    }
    if (snap.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return build();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    final uid = user.uid;

    // User profile doc (optional, for display name / photo)
    final userDocStream = _db.collection('users').doc(uid).snapshots();

    // Designs you posted
    final myPostsQ = _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    // Critiques you left (collection group). NOTE: field is reviewerId in your data.
    final myCritiquesQ = _db
        .collectionGroup('feedback')
        .where('reviewerId', isEqualTo: uid)
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
                  // Header row: avatar, name, counts, gear
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 12),
                            // Live counts (designs + critiques)
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: myPostsQ.snapshots(),
                              builder: (context, s1) {
                                final designs = s1.data?.size ?? 0;
                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: myCritiquesQ.snapshots(),
                                  builder: (context, s2) {
                                    final critiques = s2.data?.size ?? 0;
                                    return Text(
                                      '  $designs Designs  $critiques Critiques',
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    );
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
                  const Text(
                    'Your Designs',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  // Designs grid
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: myPostsQ.snapshots(),
                    builder: (context, snap) => _guard(snap, () {
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text("You didn’t post any designs yet."),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();

                          // Your posts store 'coverUrl'; add sensible fallbacks.
                          final thumb = d['coverUrl'] ??
                              d['thumbnailUrl'] ??
                              d['imageUrl'] ??
                              ((d['images'] is List && (d['images'] as List).isNotEmpty)
                                  ? (d['images'] as List).first
                                  : null);

                          final title = (d['title'] ?? '').toString().trim().isEmpty
                              ? 'Untitled'
                              : d['title'];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                thumb != null
                                    ? Image.network(thumb, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Text('No image'),
                                      ),
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Your Critiques',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  // Critiques list
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: myCritiquesQ.snapshots(),
                    builder: (context, snap) => _guard(snap, () {
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text("You haven’t critiqued any design yet."),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final data = doc.data();

                          // You have avg (num) and notes/rating maps; use a sensible summary.
                          final avg = data['avg'];
                          final comment = data['comment'] ??
                              (data['notes'] is Map ? (data['notes']['overall'] ?? '') : '') ??
                              '';
                          final commentText = (comment is String && comment.trim().isNotEmpty)
                              ? comment
                              : '(no text)';

                          // parent post id
                          final postId = doc.reference.parent.parent?.id ?? 'unknown';

                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.mode_comment_outlined),
                            ),
                            title: Text(commentText),
                            subtitle: Text(
                              'On post: $postId${avg != null ? " • Avg: $avg" : ""}',
                            ),
                          );
                        },
                      );
                    }),
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
