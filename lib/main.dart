import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/tesla_theme.dart';
import 'presentation/shell/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바/내비게이션바 다크 스타일 고정 (테슬라 순정 UI 감성)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TeslaColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: TeslaEvApp(),
    ),
  );
}

class TeslaEvApp extends StatelessWidget {
  const TeslaEvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '테슬라_ev',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: TeslaTheme.darkTheme,
      theme: TeslaTheme.darkTheme,
      home: const MainShellScreen(),
    );
  }
}
