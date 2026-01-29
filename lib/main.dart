import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'home_page.dart';
import 'language_settings.dart';
import 'game_settings.dart';
import 'language_selection_page.dart';
import 'app_localizations_helper.dart';
import 'portrait_aspect_wrapper.dart';
import 'services/login_service.dart';
import 'services/theme_service.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageSettings.initialize();
  await GameSettings.initialize();
  await ThemeService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Listen for language changes
    LanguageSettings.initialize();
    // Listen to locale changes and rebuild app
    LanguageSettings.localeNotifier.addListener(_onLocaleChanged);
    // Listen to theme changes and rebuild app
    ThemeService.themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    LanguageSettings.localeNotifier.removeListener(_onLocaleChanged);
    ThemeService.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current locale from notifier
    final currentLocale = LanguageSettings.localeNotifier.value;

    // Determine initial route based on language and login settings
    return FutureBuilder<Map<String, bool>>(
      future:
          Future.wait([
            Future.value(LanguageSettings.isFirstLaunch),
            LoginService.isLoginComplete(),
          ]).then(
            (results) => {
              'isFirstLaunch': results[0],
              'isLoginComplete': results[1],
            },
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final isFirstLaunch = snapshot.data!['isFirstLaunch'] ?? true;
        final isLoginComplete = snapshot.data!['isLoginComplete'] ?? false;

        // Determine initial route:
        // 1. First launch -> Language Selection Page
        // 2. Language selected but login not complete -> Login Page
        // 3. Both complete -> Home Page
        Widget initialRoute;
        if (isFirstLaunch) {
          initialRoute = const LanguageSelectionPage();
        } else if (!isLoginComplete) {
          initialRoute = const LoginPage();
        } else {
          initialRoute = const HomePage();
        }

        // Get current theme mode
        final currentThemeMode = ThemeService.themeModeNotifier.value;

        return MaterialApp(
          title: 'Brain Booster',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            primaryColor: const Color(0xFF6366F1),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF0F172A)),
              bodyMedium: TextStyle(color: Color(0xFF0F172A)),
              bodySmall: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            cardColor: const Color(0xFF1E293B),
            primaryColor: const Color(0xFF6366F1),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFFF1F5F9)),
              bodyMedium: TextStyle(color: Color(0xFFF1F5F9)),
              bodySmall: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          themeMode: currentThemeMode,
          // Localization configuration
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizationsHelper.getSupportedLocales(),
          locale: currentLocale,
          // Use builder to wrap all routes - automatically applies to all pages
          builder: (context, child) {
            if (child == null) {
              return const SizedBox.shrink();
            }
            return PortraitAspectWrapper(
              backgroundColor: Colors.black,
              child: child,
            );
          },
          home: initialRoute,
        );
      },
    );
  }
}
