import 'package:flutter/material.dart';
import 'multiplayer_spinner_page.dart';

class MultiplayerConfigPage extends StatefulWidget {
  const MultiplayerConfigPage({super.key});

  @override
  State<MultiplayerConfigPage> createState() => _MultiplayerConfigPageState();
}

class _MultiplayerConfigPageState extends State<MultiplayerConfigPage> {
  final List<TextEditingController> _userControllers = [];
  final List<FocusNode> _userFocusNodes = [];
  final List<String> _users = [];
  int _rounds = 5; // Default rounds set to 5

  @override
  void initState() {
    super.initState();
    // Add one default user so it doesn't look empty
    _users.add('');
    _userControllers.add(TextEditingController());
    _userFocusNodes.add(FocusNode());
    // Focus on the first field after the widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userFocusNodes.isNotEmpty) {
        _userFocusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _userControllers) {
      controller.dispose();
    }
    for (var focusNode in _userFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _addNewUser() {
    setState(() {
      _users.add('');
      _userControllers.add(TextEditingController());
      _userFocusNodes.add(FocusNode());
    });
    // Focus on the newly added field after the widget rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userFocusNodes.isNotEmpty) {
        _userFocusNodes.last.requestFocus();
      }
    });
  }

  void _removeUser(int index) {
    setState(() {
      _userControllers[index].dispose();
      _userFocusNodes[index].dispose();
      _userControllers.removeAt(index);
      _userFocusNodes.removeAt(index);
      _users.removeAt(index);
    });
  }

  void _startMultiplayer() {
    // Update users from controllers
    final updatedUsers = <String>[];
    for (var controller in _userControllers) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        updatedUsers.add(text);
      }
    }

    if (updatedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for duplicate names (case-insensitive)
    final seenNames = <String>{};
    for (var user in updatedUsers) {
      final lowerUser = user.toLowerCase();
      if (seenNames.contains(lowerUser)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicate user name: "$user". Please use unique names.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      seenNames.add(lowerUser);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            MultiplayerSpinnerPage(users: updatedUsers, rounds: _rounds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: const Color(0xFF2D2D44),
        body: SafeArea(
        child: Column(
          children: [
            // Fixed header with back button and title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back button - left aligned
                  // TODO: Add back button later
                  // Align(
                  //   alignment: Alignment.centerLeft,
                  //   child: Container(
                  //     width: 48,
                  //     height: 48,
                  //     decoration: BoxDecoration(
                  //       color: const Color(0xFF6C5CE7),
                  //       shape: BoxShape.circle,
                  //       boxShadow: [
                  //         BoxShadow(
                  //           color: Colors.black.withOpacity(0.3),
                  //           blurRadius: 8,
                  //           offset: const Offset(0, 2),
                  //         ),
                  //       ],
                  //     ),
                  //     child: IconButton(
                  //       icon: const Icon(Icons.arrow_back, color: Colors.white),
                  //       onPressed: () => Navigator.of(context).pop(),
                  //     ),
                  //   ),
                  // ),
                  // Title - centered on screen
                  const Text(
                    'Multiplayer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Rounds Selection Section (5 to 10)
                    Card(
                      color: const Color(0xFF3D3D5C),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How Many Rounds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: List.generate(6, (index) {
                                final roundNumber = index + 5; // 5 to 10
                                final isSelected = _rounds == roundNumber;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _rounds = roundNumber;
                                        });
                                      },
                                      child: Container(
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF6C5CE7)
                                              : const Color(0xFF2D2D44),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$roundNumber',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Users List Section
                    Card(
                      color: const Color(0xFF3D3D5C),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Users',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(_users.length, (index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _userControllers[index],
                                        focusNode: _userFocusNodes[index],
                                        textCapitalization:
                                            TextCapitalization.words,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter user name',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF2D2D44),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () => _removeUser(index),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (_users.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No users. Click "User" to add users.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Add User button at bottom
                            TextButton.icon(
                              onPressed: _addNewUser,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'User',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Start Button
                    ElevatedButton(
                      onPressed: _startMultiplayer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

