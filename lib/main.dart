import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/home/home_page.dart';
import 'shared/no_glow_scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF303F9F),
          secondary: const Color(0xFFFFC107),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: const Color(0xFF1A237E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // 這是設定 App 背景色的正確方式
        fontFamily: GoogleFonts.notoSansTc().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1A237E),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF303F9F)),
        ),
        // --- [修正] 使用 chipTheme 來設定 ActionChip 的樣式 ---
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[200],
          labelStyle: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.normal,
          ),
          iconTheme: const IconThemeData(color: Colors.black54, size: 16),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
      locale: const Locale('zh', 'TW'),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
