import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Update these imports to your actual file paths if needed.
import '../screens/comments_screen.dart' show CommentsArgs;
import '../screens/comment_detail_screen.dart' show CommentDetailArgs;

/// ---------------- Helpers ----------------

String _fmtDate(DateTime d) {
  const months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

Widget stars(double? rating, {double size = 18}) {
  final r = (rating ?? 0).clamp(0, 5).toDouble();
  final full = r.floor();
  final half = (r - full) >= 0.5 ? 1 : 0;
  final empty = 5 - full - half;
  Widget icon(IconData i) => Icon(i, size: size, color: Colors.amber);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < full; i++) icon(Icons.star),
      for (var i = 0; i < half; i++) icon(Icons.star_half),
      for (var i = 0; i < empty; i++) icon(Icons.star_border),
    ],
  );
}

/// ---------------- Screen ----------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onOpenSettings});
  final VoidCallback? onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Widget _guard<T>(AsyncSnapshot<T> snap, Widget Function() build) {
    if (snap.hasError) {
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

    final userDocStream = _db.collection('users').doc(uid).snapshots();

    final myPostsQ = _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

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
                  // Header
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
                        onPressed: widget.onOpenSettings ??
                            () => Navigator.of(context).pushNamed('/settings'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text('Your Designs',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  // DESIGNS GRID
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
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.72, // taller to avoid overflow
                        ),
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final d = doc.data();

                          final cover = d['coverUrl'] ??
                              d['thumbnailUrl'] ??
                              d['imageUrl'] ??
                              ((d['images'] is List && (d['images'] as List).isNotEmpty)
                                  ? (d['images'] as List).first
                                  : null);

                          final title = (d['title'] ?? 'Untitled').toString();
                          final authorName = (d['authorName'] ?? '').toString();
                          final ts = d['createdAt'] as Timestamp?;
                          final created = ts?.toDate();

                          return _DesignCard(
                            postId: doc.id,
                            coverUrl: cover,
                            title: title,
                            authorName: authorName,
                            createdAtText: created != null ? _fmtDate(created) : '--',
                          );
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 26),
                  const Text('Your Critiques',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),

                  // CRITIQUES LIST
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
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (_, i) {
                          final fbDoc = docs[i];
                          final data = fbDoc.data();
                          final avg = (data['avg'] as num?)?.toDouble();
                          final comment = (data['comment'] ??
                                  (data['notes'] is Map ? (data['notes']['overall'] ?? '') : ''))
                              .toString();
                          final ts = data['createdAt'] as Timestamp?;
                          final date = ts != null ? _fmtDate(ts.toDate()) : '--';

                          final postRef = fbDoc.reference.parent.parent!;
                          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: postRef.get(),
                            builder: (context, ps) {
                              final post = ps.data?.data();
                              final postTitle = (post?['title'] ?? 'Design').toString();
                              final thumb = post?['coverUrl'] ??
                                  post?['thumbnailUrl'] ??
                                  post?['imageUrl'] ??
                                  ((post?['images'] is List &&
                                          (post?['images'] as List).isNotEmpty)
                                      ? (post!['images'] as List).first
                                      : null);

                              return _CritiqueCard(
                                thumbnailUrl: thumb,
                                title: postTitle,
                                dateText: date,
                                rating: avg,
                                commentPreview: comment.isEmpty ? '(no text)' : comment,
                                onTap: () {
                                  // feedback doc id == reviewer uid
                                  final reviewerUid = fbDoc.id;
                                  Navigator.of(context).pushNamed(
                                    '/commentDetail',
                                    arguments: CommentDetailArgs(
                                      postId: postRef.id,
                                      uid: reviewerUid,
                                    ),
                                  );
                                },
                              );
                            },
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

/// ---------------- Cards ----------------

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.postId,
    required this.coverUrl,
    required this.title,
    required this.authorName,
    required this.createdAtText,
  });

  final String postId;
  final String? coverUrl;
  final String title;
  final String authorName;
  final String createdAtText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        // EXACTLY like Home: pass the same args shape
        Navigator.of(context).pushNamed(
          '/comments',
          arguments: CommentsArgs(
            postId: postId,
            title: title,
            authorName: authorName,
            // If Home uses a different name for the image param,
            // change this to that exact name (e.g. thumbUrl: / imageUrl:).
            coverUrl: coverUrl,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: AspectRatio(
                aspectRatio: 1.10,
                child: coverUrl != null
                    ? Image.network(coverUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.black12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      createdAtText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CritiqueCard extends StatelessWidget {
  const _CritiqueCard({
    required this.thumbnailUrl,
    required this.title,
    required this.dateText,
    required this.rating,
    required this.commentPreview,
    required this.onTap,
  });

  final String? thumbnailUrl;
  final String title;
  final String dateText;
  final double? rating;
  final String commentPreview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.black12,
              child: thumbnailUrl != null
                  ? Image.network(thumbnailUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(dateText, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(width: 8),
                    stars(rating, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating != null ? rating!.toStringAsFixed(1) : '—',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(commentPreview, maxLines: 2, overflow: TextOverflow.ellipsis),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onTap, child: const Text('View full feedback')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Bottom nav (wired like other screens)
class _NavBar extends StatelessWidget {
  final int current;
  final Color accent;
  const _NavBar({required this.current, required this.accent});

  @override
  Widget build(BuildContext context) {
    Color colorFor(bool sel) => sel ? accent : Colors.black87;

    void go(int idx) {
      if (idx == current) return; // already here
      final route = idx == 0 ? '/home' : idx == 1 ? '/upload' : '/profile';
      Navigator.of(context).pushReplacementNamed(route);
      // If the rest of your app uses a different navigation style,
      // e.g. pushNamedAndRemoveUntil, swap the line above accordingly.
    }

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
          _NavBtn(
            icon: Icons.home_rounded,
            label: 'Home',
            color: colorFor(current == 0),
            onTap: () => go(0),
          ),
          _NavBtn(
            icon: Icons.add_circle,
            label: 'Upload',
            color: colorFor(current == 1),
            onTap: () => go(1),
          ),
          _NavBtn(
            icon: Icons.person_rounded,
            label: 'Profile',
            color: colorFor(current == 2),
            onTap: () => go(2),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
