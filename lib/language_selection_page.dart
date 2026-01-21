import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'language_settings.dart';
import 'home_page.dart';
import 'app_localizations_helper.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? _selectedLanguageCode;
  final Map<String, List<String>> _groupedLanguages = {};

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = LanguageSettings.selectedLanguageCode;
    _groupLanguages();
  }

  void _groupLanguages() {
    final languages = LanguageSettings.getSupportedLanguageCodes();

    for (final code in languages) {
      final name = LanguageSettings.getLanguageName(code);
      final firstLetter = name[0].toUpperCase();

      if (!_groupedLanguages.containsKey(firstLetter)) {
        _groupedLanguages[firstLetter] = [];
      }
      _groupedLanguages[firstLetter]!.add(code);
    }

    // Sort each group
    _groupedLanguages.forEach((key, value) {
      value.sort(
        (a, b) => LanguageSettings.getLanguageName(
          a,
        ).compareTo(LanguageSettings.getLanguageName(b)),
      );
    });
  }

  void _selectLanguage(String languageCode) {
    setState(() {
      _selectedLanguageCode = languageCode;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedLanguageCode == null) return;

    await LanguageSettings.setLanguage(_selectedLanguageCode!);

    // If this is first launch, mark it complete and navigate to home
    if (LanguageSettings.isFirstLaunch) {
      await LanguageSettings.markFirstLaunchComplete();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else {
      // If not first launch, just pop back with result and trigger app rebuild
      if (mounted) {
        Navigator.of(context).pop(true);
        // Trigger app rebuild by navigating to a new MaterialApp
        // The app will rebuild with new locale
      }
    }
  }

  Widget _buildFrostedCard({
    required Widget child,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.white.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 0,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, 1),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRadio({required bool isSelected}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
          width: 2,
        ),
        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsHelper.of(context);
    final sortedKeys = _groupedLanguages.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Back button - left aligned with frosted glass effect
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const HomePage(),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.8),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                              blurStyle: BlurStyle.inner,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF475569),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Spacer to center the title
                    const Spacer(),
                    // Title - centered on screen
                    Text(
                      l10n.languages,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    // Spacer to balance the back button
                    const Spacer(),
                    // Invisible placeholder to balance the back button width
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Language list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final letter = sortedKeys[index];
                    final languages = _groupedLanguages[letter]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            top: 24,
                            bottom: 12,
                          ),
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        // Language items
                        ...languages.map((code) {
                          final name = LanguageSettings.getLanguageName(code);
                          final native = LanguageSettings.getNativeLanguageName(
                            code,
                          );
                          final isSelected = _selectedLanguageCode == code;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildFrostedCard(
                              isSelected: isSelected,
                              onTap: () => _selectLanguage(code),
                              child: Row(
                                children: [
                                  _buildCustomRadio(isSelected: isSelected),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: name != native
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? const Color(0xFF6366F1)
                                                      : const Color(0xFF334155),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                native,
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFF6366F1)
                                                  : const Color(0xFF334155),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              // Save button at bottom with gradient fade
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),

                child: Column(
                  children: [
                    // Glossy Save button
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 25,
                            offset: const Offset(0, -5),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 2),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, -2),
                            blurStyle: BlurStyle.inner,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _selectedLanguageCode != null
                              ? _saveAndContinue
                              : null,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.center,
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Text(
                                LanguageSettings.isFirstLaunch
                                    ? l10n.continueButton
                                    : l10n.save,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
