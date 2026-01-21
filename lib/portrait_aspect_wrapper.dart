import 'package:flutter/material.dart';

/// Wrapper widget that maintains portrait aspect ratio in landscape mode
/// When device rotates to landscape, shows portrait layout centered with blank space on sides
/// Dynamically calculates portrait aspect ratio based on device's actual portrait dimensions
class PortraitAspectWrapper extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;

  const PortraitAspectWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  State<PortraitAspectWrapper> createState() => _PortraitAspectWrapperState();
}

class _PortraitAspectWrapperState extends State<PortraitAspectWrapper> {
  // Store the device's portrait dimensions (width and height when in portrait)
  double? _portraitWidth;
  double? _portraitHeight;

  void _updatePortraitDimensions(double width, double height) {
    // Store portrait dimensions when device is in portrait mode
    // Portrait mode: height > width
    if (height > width) {
      _portraitWidth = width;
      _portraitHeight = height;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        // Update portrait dimensions if we're in portrait mode
        _updatePortraitDimensions(screenWidth, screenHeight);
        
        // Determine if we're in landscape mode
        final isLandscape = screenWidth > screenHeight;
        
        if (isLandscape && _portraitWidth != null && _portraitHeight != null) {
          // Calculate dynamic portrait aspect ratio from device's actual portrait dimensions
          final portraitAspectRatio = _portraitWidth! / _portraitHeight!;
          
          // Calculate the width we should use for portrait content
          // We want to fit the portrait height within the landscape height
          // So: width = height * aspectRatio
          final portraitContentWidth = screenHeight * portraitAspectRatio;
          
          // Ensure content width doesn't exceed screen width
          final contentWidth = portraitContentWidth > screenWidth 
              ? screenWidth 
              : portraitContentWidth;
          
          final bgColor = widget.backgroundColor ?? Colors.black;
          
          final mediaQuery = MediaQuery.of(context);
          
          // Override MediaQuery to provide portrait dimensions to child
          return MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(contentWidth, screenHeight),
            ),
            child: Container(
              color: bgColor,
              width: screenWidth,
              height: screenHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Full screen black background
                  Positioned.fill(
                    child: Container(color: bgColor),
                  ),
                  // Centered content with strict clipping
                  Positioned(
                    left: (screenWidth - contentWidth) / 2,
                    top: 0,
                    width: contentWidth,
                    height: screenHeight,
                    child: ClipRect(
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: contentWidth,
                        height: screenHeight,
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Portrait mode - show content normally
          return widget.child;
        }
      },
    );
  }
}
