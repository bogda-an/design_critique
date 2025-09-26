import 'package:flutter/material.dart';

enum BottomTab { home, upload, profile }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});
  final BottomTab current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBtn(
                icon: Icons.home_rounded,
                label: 'Home',
                active: current == BottomTab.home,
                onTap: () => _goTo(context, BottomTab.home),
              ),
              _NavBtn(
                icon: Icons.add_circle_outline,
                label: 'Upload',
                active: current == BottomTab.upload,
                onTap: () => _goTo(context, BottomTab.upload),
              ),
              _NavBtn(
                icon: Icons.person_rounded,
                label: 'Profile',
                active: current == BottomTab.profile,
                onTap: () => _goTo(context, BottomTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goTo(BuildContext context, BottomTab dest) {
    final currentName = ModalRoute.of(context)?.settings.name;

    switch (dest) {
      case BottomTab.home:
        if (currentName == '/home' || currentName == Navigator.defaultRouteName) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        break;

      case BottomTab.upload:
        if (currentName == '/upload') return;
        Navigator.pushNamed(context, '/upload');
        break;

      case BottomTab.profile:
        if (currentName == '/profile') return;
        try {
          Navigator.pushNamed(context, '/profile');
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile screen not available yet.')),
          );
        }
        break;
    }
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

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
