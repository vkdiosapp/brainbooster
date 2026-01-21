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
  
  double _getPortraitAspectRatio(double screenWidth, double screenHeight) {
    // If we have stored portrait dimensions, use them (most accurate)
    if (_portraitWidth != null && _portraitHeight != null) {
      return _portraitWidth! / _portraitHeight!;
    }
    
    // If app starts in landscape, calculate actual portrait dimensions from current screen
    // In landscape: width > height
    // Portrait dimensions are: width = current height, height = current width
    // So portrait aspect ratio = (current height) / (current width)
    if (screenWidth > screenHeight) {
      // We're in landscape, calculate actual portrait aspect ratio
      // Portrait width = screenHeight (smaller dimension)
      // Portrait height = screenWidth (larger dimension)
      // Aspect ratio = width/height = screenHeight/screenWidth
      return screenHeight / screenWidth;
    }
    
    // If we're in portrait mode, use current dimensions directly
    return screenWidth / screenHeight;
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
        
        if (isLandscape) {
          // Calculate dynamic portrait aspect ratio
          // Will use stored dimensions if available, otherwise estimate or use default
          final portraitAspectRatio = _getPortraitAspectRatio(screenWidth, screenHeight);
          
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
