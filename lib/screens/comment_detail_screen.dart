import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_bottom_nav.dart';

class CommentDetailArgs {
  final String postId;
  final String uid; // reviewer uid == feedback doc id
  CommentDetailArgs({required this.postId, required this.uid});
}

class CommentDetailScreen extends StatelessWidget {
  const CommentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as CommentDetailArgs;

    final ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(args.postId)
        .collection('feedback')
        .doc(args.uid);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('Feedback not found.'));
            }

            final m = snap.data!.data()!;
            final name = (m['reviewerName'] as String?) ?? 'Anonymous';
            final photoUrl = (m['reviewerPhotoUrl'] as String?) ?? '';
            final createdAt = m['createdAt'];
            final ratings = (m['ratings'] as Map?) ?? {};
            final notes = (m['notes'] as Map?) ?? {};
            double r(String k) =>
                (ratings[k] is num) ? (ratings[k] as num).toDouble() : 0.0;

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
                        'Back to comments',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 6),

                // Reviewer header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: photoUrl.isEmpty
                          ? Icon(Icons.person, color: Colors.grey.shade700)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          if (_formatDate(_toDate(createdAt)) != null)
                            Text(_formatDate(_toDate(createdAt))!,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Stars(value: r('overall')),
                    const SizedBox(width: 6),
                    Text(r('overall').toStringAsFixed(1),
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),

                const SizedBox(height: 14),

                _SectionView(
                  title: 'Visual Appeal',
                  question: 'How attractive and polished does this design look?',
                  value: r('visual'),
                  note: (notes['visual'] as String?) ?? '',
                ),
                _SectionView(
                  title: 'Accessibility',
                  question:
                      'Can people of all abilities use this comfortably?',
                  value: r('accessibility'),
                  note: (notes['accessibility'] as String?) ?? '',
                ),
                _SectionView(
                  title: 'Usability',
                  question:
                      'Is it straightforward to navigate and accomplish tasks?',
                  value: r('usability'),
                  note: (notes['usability'] as String?) ?? '',
                ),
                _SectionView(
                  title: 'Clarity',
                  question: 'Is the content clear and easy to understand?',
                  value: r('clarity'),
                  note: (notes['clarity'] as String?) ?? '',
                ),
                _SectionView(
                  title: 'Overall',
                  question: 'Overall, how would you rate this design?',
                  value: r('overall'),
                  note: (notes['overall'] as String?) ?? '',
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

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.title,
    required this.question,
    required this.value,
    required this.note,
  });

  final String title;
  final String question;
  final double value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Row(
              children: [
                _Stars(value: value),
                const SizedBox(width: 6),
                Text(value.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 6),
            Text(note.isEmpty ? '—' : note),
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
    const double size = 18;
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
