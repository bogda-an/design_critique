import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Route args (so we can push with strong types)
import '../widgets/app_bottom_nav.dart';
import 'feedback_screen.dart' show FeedbackScreenArgs;
import 'comments_screen.dart' show CommentsArgs;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _LoginRedirect();

    final usersRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: usersRef.snapshots(),
          builder: (context, userSnap) {
            final me = userSnap.data?.data() ?? {};
            final username = (me['username'] as String?)?.trim();
            final photoUrl = (me['photoUrl'] as String?)?.trim();

            return CustomScrollView(
              slivers: [
                // Greeting
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        _Avatar(photoUrl: photoUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Greeting(
                            username: username ?? _fallbackName(user.email),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Turn feedback into\nbrilliant design',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),

                // Sort / Filter (visual only)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.swap_vert),
                          label: const Text('Sort by'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Posts list
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: postsQuery.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const _StatusMessage(
                          icon: Icons.error_outline,
                          title: 'Couldn’t load posts',
                          message: 'Please try again in a moment.',
                        );
                      }
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const _StatusMessage(
                          icon: Icons.forum_outlined,
                          title: 'No posts yet',
                          message: 'Be the first to share your work!',
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final p = doc.data();
                          final postId = doc.id;

                          final title =
                              (p['title'] as String?) ?? 'Untitled design';
                          final description =
                              (p['description'] as String?) ?? '';
                          final authorId = (p['authorId'] as String?) ?? '';
                          final authorName =
                              (p['authorName'] as String?) ?? 'Anonymous';
                          final coverUrl = (p['coverUrl'] as String?);
                          final createdAt = p['createdAt'];

                          return _PostCard(
                            postId: postId,
                            title: title,
                            description: description,
                            authorId: authorId,
                            authorName: authorName,
                            coverUrl: coverUrl,
                            createdAt: createdAt,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // ✅ unified bottom nav (works the same on all pages)
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
    );
  }

  String _fallbackName(String? email) {
    if (email == null || !email.contains('@')) return 'there';
    return email.split('@').first;
  }
}

/// Redirect helper so we don’t use BuildContext across async gaps
class _LoginRedirect extends StatefulWidget {
  const _LoginRedirect();
  @override
  State<_LoginRedirect> createState() => _LoginRedirectState();
}

class _LoginRedirectState extends State<_LoginRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(photoUrl!));
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey.shade200,
      child: Icon(Icons.person, color: Colors.grey.shade700),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
        children: [
          const TextSpan(text: 'Hello,\n'),
          TextSpan(
            text: '$username!',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.black54),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// ===== Post Card =====
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.postId,
    required this.title,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.coverUrl,
    required this.createdAt,
  });

  final String postId;
  final String title;
  final String description;
  final String authorId;
  final String authorName;
  final String? coverUrl;
  final dynamic createdAt;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: borderRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            _SquareNetworkImage(
              url: coverUrl!,
              maxSide: 340,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18, height: 1.15),
                ),
                const SizedBox(height: 6),

                // Feedback summary (stars + grade + count)
                _FeedbackSummary(postId: postId),

                const SizedBox(height: 10),

                // Author line (avatar + name + date)
                _AuthorLine(
                  authorId: authorId,
                  authorName: authorName,
                  createdAt: createdAt,
                ),

                const SizedBox(height: 10),

                // Description
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black87, height: 1.3),
                  ),

                const SizedBox(height: 12),

                // Action row: Give Feedback / Comments
                _ActionsRow(
                  postId: postId,
                  currentUid: currentUid,
                  title: title,
                  authorName: authorName,
                  coverUrl: coverUrl,
                  createdAt: createdAt,
                  description: description,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square 340x340 image, crops from the bottom (keeps top).
class _SquareNetworkImage extends StatelessWidget {
  const _SquareNetworkImage({
    required this.url,
    this.maxSide = 340,
    this.borderRadius,
  });

  final String url;
  final double maxSide;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double available = c.maxWidth == double.infinity
            ? MediaQuery.of(context).size.width
            : c.maxWidth;
        final double side = available < maxSide ? available : maxSide;

        return Center(
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            child: SizedBox(
              width: side,
              height: side,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // keep top, crop bottom
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stars + numeric + feedback count (live from posts/{postId}/feedback)
class _FeedbackSummary extends StatelessWidget {
  const _FeedbackSummary({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context) {
    final fbRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('feedback');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: fbRef.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int count = docs.length;
        double avg = 0;
        if (count > 0) {
          double sum = 0;
          for (final d in docs) {
            final m = d.data();
            final ratings = (m['ratings'] as Map?) ?? {};
            final overall = ratings['overall'];
            if (overall is num) sum += overall.toDouble();
          }
          avg = sum / count;
        }

        return Row(
          children: [
            _Stars(value: avg),
            const SizedBox(width: 6),
            Text(avg.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            const Icon(Icons.chat_bubble_outline,
                size: 18, color: Colors.black54),
            const SizedBox(width: 4),
            Text('$count', style: const TextStyle(color: Colors.black54)),
          ],
        );
      },
    );
  }
}

/// 0..5 stars supporting halves
class _Stars extends StatelessWidget {
  const _Stars({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    const double iconSize = 18;

    final full = value.floor();
    final frac = value - full;
    final hasHalf = frac >= 0.25 && frac < 0.75;
    final extraFull = frac >= 0.75 ? 1 : 0;

    final icons = <Widget>[];
    for (int i = 0; i < 5; i++) {
      IconData icon;
      if (i < full + extraFull) {
        icon = Icons.star;
      } else if (i == full && hasHalf) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      icons.add(Icon(icon, size: iconSize, color: const Color(0xFFD9C63F)));
    }
    return Row(children: icons);
  }
}

/// Author avatar + name + post date
class _AuthorLine extends StatelessWidget {
  const _AuthorLine({
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  final String authorId;
  final String authorName;
  final dynamic createdAt;

  @override
  Widget build(BuildContext context) {
    final usersRef =
        FirebaseFirestore.instance.collection('users').doc(authorId);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: usersRef.get(),
      builder: (context, snap) {
        final map = snap.data?.data();
        final String? photoUrl = map?['photoUrl'] as String?;

        final dt = _toDate(createdAt);
        final dateText = dt == null ? '' : _formatDate(dt);

        return Row(
          children: [
            if (photoUrl != null && photoUrl.isNotEmpty)
              CircleAvatar(radius: 18, backgroundImage: NetworkImage(photoUrl))
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.person, color: Colors.grey.shade700),
              ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authorName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                if (dateText.isNotEmpty)
                  Text(dateText, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        );
      },
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

  String _formatDate(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// Row with Give Feedback (disabled if already submitted) and Comments.
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.postId,
    required this.currentUid,
    required this.title,
    required this.authorName,
    required this.coverUrl,
    required this.createdAt,
    required this.description,
  });

  final String postId;
  final String currentUid;
  final String title;
  final String authorName;
  final String? coverUrl;
  final dynamic createdAt;
  final String description;

  @override
  Widget build(BuildContext context) {
    final myFbDoc = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('feedback')
        .doc(currentUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myFbDoc.snapshots(),
      builder: (context, snap) {
        final alreadyLeft = (snap.data?.exists ?? false);

        return Row(
          children: [
            TextButton(
              onPressed: alreadyLeft
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        '/feedback',
                        arguments: FeedbackScreenArgs(
                          postId: postId,
                          title: title,
                          authorName: authorName,
                          coverUrl: coverUrl,
                          createdAt: createdAt,
                        ),
                      );
                    },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor:
                    alreadyLeft ? Colors.black45 : Colors.black,
              ),
              child: Text(
                alreadyLeft ? 'Feedback sent' : 'Give Feedback',
                style: TextStyle(
                  decoration:
                      alreadyLeft ? TextDecoration.none : TextDecoration.underline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 18),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/comments',
                  arguments: CommentsArgs(
                    postId: postId,
                    title: title,
                    authorName: authorName,
                    coverUrl: coverUrl,
                    description: description,
                    createdAt: createdAt,
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Comments',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
