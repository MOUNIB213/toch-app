import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final cs = ColorScheme.fromSeed(seedColor: const Color(0xFFE11D2A), brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: dark ? cs.copyWith(surface: const Color(0xFF0B0B0B)) : cs,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B0B0B) : null,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: app.t('title'),
          themeMode: app.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          locale: Locale(app.lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Home(),
        ),
      );
}
