import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/app_bottom_nav.dart';
import 'design_view_screen.dart';


class FeedbackScreenArgs {
  final String postId;
  final String title;
  final String authorName;
  final String? authorPhotoUrl; 
  final String? coverUrl;       
  final String? description;    
  final dynamic createdAt;     

  FeedbackScreenArgs({
    required this.postId,
    required this.title,
    required this.authorName,
    this.authorPhotoUrl,
    this.coverUrl,
    this.description,
    this.createdAt,
  });
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  
  double visual = 0, accessibility = 0, usability = 0, clarity = 0, overall = 0;

 
  final visualC = TextEditingController();
  final accessibilityC = TextEditingController();
  final usabilityC = TextEditingController();
  final clarityC = TextEditingController();
  final overallC = TextEditingController();

  bool submitting = false;

  @override
  void dispose() {
    visualC.dispose();
    accessibilityC.dispose();
    usabilityC.dispose();
    clarityC.dispose();
    overallC.dispose();
    super.dispose();
  }

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  double _avg(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  Future<void> _submit() async {
    final args =
        ModalRoute.of(context)!.settings.arguments as FeedbackScreenArgs;
    final user = FirebaseAuth.instance.currentUser!;

    if (overall <= 0) {
      _show('Please set an overall rating.');
      return;
    }

    setState(() => submitting = true);

    try {
      final doc = FirebaseFirestore.instance
          .collection('posts')
          .doc(args.postId)
          .collection('feedback')
          .doc(user.uid);

     
      final exists = (await doc.get()).exists;
      if (exists) {
        setState(() => submitting = false);
        _show('You already left feedback for this post.');
        return;
      }

      
      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profile = profileSnap.data() ?? {};

      final nameFromUsername = (profile['username'] as String?) ?? '';
      final nameFromName = (profile['name'] as String?) ?? '';
      final nameFromAuth = user.displayName ?? '';

      final reviewerName = nameFromUsername.isNotEmpty
          ? nameFromUsername
          : (nameFromName.isNotEmpty
              ? nameFromName
              : (nameFromAuth.isNotEmpty ? nameFromAuth : 'Anonymous'));

      final reviewerPhotoUrl =
          (profile['photoUrl'] as String?) ?? (user.photoURL ?? '');

      await doc.set({
        'reviewerId': user.uid,
        'reviewerName': reviewerName,
        'reviewerPhotoUrl': reviewerPhotoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'ratings': {
          'visual': visual,
          'accessibility': accessibility,
          'usability': usability,
          'clarity': clarity,
          'overall': overall,
        },
        'notes': {
          'visual': visualC.text.trim(),
          'accessibility': accessibilityC.text.trim(),
          'usability': usabilityC.text.trim(),
          'clarity': clarityC.text.trim(),
          'overall': overallC.text.trim(),
        },
        'avg': _avg([visual, accessibility, usability, clarity, overall]),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feedbackThanks');
    } catch (e) {
      setState(() => submitting = false);
      _show('Failed to submit feedback. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ModalRoute.of(context)!.settings.arguments as FeedbackScreenArgs;

    final fbRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(a.postId)
        .collection('feedback')
        .orderBy('createdAt', descending: true);

    final me = FirebaseAuth.instance.currentUser!;
    final myDoc = FirebaseFirestore.instance
        .collection('posts')
        .doc(a.postId)
        .collection('feedback')
        .doc(me.uid);

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

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: myDoc.snapshots(),
              builder: (context, mySnap) {
                final alreadyLeft = mySnap.data?.exists ?? false;

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
                            'Back to home',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),

                    
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: (a.authorPhotoUrl?.isNotEmpty ?? false)
                              ? NetworkImage(a.authorPhotoUrl!)
                              : null,
                          child: (a.authorPhotoUrl?.isEmpty ?? true)
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.authorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              if (_formatDate(_toDate(a.createdAt)) != null)
                                Text(_formatDate(_toDate(a.createdAt))!,
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                        ),
                        _Stars(value: avg),
                        const SizedBox(width: 4),
                        Text(avg.toStringAsFixed(1),
                            style:
                                const TextStyle(color: Colors.black54)),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 16),
                            const SizedBox(width: 2),
                            Text('$count',
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 10),

                    
                    Material(
                      elevation: 1,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            
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
                                        ? Image.network(
                                            a.coverUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.image, size: 28),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                           
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  if ((a.description?.isNotEmpty ?? false))
                                    Text(
                                      a.description!,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.black87),
                                    ),
                                  const SizedBox(height: 4),
                                  TextButton(
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    
                    _Section(
                      title: 'Visual Appeal',
                      question:
                          'How attractive and polished does this design look?',
                      value: visual,
                      onChanged: (v) => setState(() => visual = v),
                      controller: visualC,
                    ),
                    _Section(
                      title: 'Accessibility',
                      question:
                          'Can people of all abilities use this comfortably?',
                      value: accessibility,
                      onChanged: (v) => setState(() => accessibility = v),
                      controller: accessibilityC,
                    ),
                    _Section(
                      title: 'Usability',
                      question:
                          'Is it straightforward to navigate and accomplish tasks?',
                      value: usability,
                      onChanged: (v) => setState(() => usability = v),
                      controller: usabilityC,
                    ),
                    _Section(
                      title: 'Clarity & Structure',
                      question:
                          'Are information and actions clear and well-organized?',
                      value: clarity,
                      onChanged: (v) => setState(() => clarity = v),
                      controller: clarityC,
                    ),
                    _Section(
                      title: 'Overall Experience',
                      question:
                          'Your gut-level rating of the design as a whole.',
                      value: overall,
                      onChanged: (v) => setState(() => overall = v),
                      controller: overallC,
                    ),

                    const SizedBox(height: 10),

                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: submitting ? null : () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF64330A), 
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8), 
                            minimumSize: const Size(0, 40),
                            shape: const StadiumBorder(), 
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: .25,
                            ),
                          ),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: submitting || alreadyLeft ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE1D145), 
                            foregroundColor: Colors.white,               
                            elevation: 3,
                            shadowColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            minimumSize: const Size(0, 40),
                            shape: const StadiumBorder(), 
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: .25,
                            ),
                          ),
                          child: Text(
                              alreadyLeft ? 'ALREADY SUBMITTED' : 'SUBMIT'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
    );
  }
}



class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.question,
    required this.value,
    required this.onChanged,
    required this.controller,
  });

  final String title;
  final String question;
  final double value;
  final ValueChanged<double> onChanged;
  final TextEditingController controller;

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
          Text(question,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          StarPicker(value: value, onChanged: onChanged),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            elevation: 0.5,
            borderRadius: BorderRadius.circular(12),
            child: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Add details',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final filled = value.round(); 
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isOn = i < filled;
        return InkWell(
          onTap: () => onChanged(i + 1.0),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              isOn ? Icons.star : Icons.star_border,
              size: 24,
              color: const Color(0xFFD9C63F),
            ),
          ),
        );
      }),
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
