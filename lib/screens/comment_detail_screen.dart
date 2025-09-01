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
    final a = ModalRoute.of(context)!.settings.arguments as CommentDetailArgs;

    final fbDoc = FirebaseFirestore.instance
        .collection('posts')
        .doc(a.postId)
        .collection('feedback')
        .doc(a.uid);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: fbDoc.get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('Feedback not found.'));
            }

            final m = snap.data!.data()!;
            final name = (m['reviewerName'] as String?) ?? 'Anonymous';
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
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(Icons.person, color: Colors.grey.shade700),
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
                    Row(
                      children: [
                        _Stars(value: r('overall')),
                        const SizedBox(width: 6),
                        Text(r('overall').toStringAsFixed(1),
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 14),

                _SectionView(
                  title: 'Visual Appeal',
                  question:
                      'How attractive and polished does this design look?',
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
                  title: 'Clarity & Structure',
                  question:
                      'Are information and actions clear and well-organized?',
                  value: r('clarity'),
                  note: (notes['clarity'] as String?) ?? '',
                ),
                _SectionView(
                  title: 'Overall Experience',
                  question:
                      'Your gut-level rating of the design as a whole.',
                  value: r('overall'),
                  note: (notes['overall'] as String?) ?? '',
                ),
              ],
            );
          },
        ),
      ),

      // ✅ unified bottom nav
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(question, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            children: [
              _Stars(value: value),
              const SizedBox(width: 6),
              Text(value.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            elevation: 2,
            shadowColor: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(note.isEmpty ? '—' : note),
            ),
          ),
        ],
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
