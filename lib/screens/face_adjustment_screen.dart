import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/face_mask_region.dart';
import '../services/config_service.dart';

/// Screen allowing the user to adjust the face blur position and size
/// by dragging a circle over the photo. The mosaic blur follows the circle in real-time.
class FaceAdjustmentScreen extends StatefulWidget {
  final String imagePath;
  final String angleLabel;
  final FaceMaskRegion initialRegion;
  final FaceMaskRegion autoDetectedRegion;
  final Uint8List? imageBytes;
  final ui.Image? preloadedMosaicImage;
  final Size? preloadedNaturalSize;

  const FaceAdjustmentScreen({
    super.key,
    required this.imagePath,
    required this.angleLabel,
    required this.initialRegion,
    required this.autoDetectedRegion,
    this.imageBytes,
    this.preloadedMosaicImage,
    this.preloadedNaturalSize,
  });

  @override
  State<FaceAdjustmentScreen> createState() => _FaceAdjustmentScreenState();
}

class _FaceAdjustmentScreenState extends State<FaceAdjustmentScreen> {
  bool _isLoading = true;
  ui.Image? _mosaicImage;
  Size _imageNaturalSize = const Size(1080, 1920);

  late FaceMaskRegion _currentRegion;
  Offset _dragStartFocal = Offset.zero;
  late FaceMaskRegion _startRegion;

  @override
  void initState() {
    super.initState();
    _currentRegion = widget.initialRegion;
    if (widget.preloadedMosaicImage != null) {
      _mosaicImage = widget.preloadedMosaicImage;
      _imageNaturalSize = widget.preloadedNaturalSize ?? const Size(1080, 1920);
      _isLoading = false;
    } else {
      _loadImage();
    }
  }

