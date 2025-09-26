import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/app_bottom_nav.dart';
import 'feedback_screen.dart' show FeedbackScreenArgs;
import 'comments_screen.dart' show CommentsArgs;

enum _SortBy { dateDesc, starsDesc }
enum _FilterBy { all, withComments, withoutComments }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;

  
  _SortBy _sortBy = _SortBy.dateDesc;
  _FilterBy _filterBy = _FilterBy.all;

 
  final Map<String, double> _avgCache = {};   
  final Map<String, int> _countCache = {};    
  final Set<String> _inflight = {};           
  bool _loadingStats = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const _LoginRedirect();

    final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

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
                          onPressed: _showHeaderMenu,
                          icon: const Icon(Icons.more_horiz),
                          tooltip: 'More',
                        ),
                      ],
                    ),
                  ),
                ),

                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        'Turn feedback into\nbrilliant design',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),

              
                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickSortBy,
                          icon: const Icon(Icons.swap_vert, size: 18),
                          label: Text(
                            _sortBy == _SortBy.dateDesc ? 'Sort by' : 'Sort: Stars',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.black12, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40), // pill
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _pickFilters,
                          icon: const Icon(Icons.filter_alt_outlined, size: 18),
                          label: Text(
                            _filterLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Colors.black12, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40), // pill
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

               
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

                      
                      _ensureStatsLoadedOnce(docs);

                      
                      final items = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

                      final needStats = _sortBy == _SortBy.starsDesc || _filterBy != _FilterBy.all;
                      final allReady = !needStats || _statsReadyFor(items.map((d) => d.id));

                     
                      if (needStats && allReady && _filterBy != _FilterBy.all) {
                        items.retainWhere((d) {
                          final count = _countCache[d.id] ?? 0;
                          return _filterBy == _FilterBy.withComments ? count > 0 : count == 0;
                        });
                      }

                      
                      if (needStats && allReady && _sortBy == _SortBy.starsDesc) {
                        items.sort((a, b) {
                          final aa = _avgCache[a.id] ?? -1; // unknown last
                          final bb = _avgCache[b.id] ?? -1;
                          if (aa == bb) {
                            return _compareDateDesc(a.data()['createdAt'], b.data()['createdAt']);
                          }
                          return bb.compareTo(aa);
                        });
                      } else {
                        
                        items.sort((a, b) => _compareDateDesc(a.data()['createdAt'], b.data()['createdAt']));
                      }

                      return Column(
                        children: [
                          if (_loadingStats || (needStats && !allReady))
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, i) {
                              final doc = items[i];
                              final p = doc.data();
                              final postId = doc.id;

                              final title = (p['title'] as String?) ?? 'Untitled design';
                              final description = (p['description'] as String?) ?? '';
                              final authorId = (p['authorId'] as String?) ?? '';
                              final authorName = (p['authorName'] as String?) ?? 'Anonymous';
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
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),

      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
    );
  }

  
  void _showHeaderMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Go to Settings'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushNamed('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

 
  Future<void> _pickSortBy() async {
    final choice = await showModalBottomSheet<_SortBy>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<_SortBy>(
              value: _SortBy.dateDesc,
              groupValue: _sortBy,
              title: const Text('Date (newest first)'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<_SortBy>(
              value: _SortBy.starsDesc,
              groupValue: _sortBy,
              title: const Text('Stars (highest first)'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() => _sortBy = choice);
    }
  }

  Future<void> _pickFilters() async {
    final choice = await showModalBottomSheet<_FilterBy>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => SafeArea(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<_FilterBy>(
              value: _FilterBy.all,
              groupValue: _filterBy,
              title: const Text('All posts'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<_FilterBy>(
              value: _FilterBy.withComments,
              groupValue: _filterBy,
              title: const Text('With comments'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<_FilterBy>(
              value: _FilterBy.withoutComments,
              groupValue: _filterBy,
              title: const Text('Without comments'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() => _filterBy = choice);
    }
  }

  String get _filterLabel {
    switch (_filterBy) {
      case _FilterBy.all:
        return 'Filters';
      case _FilterBy.withComments:
        return 'With comments';
      case _FilterBy.withoutComments:
        return 'Without comments';
    }
  }

  
  void _ensureStatsLoadedOnce(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    
    final needStats = _sortBy == _SortBy.starsDesc || _filterBy != _FilterBy.all;
    if (!needStats) return;

    
    final toLoad = <String>[];
    for (final d in docs) {
      final id = d.id;
      final missing = !_avgCache.containsKey(id) || !_countCache.containsKey(id);
      if (missing && !_inflight.contains(id)) {
        toLoad.add(id);
      }
    }

    if (toLoad.isEmpty) {
      
      if (_loadingStats) setState(() => _loadingStats = false);
      return;
    }

    setState(() => _loadingStats = true);
    try {
      await Future.wait(toLoad.map(_loadOnePostStats));
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

    bool _statsReadyFor(Iterable<String> ids) {
    
    for (final id in ids) {
      if (!_avgCache.containsKey(id) || !_countCache.containsKey(id)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadOnePostStats(String postId) async {
    _inflight.add(postId);
    try {
      final fb = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('feedback')
          .get();

      int count = fb.size;
      double sum = 0;
      for (final doc in fb.docs) {
        final m = doc.data();
        // 1) ratings.overall (0..5)
        final ratings = (m['ratings'] as Map?) ?? {};
        final overall = ratings['overall'];
        if (overall is num) sum += overall.toDouble();
        // 2) or an 'avg' field (compat)
        if (overall == null && m['avg'] is num) sum += (m['avg'] as num).toDouble();
      }
      final avg = count == 0 ? 0.0 : (sum / count);

      _avgCache[postId] = avg;
      _countCache[postId] = count;

      
      if (mounted) setState(() {});
    } catch (_) {
      
      _avgCache[postId] = 0.0;
      _countCache[postId] = 0;
      if (mounted) setState(() {});
    } finally {
      _inflight.remove(postId);
    }
  }

  int _compareDateDesc(dynamic a, dynamic b) {
    DateTime? da;
    DateTime? db;
    if (a is Timestamp) da = a.toDate();
    if (a is DateTime) da = a;
    if (b is Timestamp) db = b.toDate();
    if (b is DateTime) db = b;
    da ??= DateTime.fromMillisecondsSinceEpoch(0);
    db ??= DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  }

  String _fallbackName(String? email) {
    if (email == null || !email.contains('@')) return 'there';
    return email.split('@').first;
  }
}


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

          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18, height: 1.15),
                ),
                const SizedBox(height: 6),

                _FeedbackSummary(postId: postId),

                const SizedBox(height: 10),

                _AuthorLine(
                  authorId: authorId,
                  authorName: authorName,
                  createdAt: createdAt,
                ),

                const SizedBox(height: 10),

                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black87, height: 1.3),
                  ),

                const SizedBox(height: 12),

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
                alignment: Alignment.topCenter,
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
            if (overall == null && m['avg'] is num) {
              sum += (m['avg'] as num).toDouble();
            }
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
