import 'dart:io' as io;

import 'package:flutter/material.dart';

class FullscreenImageGallery extends StatefulWidget {
  const FullscreenImageGallery({
    super.key,
    required this.photoPaths,
    required this.initialIndex,
  });

  final List<String> photoPaths;
  final int initialIndex;

  static Route<void> route({
    required List<String> photoPaths,
    required int initialIndex,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (BuildContext context, _, __) => FullscreenImageGallery(
        photoPaths: photoPaths,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<FullscreenImageGallery> createState() =>
      _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final double velocityY = details.velocity.pixelsPerSecond.dy;
    if (velocityY.abs() > 300) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            GestureDetector(
              onVerticalDragEnd: _onVerticalDragEnd,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.photoPaths.length,
                onPageChanged: (int index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (BuildContext context, int index) {
                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        io.File(widget.photoPaths[index]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.photoPaths.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
