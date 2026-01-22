import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/login_service.dart';
import '../home_page.dart';
import '../language_selection_page.dart';
import '../language_settings.dart';
import 'terms_webview_page.dart';

class LoginPage extends StatefulWidget {
  final bool isEditMode;
  
  const LoginPage({
    super.key,
    this.isEditMode = false,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthdateController = TextEditingController();
  bool _acceptTerms = false;
  String? _firstNameError;
  String? _lastNameError;
  String? _birthdateError;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    final data = await LoginService.getLoginData();
    setState(() {
      _firstNameController.text = data['firstName'] ?? '';
      _lastNameController.text = data['lastName'] ?? '';
      _birthdateController.text = data['birthdate'] ?? '';
      _acceptTerms = true; // Auto-accept in edit mode
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _validateAndSave() {
    setState(() {
      // Clear previous errors
      _firstNameError = null;
      _lastNameError = null;
      _birthdateError = null;
      _termsError = null;

      // Validate first name
      if (_firstNameController.text.trim().isEmpty) {
        _firstNameError = 'Please enter your first name';
      }

      // Validate last name
      if (_lastNameController.text.trim().isEmpty) {
        _lastNameError = 'Please enter your last name';
      }

      // Validate birthdate
      if (_birthdateController.text.isEmpty) {
        _birthdateError = 'Please select your birthdate';
      }

      // Validate terms (only if not in edit mode)
      if (!widget.isEditMode && !_acceptTerms) {
        _termsError = 'Please accept Terms and Conditions';
      }
    });

    // If all validations pass, save and navigate
    if (_firstNameError == null &&
        _lastNameError == null &&
        _birthdateError == null &&
        (widget.isEditMode || _termsError == null)) {
      _saveLogin();
    }
  }

  Future<void> _saveLogin() async {
    await LoginService.saveLoginData(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      birthdate: _birthdateController.text,
    );

      if (mounted) {
        if (widget.isEditMode) {
          Navigator.of(context).pop(); // Go back to home page
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguageCode = LanguageSettings.selectedLanguageCode;
    final currentLanguageName = LanguageSettings.getLanguageName(currentLanguageCode);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient overlay filling whole page
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Container(
                child: Stack(
                  children: [
                    // Blurred gradient circle - matches HTML blur-3xl rounded-full
                    Positioned(
                      top: -192, // -top-48 = -192px
                      left: -96, // -left-24 = -96px
                      child: Container(
                        width: MediaQuery.of(context).size.width * 1.5, // w-[150%]
                        height: MediaQuery.of(context).size.width * 1.5, // h-[150%]
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFA5B4FC).withOpacity(0.4), // darker purple
                                const Color(0xFFC4B5FD).withOpacity(0.4), // darker purple
                                const Color(0xFFB8A5F8).withOpacity(0.4), // darker purple
                              ],
                          ),
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 64, sigmaY: 64), // blur-3xl
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFA5B4FC).withOpacity(0.4), // darker purple
                                    const Color(0xFFC4B5FD).withOpacity(0.4), // darker purple
                                    const Color(0xFFB8A5F8).withOpacity(0.4), // darker purple
                                  ],
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
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar for edit mode (similar to language page)
                if (widget.isEditMode)
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
                            Navigator.of(context).pop();
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
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                        const Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 32,
                      right: 32,
                      top: widget.isEditMode ? 16 : 48,
                      bottom: 32,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title section (hidden in edit mode)
                          if (!widget.isEditMode) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Welcome to',
                                            style: TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.025,
                                              color: Color(0xFF0F172A),
                                              height: 1.2,
                                            ),
                                          ),
                                          const Text(
                                            'Brain Booster',
                                            style: TextStyle(
                                              fontSize: 42,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.025,
                                              color: Color(0xFF0F172A),
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Language selector in top right
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const LanguageSelectionPage(),
                                          ),
                                        ).then((_) {
                                          // Rebuild the page when language changes
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(0xFFF1F5F9),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.language,
                                              color: Color(0xFF6366F1),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              currentLanguageName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please fill in your details to continue',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                          ],
                          // First Name
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _firstNameController,
                                  onChanged: (value) {
                                    if (_firstNameError != null) {
                                      setState(() {
                                        _firstNameError = null;
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'First Name',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 20,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (_firstNameError != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 24),
                                  child: Text(
                                    _firstNameError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                            const SizedBox(height: 16),
                            // Last Name
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _lastNameController,
                                  onChanged: (value) {
                                    if (_lastNameError != null) {
                                      setState(() {
                                        _lastNameError = null;
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Last Name',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 20,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (_lastNameError != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 24),
                                  child: Text(
                                    _lastNameError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                            const SizedBox(height: 16),
                            // Birthdate
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _birthdateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'Birthdate',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(32),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 20,
                                    ),
                                    suffixIcon: const Padding(
                                      padding: EdgeInsets.only(right: 24),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                  onTap: () {
                                    _selectDate(context).then((_) {
                                      if (_birthdateError != null && _birthdateController.text.isNotEmpty) {
                                        setState(() {
                                          _birthdateError = null;
                                        });
                                      }
                                    });
                                  },
                                ),
                              ),
                              if (_birthdateError != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 24),
                                  child: Text(
                                    _birthdateError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                            // Terms and Conditions (hidden in edit mode)
                            if (!widget.isEditMode) ...[
                              const SizedBox(height: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _acceptTerms = !_acceptTerms;
                                              // Clear error when checkbox is checked
                                              if (_acceptTerms) {
                                                _termsError = null;
                                              }
                                            });
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _acceptTerms
                                                    ? const Color(0xFF6366F1)
                                                    : const Color(0xFFCBD5E1),
                                                width: 2,
                                              ),
                                              color: _acceptTerms
                                                  ? const Color(0xFF6366F1)
                                                  : Colors.white,
                                            ),
                                            child: _acceptTerms
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 16,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const TermsWebViewPage(
                                                    url: 'https://www.google.com',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: RichText(
                                              text: TextSpan(
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                children: [
                                                  const TextSpan(text: 'I Accept '),
                                                  TextSpan(
                                                    text: 'Terms and Conditions',
                                                    style: const TextStyle(
                                                      color: Color(0xFF6366F1),
                                                      fontWeight: FontWeight.w500,
                                                      decoration:
                                                          TextDecoration.underline,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_termsError != null) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 44),
                                      child: Text(
                                        _termsError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                              // Login Button - Always enabled
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _validateAndSave,
                                borderRadius: BorderRadius.circular(32),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF6366F1),
                                        Color(0xFFA855F7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1)
                                            .withOpacity(0.4),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.isEditMode ? 'Save' : 'Login',
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom indicator bar
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 128,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[200]!.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
