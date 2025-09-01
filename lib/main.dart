import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/post_thanks_screen.dart';
import 'screens/comment_detail_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/design_view_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/feedback_thanks_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DesignCritiqueApp());
}

class AppTheme {
  static const Color primaryYellow = Color(0xFFD9C63F);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryYellow),
      scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Colors.black54),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          backgroundColor: primaryYellow,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 16),
      ),
    );
  }
}

class DesignCritiqueApp extends StatelessWidget {
  const DesignCritiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Design Critique',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/login',
      routes: {
        '/home': (_) => const HomeScreen(),
        '/upload': (_) => const UploadScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/comments': (_) => const CommentsScreen(),
        '/commentDetail': (_) => const CommentDetailScreen(),
        '/designView': (_) => const DesignViewScreen(),
        '/feedback': (_) => const FeedbackScreen(),
        '/feedbackThanks': (_) => const FeedbackThanksScreen(),
        '/postThanks': (_) => const PostThanksScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
      },
    );
  }
}