import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/home/home_page.dart';
import 'shared/no_glow_scroll_behavior.dart';

void main() async {
  // 確保 Flutter 已初始化
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 Firebase
  await Firebase.initializeApp();
  runApp(const SubscriptionApp());
}

class SubscriptionApp extends StatelessWidget {
  const SubscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '訂閱管家',
      scrollBehavior: NoGlowScrollBehavior(),
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: GoogleFonts.notoSansTc().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1A237E),
        ),
      ),
      // App 的進入點直接設為主畫面
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
