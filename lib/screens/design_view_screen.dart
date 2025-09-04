import 'package:flutter/material.dart';

class DesignViewArgs {
  final String imageUrl;
  final String postId; // used for Hero tag
  DesignViewArgs({required this.imageUrl, required this.postId});
}

/// Full-screen, edge-to-edge design viewer with pinch-zoom.
/// Route name suggestion: '/designView'
class DesignViewScreen extends StatelessWidget {
  const DesignViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a =
        ModalRoute.of(context)!.settings.arguments as DesignViewArgs;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Back to feedback',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            // Image viewer
            Expanded(
              child: Center(
                child: Hero(
                  tag: 'designImage-${a.postId}',
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.7,
                    maxScale: 4,
                    child: Image.network(
                      a.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
