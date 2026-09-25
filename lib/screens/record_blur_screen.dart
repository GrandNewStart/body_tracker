import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/body_record.dart';
import '../models/face_mask_region.dart';
import '../services/config_service.dart';
import '../services/ml_service.dart';
import '../services/storage_service.dart';
import 'face_adjustment_screen.dart';

/// Screen allowing the user to review and adjust facial blur for a stored record
/// before permanently applying it to the stored photo files.
class RecordBlurScreen extends StatefulWidget {
  final BodyRecord record;
  final int initialAngleIndex;

  const RecordBlurScreen({
    super.key,
    required this.record,
    this.initialAngleIndex = 0,
  });

  @override
  State<RecordBlurScreen> createState() => _RecordBlurScreenState();
}

class _RecordBlurScreenState extends State<RecordBlurScreen> {
  bool _isProcessing = true;
  bool _isApplying = false;

  final List<String> _imagePaths = [];
  final List<FaceMaskRegion> _regions = [];
  final List<FaceMaskRegion> _autoDetectedRegions = [];
  final List<String> _previewPaths = [];

  @override
  void initState() {
    super.initState();
    _preparePreviews();
  }

  @override
  void dispose() {
    _cleanTempPreviews();
    super.dispose();
  }

  void _cleanTempPreviews() {
    for (final p in _previewPaths) {
      try {
        final f = File(p);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }
  }

  Future<void> _preparePreviews() async {
    final storage = StorageService.instance;
    final ml = MlService.instance;
    final tempDir = Directory.systemTemp;

    final rawPaths = [
      widget.record.frontImagePath,
      widget.record.leftImagePath,
      widget.record.backImagePath,
      widget.record.rightImagePath,
    ];

    _imagePaths.clear();
    _regions.clear();
    _autoDetectedRegions.clear();
    _previewPaths.clear();

    for (int i = 0; i < rawPaths.length; i++) {
      final resolved = storage.resolveImagePath(rawPaths[i]);
      _imagePaths.add(resolved);

      if (File(resolved).existsSync()) {
        final region = await ml.detectFaceRegion(resolved);
        _regions.add(region);
        _autoDetectedRegions.add(region);

        final previewPath = '${tempDir.path}/preview_masked_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
        await ml.applyFaceMask(
          originalImagePath: resolved,
          maskedOutputPath: previewPath,
          region: region,
        );
        _previewPaths.add(previewPath);
      } else {
        _regions.add(FaceMaskRegion.defaultHead);
        _autoDetectedRegions.add(FaceMaskRegion.defaultHead);
        _previewPaths.add('');
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _adjustAngle(int index) async {
    if (index >= _imagePaths.length || !File(_imagePaths[index]).existsSync()) {
      return;
    }

    final strings = AppStrings(ConfigService.instance.config.language);
    final angleLabels = [
      strings.angleFront,
      strings.angleLeft,
      strings.angleBack,
      strings.angleRight,
    ];
    final label = index < angleLabels.length ? angleLabels[index] : '';

    final currentRegion = _regions[index];
    final autoRegion = _autoDetectedRegions[index];

    final newRegion = await Navigator.of(context).push<FaceMaskRegion>(
      MaterialPageRoute(
        builder: (context) => FaceAdjustmentScreen(
          imagePath: _imagePaths[index],
          angleLabel: label,
          initialRegion: currentRegion,
          autoDetectedRegion: autoRegion,
        ),
      ),
    );

    if (newRegion != null && mounted) {
      setState(() {
        _isProcessing = true;
      });

      final tempDir = Directory.systemTemp;
      final newPreviewPath = '${tempDir.path}/preview_masked_${DateTime.now().microsecondsSinceEpoch}_$index.jpg';

      await MlService.instance.applyFaceMask(
        originalImagePath: _imagePaths[index],
        maskedOutputPath: newPreviewPath,
        region: newRegion,
      );

      // Clean old preview file
      try {
        final oldFile = File(_previewPaths[index]);
        if (oldFile.existsSync()) oldFile.deleteSync();
      } catch (_) {}

      // Evict new preview from imageCache so Flutter displays it immediately
      PaintingBinding.instance.imageCache.evict(FileImage(File(newPreviewPath)));

      if (mounted) {
        setState(() {
          _regions[index] = newRegion;
          _previewPaths[index] = newPreviewPath;
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.faceBlurUpdated),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndApply() async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(strings.permanentBlurConfirmTitle)),
          ],
        ),
        content: Text(strings.permanentBlurConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.applyPermanent),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isApplying = true;
    });

    final tempDir = Directory.systemTemp;

    for (int i = 0; i < _imagePaths.length; i++) {
      final targetPath = _imagePaths[i];
      if (targetPath.isEmpty || !File(targetPath).existsSync()) continue;

      final tempMaskedPath = '${tempDir.path}/perm_masked_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
      await MlService.instance.applyFaceMask(
        originalImagePath: targetPath,
        maskedOutputPath: tempMaskedPath,
        region: _regions[i],
      );

      // Overwrite persistent photo file
      File(tempMaskedPath).copySync(targetPath);
      try {
        File(tempMaskedPath).deleteSync();
      } catch (_) {}

      // Evict from Flutter imageCache so updated photo displays immediately
      PaintingBinding.instance.imageCache.evict(FileImage(File(targetPath)));
    }

    final updatedRecord = widget.record.copyWith(isMasked: true);
    await StorageService.instance.updateRecord(updatedRecord);

    if (mounted) {
      Navigator.of(context).pop(updatedRecord);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings(ConfigService.instance.config.language);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.reviewFaceBlurTitle),
      ),
      body: _isProcessing || _isApplying
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isApplying
                        ? strings.applyingFaceBlur
                        : (strings.isKorean ? '얼굴 감지 및 블러 처리 중...' : 'Detecting faces and applying blur...'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.reviewFaceBlurWarningBanner,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hint banner to adjust face blur
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_rounded, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.tapToAdjustFaceBlur,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4 photo preview grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final path = (index < _previewPaths.length) ? _previewPaths[index] : '';
                      final label = [
                        strings.angleFront,
                        strings.angleLeft,
                        strings.angleBack,
                        strings.angleRight,
                      ][index];
                      final file = File(path);

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _adjustAngle(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outlineVariant),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: file.existsSync()
                                  ? Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      key: ValueKey('${path}_${file.lastModifiedSync().millisecondsSinceEpoch}'),
                                    )
                                  : const Center(child: Icon(Icons.image)),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      strings.adjustFaceBlurShort,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bottom Action Buttons: Cancel or Permanently Apply
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(strings.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.blur_on),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _confirmAndApply,
                          label: Text(
                            strings.applyPermanent,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