  @override
  void dispose() {
    if (widget.preloadedMosaicImage == null) {
      _mosaicImage?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      Uint8List bytes;
      if (widget.imageBytes != null) {
        bytes = widget.imageBytes!;
      } else {
        final file = File(widget.imagePath);
        if (!file.existsSync()) {
          setState(() => _isLoading = false);
          return;
        }
        bytes = file.readAsBytesSync();
      }

      // Decode a heavily downscaled ui.Image (45px width) for real-time GPU mosaic rendering
      final mosaicCodec = await ui.instantiateImageCodec(bytes, targetWidth: 45);
      final mosaicFrame = await mosaicCodec.getNextFrame();
      _mosaicImage = mosaicFrame.image;

      // Decode full image briefly to obtain natural orientation-baked dimensions
      final fullCodec = await ui.instantiateImageCodec(bytes);
      final fullFrame = await fullCodec.getNextFrame();
      _imageNaturalSize = Size(
        fullFrame.image.width.toDouble(),
        fullFrame.image.height.toDouble(),
      );
      fullFrame.image.dispose();
    } catch (e) {
      debugPrint('Error preparing face adjustment image: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetToAutoDetected() {
    setState(() {
      _currentRegion = widget.autoDetectedRegion;
    });
  }

  void _applyAndClose() {
    Navigator.of(context).pop(_currentRegion);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings(ConfigService.instance.config.language);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(
          widget.angleLabel.isNotEmpty
              ? '${widget.angleLabel} - ${strings.adjustFaceBlur}'
              : strings.adjustFaceBlur,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(strings.resetPosition),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: _resetToAutoDetected,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(strings.apply),
              onPressed: _applyAndClose,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    strings.loadingPhoto,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Photo interactive canvas
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final fitted = applyBoxFit(
                          BoxFit.contain,
                          _imageNaturalSize,
                          availableSize,
                        );
                        final renderSize = fitted.destination;

                        final centerOnScreen = Offset(
                          _currentRegion.x * renderSize.width,
                          _currentRegion.y * renderSize.height,
                        );
                        final radiusOnScreen = _currentRegion.radius * renderSize.width;

                        return Center(
                          child: SizedBox(
                            width: renderSize.width,
                            height: renderSize.height,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Layer 0: Original Photo
                                widget.imageBytes != null
                                    ? Image.memory(
                                        widget.imageBytes!,
                                        width: renderSize.width,
                                        height: renderSize.height,
                                        fit: BoxFit.fill,
                                      )
                                    : Image.file(
                                        File(widget.imagePath),
                                        width: renderSize.width,
                                        height: renderSize.height,
                                        fit: BoxFit.fill,
                                      ),

                                // Layer 1: Real-time interactive Mosaic blur circle
                                if (_mosaicImage != null)
                                  CustomPaint(
                                    size: renderSize,
                                    painter: MosaicCirclePainter(
                                      mosaicImage: _mosaicImage!,
                                      center: centerOnScreen,
                                      radius: radiusOnScreen,
                                      primaryColor: colorScheme.primary,
                                    ),
                                  ),

                                // Layer 2: Gesture listener for drag, pinch, and tap
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (details) {
                                    _dragStartFocal = details.localFocalPoint;
                                    _startRegion = _currentRegion;
                                  },
                                  onScaleUpdate: (details) {
                                    if (details.pointerCount > 1) {
                                      // Pinch to zoom radius
                                      final newRadius = (_startRegion.radius * details.scale)
                                          .clamp(0.04, 0.40);
                                      setState(() {
                                        _currentRegion = _currentRegion.copyWith(radius: newRadius);
                                      });
                                    } else {
                                      // 1-finger drag
                                      final delta = details.localFocalPoint - _dragStartFocal;
                                      final newX = (_startRegion.x + delta.dx / renderSize.width)
                                          .clamp(0.0, 1.0);
                                      final newY = (_startRegion.y + delta.dy / renderSize.height)
                                          .clamp(0.0, 1.0);
                                      setState(() {
                                        _currentRegion = _currentRegion.copyWith(x: newX, y: newY);
                                      });
                                    }
                                  },
                                  onTapDown: (details) {
                                    final tapPos = details.localPosition;
                                    final newX = (tapPos.dx / renderSize.width).clamp(0.0, 1.0);
                                    final newY = (tapPos.dy / renderSize.height).clamp(0.0, 1.0);
                                    setState(() {
                                      _currentRegion = _currentRegion.copyWith(x: newX, y: newY);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom controls bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Hint text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                strings.adjustFaceBlurHint,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Radius slider
                        Row(
                          children: [
                            const Icon(
                              Icons.circle_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.circleSize,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _currentRegion.radius,
                                min: 0.05,
                                max: 0.35,
                                activeColor: colorScheme.primary,
                                inactiveColor: Colors.white24,
                                onChanged: (val) {
                                  setState(() {
                                    _currentRegion = _currentRegion.copyWith(radius: val);
                                  });
                                },
                              ),
                            ),
                            const Icon(
                              Icons.circle_outlined,
                              size: 28,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Bottom action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.restart_alt, size: 18),
                                label: Text(strings.resetPosition),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _resetToAutoDetected,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(strings.apply),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _applyAndClose,
                              ),
                            ),
                          ],
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

/// Custom painter that paints the downsampled mosaic image strictly inside
/// a circular clipping path centered at [center] with radius [radius],
/// followed by an interactive circle outline and guide reticle.
class MosaicCirclePainter extends CustomPainter {
  final ui.Image mosaicImage;
  final Offset center;
  final double radius;
  final Color primaryColor;

  MosaicCirclePainter({
    required this.mosaicImage,
    required this.center,
    required this.radius,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Clip canvas to the circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // 2. Draw downscaled mosaic image stretched to the canvas bounds with nearest-neighbor interpolation
    final srcRect = Rect.fromLTWH(
      0,
      0,
      mosaicImage.width.toDouble(),
      mosaicImage.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final mosaicPaint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(mosaicImage, srcRect, dstRect, mosaicPaint);

    canvas.restore();

    // 3. Draw circle outline with high-contrast shadow for visibility on any background
    final shadowPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, shadowPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);

    final innerAccentPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 1.5, innerAccentPaint);

    // 4. Draw 4 directional handle markers on perimeter (at 0, 90, 180, 270 degrees)
    final handleShadowPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;
    final handleFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleCorePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final hx = center.dx + radius * math.cos(angle);
      final hy = center.dy + radius * math.sin(angle);
      final pos = Offset(hx, hy);

      canvas.drawCircle(pos, 5.0, handleShadowPaint);
      canvas.drawCircle(pos, 4.0, handleFillPaint);
      canvas.drawCircle(pos, 2.5, handleCorePaint);
    }

    // 5. Draw center reticle dot
    canvas.drawCircle(center, 4.0, Paint()..color = Colors.black54);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant MosaicCirclePainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.mosaicImage != mosaicImage ||
        oldDelegate.primaryColor != primaryColor;
  }
}
