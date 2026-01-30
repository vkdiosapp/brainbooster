import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/game_history_service.dart';
import '../services/login_service.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';
import 'settings_page.dart';
import '../language_selection_page.dart';
import 'terms_webview_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _firstName = '';
  String _lastName = '';
  final GlobalKey _shareTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await LoginService.getLoginData();
    if (!mounted) return;
    setState(() {
      _firstName = data['firstName'] ?? '';
      _lastName = data['lastName'] ?? '';
    });
  }

  String get _displayName {
    final full = '${_firstName.trim()} ${_lastName.trim()}'.trim();
    return full.isEmpty ? 'User' : full;
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: child,
    );
  }

  Widget _buildActionTile({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    Key? key,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      key: key,
      onTap: onTap,
      leading: Icon(
        icon,
        color: iconColor ?? AppTheme.iconColor(context),
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppTheme.textPrimary(context),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.iconSecondary(context),
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary(context),
          ),
        ),
        content: Text(
          'This will remove your profile and all saved data from this device. This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GameHistoryService.clearAllAnalyticsData();
      await LoginService.clearLoginData();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryWithOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LoginPage(isEditMode: true),
                                    ),
                                  )
                                  .then((_) => _loadProfile());
                            },
                            child: Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildActionTile(
                      label: 'Rate us',
                      icon: Icons.star_rate_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thanks for your support!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    _buildActionTile(
                      label: 'Settings',
                      icon: Icons.settings,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    _buildActionTile(
                      label: 'Language',
                      icon: Icons.language,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LanguageSelectionPage(),
                          ),
                        );
                      },
                    ),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    _buildActionTile(
                      label: 'Terms and Conditions',
                      icon: Icons.description,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TermsWebViewPage(
                              url:
                                  'https://docs.google.com/document/d/1Vl-slTVjGTIDBaU4tkhlOG9bDdTHiWGPZYwHP904E_A/edit?usp=sharing',
                              title: 'Terms and Conditions',
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    _buildActionTile(
                      label: 'Privacy Policy',
                      icon: Icons.privacy_tip,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TermsWebViewPage(
                              url:
                                  'https://docs.google.com/document/d/1Vl-slTVjGTIDBaU4tkhlOG9bDdTHiWGPZYwHP904E_A/edit?usp=sharing',
                              title: 'Privacy Policy',
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    _buildActionTile(
                      label: 'Share App',
                      icon: Icons.share,
                      onTap: () {
                        final context = _shareTileKey.currentContext;
                        if (context != null) {
                          final renderBox =
                              context.findRenderObject() as RenderBox;
                          final origin =
                              renderBox.localToGlobal(Offset.zero) &
                              renderBox.size;
                          Share.share(
                            'Try BrainScale! Fun brain training games to boost focus and speed.\n\nhttps://apps.apple.com/us/app/brainscale/id6758104985',
                            sharePositionOrigin: origin,
                          );
                        } else {
                          Share.share(
                            'Try BrainScale! Fun brain training games to boost focus and speed.\n\nhttps://apps.apple.com/us/app/brainscale/id6758104985',
                          );
                        }
                      },
                      key: _shareTileKey,
                    ),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    _buildActionTile(
                      label: 'Delete Account',
                      icon: Icons.delete_outline,
                      onTap: _confirmDeleteAccount,
                      iconColor: AppTheme.errorColor,
                      textColor: AppTheme.errorColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
