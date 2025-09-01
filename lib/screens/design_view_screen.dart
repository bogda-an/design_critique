import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';

/// Route expects a String (image url) as arguments.
class DesignViewScreen extends StatelessWidget {
  const DesignViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String url = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Design', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SafeArea(
        // Scroll vertically if the image is long
        child: SingleChildScrollView(
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Icon(Icons.broken_image_outlined, size: 48),
                    SizedBox(height: 8),
                    Text('Failed to load image'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // ✅ unified bottom nav
      bottomNavigationBar: const AppBottomNav(current: BottomTab.home),
      backgroundColor: Colors.white,
    );
  }
}
