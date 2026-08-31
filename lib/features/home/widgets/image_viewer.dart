import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Full-screen image viewer. Supports:
/// - Multiple images via horizontal PageView
/// - Pinch-to-zoom via InteractiveViewer
/// - Swipe down to dismiss
/// - Hero animation from the thumbnail
///
/// Usage:
/// ```dart
/// Navigator.push(context, ImageViewerPage.route(
///   imageUrls: post.imageUrls,
///   initialIndex: 0,
///   heroTag: 'post_image_${post.id}_0',
/// ));
/// ```
class ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String heroTag;

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.heroTag,
  });

  static Route<void> route({
    required List<String> imageUrls,
    int initialIndex = 0,
    required String heroTag,
  }) {
    return PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => ImageViewerPage(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        heroTag: heroTag,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.imageUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe down fast → close
          if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
            Navigator.pop(context);
          }
        },
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.imageUrls.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, i) {
            final url = widget.imageUrls[i];
            final tag = i == widget.initialIndex ? widget.heroTag : 'img_$i';
            return Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
