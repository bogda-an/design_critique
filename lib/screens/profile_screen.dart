import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/comments_screen.dart' show CommentsArgs;
import '../screens/comment_detail_screen.dart' show CommentDetailArgs;


String _fmtDate(DateTime d) {
  const m = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
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


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onOpenSettings});
  final VoidCallback? onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _busyDelete = false;

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

  Future<void> _deleteDesignAndComments(String postId) async {
    setState(() => _busyDelete = true);
    try {
      final postRef = _db.collection('posts').doc(postId);
      final fb = await postRef.collection('feedback').get();
      final batch = _db.batch();
      for (final d in fb.docs) {
        batch.delete(d.reference);
      }
      batch.delete(postRef);
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design deleted.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to delete')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyDelete = false);
      }
    }
  }

  Future<void> _confirmDeleteDesign({
    required String postId,
    required String title,
    String? coverUrl,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Delete this design?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              elevation: 1,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (coverUrl != null && (coverUrl).isNotEmpty)
                      ? Image.network(coverUrl, width: 48, height: 48, fit: BoxFit.cover)
                      : Container(width: 48, height: 48, color: Colors.grey.shade200,
                          child: const Icon(Icons.image_outlined, color: Colors.black54)),
                ),
                title: Text(title.isEmpty ? 'Untitled' : title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('This will permanently remove the design and all comments.'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _deleteDesignAndComments(postId);
    }
  }

  Future<void> _showDesignActions({
    required String postId,
    required String title,
    String? coverUrl,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (coverUrl != null && coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(coverUrl, width: 48, height: 48, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image_outlined, color: Colors.black54),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Untitled' : title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete design'),
                subtitle: const Text('Also removes all comments'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteDesign(postId: postId, title: title, coverUrl: coverUrl);
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMyComment({
    required String postId,
    required String reviewerUid,
  }) async {
    setState(() => _busyDelete = true);
    try {
      final ref = _db.collection('posts').doc(postId).collection('feedback').doc(reviewerUid);
      await ref.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to delete comment')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyDelete = false);
      }
    }
  }

  Future<void> _confirmDeleteComment({
    required String postTitle,
    required String postId,
    required String reviewerUid,
    String? postCoverUrl,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Delete this comment?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              elevation: 1,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (postCoverUrl != null && postCoverUrl.isNotEmpty)
                      ? Image.network(postCoverUrl, width: 48, height: 48, fit: BoxFit.cover)
                      : Container(width: 48, height: 48, color: Colors.grey.shade200,
                          child: const Icon(Icons.image_outlined, color: Colors.black54)),
                ),
                title: Text(postTitle.isEmpty ? 'Untitled' : postTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('This will permanently remove your comment.'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (ok == true) {
      await _deleteMyComment(postId: postId, reviewerUid: reviewerUid);
    }
  }

  Future<void> _showCommentActions({
    required String postId,
    required String postTitle,
    required String reviewerUid,
    String? postCoverUrl,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize   .min,
          children: [
            Row(
              children: [
                if (postCoverUrl != null && postCoverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(postCoverUrl, width: 48, height: 48, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image_outlined, color: Colors.black54),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    postTitle.isEmpty ? 'Untitled' : postTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
              ],
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete comment'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteComment(
                    postTitle: postTitle,
                    postId: postId,
                    reviewerUid: reviewerUid,
                    postCoverUrl: postCoverUrl,
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
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

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, profileSnap) {
            final profile = profileSnap.data?.data();
            final displayName = profile?['username'] ?? user.displayName ?? 'user';
            final photoUrl = profile?['photoUrl'] ?? user.photoURL;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          const crossAxisCount = 2;

                          final ratio = w < 360
                              ? 0.56
                              : (w < 420 ? 0.62 : (w < 520 ? 0.70 : 0.80));

                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 18,
                                  childAspectRatio: ratio,
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
                                    onMore: () => _showDesignActions(
                                      postId: doc.id,
                                      title: title,
                                      coverUrl: cover?.toString(),
                                    ),
                                  );
                                },
                              );
                            }),
                          );
                        },
                      ),

                      const SizedBox(height: 26),
                      const Text('Your Critiques',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),

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
                                      final reviewerUid = fbDoc.id; 
                                      Navigator.of(context).pushNamed(
                                        '/commentDetail',
                                        arguments: CommentDetailArgs(
                                          postId: postRef.id,
                                          uid: reviewerUid,
                                        ),
                                      );
                                    },
                                    onMore: () {
                                      final reviewerUid = fbDoc.id;
                                      _showCommentActions(
                                        postId: postRef.id,
                                        postTitle: postTitle,
                                        reviewerUid: reviewerUid,
                                        postCoverUrl: thumb?.toString(),
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
                ),

                if (_busyDelete)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            );
          },
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
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                ),
                _NavItem(
                  icon: Icons.add_circle,
                  label: 'Upload',
                  onTap: () => Navigator.pushReplacementNamed(context, '/upload'),
                ),
                const _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  active: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.postId,
    required this.coverUrl,
    required this.title,
    required this.authorName,
    required this.createdAtText,
    this.onMore,
  });

  final String postId;
  final String? coverUrl;
  final String title;
  final String authorName;
  final String createdAtText;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final feedbackStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('feedback')
        .snapshots();

    final screenW = MediaQuery.of(context).size.width;
    final starSize = screenW < 360 ? 12.0 : (screenW < 420 ? 13.0 : 15.0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: feedbackStream,
      builder: (context, snap) {
        double? avg;
        int commentsCount = 0;

        if (snap.hasData) {
          final docs = snap.data!.docs;
          commentsCount = docs.length;
          final values = docs
              .map((d) => (d.data()['avg'] as num?)?.toDouble())
              .whereType<double>()
              .toList();
          if (values.isNotEmpty) {
            avg = values.reduce((a, b) => a + b) / values.length;
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.of(context).pushNamed(
              '/comments',
              arguments: CommentsArgs(
                postId: postId,
                title: title,
                authorName: authorName,
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
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: coverUrl != null
                              ? Image.network(coverUrl!, fit: BoxFit.cover)
                              : Container(color: Colors.black12),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: onMore,
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.more_horiz, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(child: stars(avg, size: starSize)),
                            const SizedBox(width: 4),
                            Text(
                              avg != null ? avg.toStringAsFixed(1) : '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chat_bubble_outline, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        commentsCount.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                    createdAtText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    this.onMore,
  });

  final String? thumbnailUrl;
  final String title;
  final String dateText;
  final double? rating;
  final String commentPreview;
  final VoidCallback onTap;
  final VoidCallback? onMore;

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
                    const SizedBox(width: 8),                    
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: onMore,
                      tooltip: 'More',
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

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
