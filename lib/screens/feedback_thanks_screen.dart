import 'package:flutter/material.dart';

class FeedbackThanksScreen extends StatelessWidget {
  const FeedbackThanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outlined, size: 120, color: Colors.brown.shade700),
                const SizedBox(height: 16),
                const Text('Thanks for your feedback!',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/home')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9C63F),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 2,
                  ),
                  child: const Text('BACK TO HOME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
