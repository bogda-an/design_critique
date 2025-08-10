import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // If not logged in, kick back to login
    if (user == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final usersRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final postsRef = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: usersRef.snapshots(),
          builder: (context, userSnap) {
            final data = userSnap.data?.data() ?? {};
            final username = (data['username'] as String?)?.trim();
            final photoUrl = (data['photoUrl'] as String?)?.trim();

            return CustomScrollView(
              slivers: [
                // Greeting row
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

                // Big headline
                SliverToBoxAdapter(
                  child: const Padding(
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

                // Sort / Filter (stubs)
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

                // Posts list
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: postsRef.snapshots(),
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
                          final p = docs[i].data();
                          final title = (p['title'] as String?) ?? 'Untitled';
                          final author =
                              (p['authorName'] as String?) ?? 'Anonymous';
                          final image = (p['coverUrl'] as String?);
                          return _PostCardStub(
                            title: title,
                            author: author,
                            imageUrl: image,
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

      // Bottom navigation — Upload navigates to '/upload'
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const _NavItem(icon: Icons.home_rounded, label: 'Home', active: true),
                _NavItem(
                  icon: Icons.add_circle_outline,
                  label: 'Upload',
                  onTap: () => Navigator.pushNamed(context, '/upload'),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  onTap: () {
                    // TODO: push to profile when you build it
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fallbackName(String? email) {
    if (email == null || !email.contains('@')) return 'there';
    return email.split('@').first;
  }
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

  const _StatusMessage.noPosts()
      : icon = Icons.forum_outlined,
        title = 'No posts yet',
        message = 'Be the first to share your work!';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.black54),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _PostCardStub extends StatelessWidget {
  const _PostCardStub({
    required this.title,
    required this.author,
    this.imageUrl,
  });

  final String title;
  final String author;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(imageUrl!, fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('by $author',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
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
