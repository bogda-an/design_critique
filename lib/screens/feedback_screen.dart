import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/app_bottom_nav.dart';

class FeedbackScreenArgs {
  final String postId;
  final String title;
  final String authorName;
  final String? coverUrl;
  final dynamic createdAt;

  FeedbackScreenArgs({
    required this.postId,
    required this.title,
    required this.authorName,
    this.coverUrl,
    this.createdAt,
  });
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // ratings
  double visual = 0, accessibility = 0, usability = 0, clarity = 0, overall = 0;

  // notes
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

  void _show(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit(FeedbackScreenArgs a) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      _show('Please log in first.');
      return;
    }
    if (overall == 0) {
      _show('Please set an overall rating.');
      return;
    }

    setState(() => submitting = true);

    try {
      final doc = FirebaseFirestore.instance
          .collection('posts')
          .doc(a.postId)
          .collection('feedback')
          .doc(u.uid);

      // If it exists, block here too (UI also disables, and rules enforce)
      final exists = (await doc.get()).exists;
      if (exists) {
        setState(() => submitting = false);
        _show('You already left feedback for this post.');
        return;
      }

      await doc.set({
        'reviewerId': u.uid,
        'reviewerName': u.displayName ?? 'Anonymous',
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
      _show('Failed to submit. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ModalRoute.of(context)!.settings.arguments as FeedbackScreenArgs;

    final myDoc = FirebaseFirestore.instance
        .collection('posts')
        .doc(a.postId)
        .collection('feedback')
        .doc(FirebaseAuth.instance.currentUser?.uid ?? '_');

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: myDoc.snapshots(),
          builder: (context, snap) {
            final alreadyLeft = snap.data?.exists ?? false;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

                const SizedBox(height: 8),

                Text(a.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                if (alreadyLeft)
                  Material(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'You already submitted feedback for this post.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                if (!alreadyLeft) ...[
                  _Section(
                    title: 'Visual Appeal',
                    question:
                        'How attractive and polished does this design look?',
                    onChanged: (v) => setState(() => visual = v),
                    controller: visualC,
                  ),
                  _Section(
                    title: 'Accessibility',
                    question:
                        'Can people of all abilities use this comfortably?',
                    onChanged: (v) => setState(() => accessibility = v),
                    controller: accessibilityC,
                  ),
                  _Section(
                    title: 'Usability',
                    question:
                        'Is it straightforward to navigate and accomplish tasks?',
                    onChanged: (v) => setState(() => usability = v),
                    controller: usabilityC,
                  ),
                  _Section(
                    title: 'Clarity & Structure',
                    question:
                        'Are information and actions clear and well-organized?',
                    onChanged: (v) => setState(() => clarity = v),
                    controller: clarityC,
                  ),
                  _Section(
                    title: 'Overall Experience',
                    question: 'Your gut-level rating of the design as a whole.',
                    onChanged: (v) => setState(() => overall = v),
                    controller: overallC,
                  ),

                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: submitting || alreadyLeft
                        ? null
                        : () => _submit(a),
                    child: submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ],
              ],
            );
          },
        ),
      ),

      // ✅ unified bottom nav
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
    );
  }

  double _avg(List<double> xs) {
    final n = xs.where((e) => e > 0).toList();
    if (n.isEmpty) return 0;
    final s = n.fold(0.0, (a, b) => a + b);
    return s / n.length;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.question,
    required this.onChanged,
    required this.controller,
  });

  final String title;
  final String question;
  final ValueChanged<double> onChanged;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    double localValue = 0;

    Widget stars(double v, void Function(double) set) {
      const size = 22.0;
      int full = v.floor();
      double frac = v - full;
      bool half = frac >= 0.25 && frac < 0.75;
      int extra = frac >= 0.75 ? 1 : 0;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          IconData icon;
          if (i < full + extra) {
            icon = Icons.star;
          } else if (i == full && half) {
            icon = Icons.star_half;
          } else {
            icon = Icons.star_border;
          }
          return InkWell(
            onTap: () {
              set(i + 1.0);
              onChanged(i + 1.0);
            },
            child: Icon(icon, size: size, color: const Color(0xFFD9C63F)),
          );
        }),
      );
    }

    return StatefulBuilder(builder: (context, setState) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(question, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            stars(localValue, (v) => setState(() => localValue = v)),
            const SizedBox(height: 8),
            Material(
              elevation: 2,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add your note (optional)',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
