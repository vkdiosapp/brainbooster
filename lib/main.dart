import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'home_page.dart';
import 'language_settings.dart';
import 'language_selection_page.dart';
import 'app_localizations_helper.dart';
import 'portrait_aspect_wrapper.dart';
import 'services/login_service.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageSettings.initialize();
  
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
  }
  
  @override
  void dispose() {
    LanguageSettings.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }
  
  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current locale from notifier
    final currentLocale = LanguageSettings.localeNotifier.value;
    
    // Determine initial route based on login and language settings
    return FutureBuilder<bool>(
      future: LoginService.isLoginComplete(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final isLoginComplete = snapshot.data ?? false;
        
        // Show login page if not completed
        if (!isLoginComplete) {
          return MaterialApp(
            title: 'Brain Booster',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              scaffoldBackgroundColor: Colors.white,
            ),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizationsHelper.getSupportedLocales(),
            locale: currentLocale,
            builder: (context, child) {
              if (child == null) {
                return const SizedBox.shrink();
              }
              return PortraitAspectWrapper(
                backgroundColor: Colors.black,
                child: child,
              );
            },
            home: const LoginPage(),
          );
        }
        
        // Show language selection page on first launch, otherwise show home page
        final initialRoute = LanguageSettings.isFirstLaunch
            ? const LanguageSelectionPage()
            : const HomePage();
        
        return MaterialApp(
          title: 'Brain Booster',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            scaffoldBackgroundColor: Colors.white,
          ),
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
