import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_bottom_nav.dart';
import 'comment_detail_screen.dart';

/// Arguments when opening the comments page from Home.
class CommentsArgs {
  final String postId;
  final String title;
  final String authorName;
  final String? coverUrl;
  final String? description;
  final dynamic createdAt;

  CommentsArgs({
    required this.postId,
    required this.title,
    required this.authorName,
    this.coverUrl,
    this.description,
    this.createdAt,
  });
}

class CommentsScreen extends StatelessWidget {
  const CommentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = ModalRoute.of(context)!.settings.arguments as CommentsArgs;
    final fbRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(a.postId)
        .collection('feedback')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            // Back header
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

            // Post header (author + average stars)
            _PostHeader(a: a),

            const SizedBox(height: 10),

            // Title row + fake sort
            Row(
              children: [
                const Expanded(
                  child: Text('Comments',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Sort by'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),

            // Comments list (feedback)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: fbRef.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No comments yet.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final m = d.data();
                    final reviewerName =
                        (m['reviewerName'] as String?) ?? 'Anonymous';
                    final createdAt = m['createdAt'];
                    final ratings = (m['ratings'] as Map?) ?? {};
                    final notes = (m['notes'] as Map?) ?? {};
                    final overall = (ratings['overall'] is num)
                        ? (ratings['overall'] as num).toDouble()
                        : 0.0;
                    final overallText =
                        (notes['overall'] as String?)?.trim() ?? '';

                    return _CommentTile(
                      reviewerName: reviewerName,
                      createdAt: createdAt,
                      overall: overall,
                      overallText: overallText,
                      onView: () {
                        Navigator.pushNamed(
                          context,
                          '/commentDetail',
                          arguments: CommentDetailArgs(
                            postId: a.postId,
                            uid: d.id, // feedback docId is the reviewer's uid
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),

      // ✅ unified bottom nav
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.a});
  final CommentsArgs a;

  @override
  Widget build(BuildContext context) {
    final avgStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(a.postId)
        .collection('feedback')
        .snapshots();

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail (tap → full view)
            GestureDetector(
              onTap: () {
                if (a.coverUrl == null || a.coverUrl!.isEmpty) return;
                Navigator.pushNamed(context, '/designView', arguments: a.coverUrl);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: a.coverUrl == null || a.coverUrl!.isEmpty
                    ? Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : Image.network(
                        a.coverUrl!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author + stars row
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: avgStream,
                    builder: (context, snap) {
                      double avg = 0;
                      int count = 0;
                      if (snap.hasData) {
                        count = snap.data!.docs.length;
                        if (count > 0) {
                          double sum = 0;
                          for (final d in snap.data!.docs) {
                            final m = d.data();
                            final ratings = (m['ratings'] as Map?) ?? {};
                            final o = ratings['overall'];
                            if (o is num) sum += o.toDouble();
                          }
                          avg = sum / count;
                        }
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _Stars(value: avg),
                          const SizedBox(width: 6),
                          Text(avg.toStringAsFixed(1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          const Icon(Icons.chat_bubble_outline,
                              size: 18, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text('$count',
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if ((a.description ?? '').isNotEmpty)
                    Text(
                      a.description!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87, height: 1.3),
                    ),
                  TextButton(
                    onPressed: () {
                      if (a.coverUrl == null || a.coverUrl!.isEmpty) return;
                      Navigator.pushNamed(context, '/designView',
                          arguments: a.coverUrl);
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('Press to view design'),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.reviewerName,
    required this.createdAt,
    required this.overall,
    required this.overallText,
    required this.onView,
  });

  final String reviewerName;
  final dynamic createdAt;
  final double overall;
  final String overallText;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(_toDate(createdAt));

    return Material(
      color: Colors.white,
      elevation: 0.5,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar placeholder (optional: load from /users)
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              child: Icon(Icons.person, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reviewerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (dateText != null)
                    Text(dateText,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Stars(value: overall),
                      const SizedBox(width: 6),
                      Text(overall.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overallText.isEmpty ? '—' : overallText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onView,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        'View full feedback',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  DateTime? _toDate(dynamic ts) {
    try {
      if (ts == null) return null;
      if (ts is DateTime) return ts;
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {}
    return null;
  }

  String? _formatDate(DateTime? d) {
    if (d == null) return null;
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// Small star row used in this screen
class _Stars extends StatelessWidget {
  const _Stars({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    const double size = 16;
    final full = value.floor();
    final frac = value - full;
    final hasHalf = frac >= 0.25 && frac < 0.75;
    final extraFull = frac >= 0.75 ? 1 : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (i < full + extraFull) {
          icon = Icons.star;
        } else if (i == full && hasHalf) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: const Color(0xFFD9C63F));
      }),
    );
  }
}
