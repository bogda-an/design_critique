import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_bottom_nav.dart';
import 'comment_detail_screen.dart';
import 'design_view_screen.dart';

/// Keep description/createdAt optional so old call-sites work.
class CommentsArgs {
  final String postId;
  final String title;
  final String authorName;
  final String? authorPhotoUrl;
  final String? coverUrl;
  final String? description;
  final dynamic createdAt;

  CommentsArgs({
    required this.postId,
    required this.title,
    required this.authorName,
    this.authorPhotoUrl,
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
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fbRef.snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            final count = docs.length;
            var sum = 0.0;
            for (final d in docs) {
              final m = d.data();
              final ratings = (m['ratings'] as Map?) ?? {};
              final o = ratings['overall'];
              if (o is num) sum += o.toDouble();
            }
            final avg = count == 0 ? 0.0 : sum / count;

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                // Header card like your mock
                const SizedBox(height: 6),
                Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview
                        InkWell(
                          onTap: (a.coverUrl?.isNotEmpty ?? false)
                              ? () {
                                  Navigator.pushNamed(
                                    context,
                                    '/designView',
                                    arguments: DesignViewArgs(
                                      imageUrl: a.coverUrl!,
                                      postId: a.postId,
                                    ),
                                  );
                                }
                              : null,
                          child: Hero(
                            tag: 'designImage-${a.postId}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 92,
                                height: 92,
                                color: Colors.grey.shade200,
                                child: (a.coverUrl?.isNotEmpty ?? false)
                                    ? Image.network(a.coverUrl!, fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 28),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Author row, date, rating + count
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage:
                                        (a.authorPhotoUrl?.isNotEmpty ?? false)
                                            ? NetworkImage(a.authorPhotoUrl!)
                                            : null,
                                    child: (a.authorPhotoUrl?.isEmpty ?? true)
                                        ? const Icon(Icons.person, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(a.authorName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        if (_formatDate(_toDate(a.createdAt)) !=
                                            null)
                                          Text(
                                            _formatDate(_toDate(a.createdAt))!,
                                            style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),
                                  _Stars(value: avg),
                                  const SizedBox(width: 4),
                                  Text(avg.toStringAsFixed(1),
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.chat_bubble_outline,
                                          size: 16),
                                      const SizedBox(width: 2),
                                      Text('$count',
                                          style: const TextStyle(
                                              color: Colors.black54)),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                a.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              if ((a.description?.isNotEmpty ?? false))
                                Text(
                                  a.description!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(color: Colors.black87),
                                ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: (a.coverUrl?.isNotEmpty ?? false)
                                      ? () {
                                          Navigator.pushNamed(
                                            context,
                                            '/designView',
                                            arguments: DesignViewArgs(
                                              imageUrl: a.coverUrl!,
                                              postId: a.postId,
                                            ),
                                          );
                                        }
                                      : null,
                                  child: const Text('Press to view design'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Title + Sort
                Row(
                  children: [
                    const Expanded(
                      child: Text('Comments',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.swap_vert),
                      label: const Text('Sort by'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                // Comments list
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No comments yet.')),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final d = docs[i];
                      final m = d.data();
                      final name = (m['reviewerName'] as String?) ?? 'Anonymous';
                      final photo = (m['reviewerPhotoUrl'] as String?) ?? '';
                      final createdAt = m['createdAt'];
                      final ratings = (m['ratings'] as Map?) ?? {};
                      final notes = (m['notes'] as Map?) ?? {};
                      final overall = (ratings['overall'] is num)
                          ? (ratings['overall'] as num).toDouble()
                          : 0.0;
                      final overallText =
                          (notes['overall'] as String?)?.trim() ?? '';

                      return _CommentTile(
                        name: name,
                        photoUrl: photo,
                        date: _formatDate(_toDate(createdAt)),
                        stars: overall,
                        text: overallText,
                        onView: () {
                          Navigator.pushNamed(
                            context,
                            '/commentDetail',
                            arguments: CommentDetailArgs(
                              postId: a.postId,
                              uid: d.id,
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.name,
    required this.photoUrl,
    required this.date,
    required this.stars,
    required this.text,
    required this.onView,
  });

  final String name;
  final String photoUrl;
  final String? date;
  final double stars;
  final String text;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (date != null)
                      Text(date!,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                    const SizedBox(width: 6),
                    _Stars(value: stars),
                    const SizedBox(width: 4),
                    Text(stars.toStringAsFixed(1),
                        style:
                            const TextStyle(color: Colors.black54, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    text.isEmpty ? '—' : text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onView,
                      child: const Text('View full feedback'),
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

// utils
DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return (v as Timestamp).toDate();
  } catch (_) {
    return null;
  }
}
String? _formatDate(DateTime? d) {
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
