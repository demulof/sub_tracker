import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_config.dart';
import 'features/home/home_page.dart';
import 'firebase_options.dart';
import 'services/exchange_rate_service.dart';
import 'shared/no_glow_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('zh_TW');
  // 匯率在背景載入，不阻擋 app 啟動。
  ExchangeRateService.instance.init();
  runApp(const SubscriptionApp());
}

class SubscriptionApp extends StatelessWidget {
  const SubscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
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
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[200],
          labelStyle: const TextStyle(color: Colors.black87),
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
