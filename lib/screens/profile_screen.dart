import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/body_angle.dart';
import '../models/body_record.dart';
import '../models/video_render_settings.dart';
import '../services/config_service.dart';
import '../services/storage_service.dart';
import '../services/video_service.dart';
import '../widgets/record_card.dart';
import 'capture_screen.dart';
import 'record_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRenderingVideo = false;
  double _renderProgress = 0.0;
  int _currentSlideIndex = 0;
  int _totalSlideCount = 0;

  void _navigateToCapture() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  void _navigateToRecord(BodyRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordScreen(record: record)),
    );
  }

  Future<void> _confirmDeleteRecord(BodyRecord record) async {
    final strings = AppStrings(ConfigService.instance.config.language);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteRecordTitle),
        content: Text(strings.deleteRecordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.deleteRecord(record.id);
    }
  }

  Future<void> _showRenderVideoDialog() async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final records = StorageService.instance.records;

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noRecordsToRender)),
      );
      return;
    }

    final selectedAngles = <BodyAngle>{
      BodyAngle.front,
      BodyAngle.left,
      BodyAngle.back,
      BodyAngle.right,
    };
    double slideInterval = 1.0;
    final intervalController = TextEditingController(text: '1.0');

    final settings = await showDialog<VideoRenderSettings>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalSlides = records.length * selectedAngles.length;
            final estimatedDuration = (totalSlides * slideInterval).toStringAsFixed(1);

            return AlertDialog(
              title: Text(strings.renderVideoDialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.slideIntervalPrompt),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: slideInterval,
                            min: 0.2,
                            max: 4.0,
                            divisions: 38,
                            label: '${slideInterval.toStringAsFixed(1)}s',
                            onChanged: (val) {
                              setDialogState(() {
                                slideInterval = double.parse(val.toStringAsFixed(1));
                                intervalController.text = slideInterval.toString();
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: intervalController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: 's',
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val);
                              if (parsed != null && parsed >= 0.1 && parsed <= 10.0) {
                                setDialogState(() {
                                  slideInterval = parsed;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.selectProfilesPrompt,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: BodyAngle.values.map((angle) {
                        final isSelected = selectedAngles.contains(angle);
                        return FilterChip(
                          label: Text(angle.label(strings.isKorean)),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedAngles.add(angle);
                              } else {
                                selectedAngles.remove(angle);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (selectedAngles.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        strings.selectAtLeastOneProfile,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.isKorean
                                ? '총 슬라이드: $totalSlides장 (기록 ${records.length}일 × ${selectedAngles.length}개 각도)'
                                : 'Total Slides: $totalSlides (${records.length} days × ${selectedAngles.length} profiles)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.isKorean
                                ? '예상 영상 길이: 약 $estimatedDuration초'
                                : 'Estimated Length: ~$estimatedDuration seconds',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(strings.cancel),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: Text(strings.renderVideo),
                  onPressed: selectedAngles.isNotEmpty
                      ? () => Navigator.of(ctx).pop(
                            VideoRenderSettings(
                              slideInterval: slideInterval,
                              selectedAngles: Set<BodyAngle>.from(selectedAngles),
                            ),
                          )
                      : null,
                ),
              ],
            );
          },
        );
      },
    );

    if (settings != null) {
      _startVideoRendering(
        slideInterval: settings.slideInterval,
        selectedAngles: settings.selectedAngles,
      );
    }
  }

  Future<void> _startVideoRendering({
    required double slideInterval,
    required Set<BodyAngle> selectedAngles,
  }) async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final records = StorageService.instance.records;

    setState(() {
      _isRenderingVideo = true;
      _renderProgress = 0.0;
      _currentSlideIndex = 0;
      _totalSlideCount = records.length * selectedAngles.length;
    });

    final videoPath = await VideoService.instance.renderSlideshowVideo(
      records: records,
      slideIntervalSeconds: slideInterval,
      selectedAngles: selectedAngles,
      isKorean: strings.isKorean,
      theme: ConfigService.instance.config.theme,
      onProgress: (current, total, progress) {
        if (mounted) {
          setState(() {
            _currentSlideIndex = current;
            _totalSlideCount = total;
            _renderProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isRenderingVideo = false;
      });

      if (videoPath != null) {
        // Export via share sheet
        await VideoService.instance.exportVideo(videoPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.isKorean ? '영상 렌더링에 실패했습니다.' : 'Failed to render video.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ConfigService.instance.config;
    final strings = AppStrings(config.language);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        elevation: 0,
      ),
      body: ValueListenableBuilder<List<BodyRecord>>(
        valueListenable: StorageService.instance.recordsNotifier,
        builder: (context, records, child) {
          final hasRecordedToday = StorageService.instance.hasRecordedToday();

          if (records.isEmpty) {
            return _buildEmptyState(strings);
          }

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(bottom: 96, top: 8),
                itemCount: records.length + (hasRecordedToday ? 0 : 1),
                itemBuilder: (context, index) {
                  // If not recorded today, show 'Record Today' button on top of list
                  if (!hasRecordedToday && index == 0) {
                    return _buildRecordTodayBanner(strings);
                  }

                  final recordIndex = hasRecordedToday ? index : index - 1;
                  final record = records[recordIndex];

                  return RecordCard(
                    record: record,
                    isKorean: strings.isKorean,
                    onTap: () => _navigateToRecord(record),
                    onDelete: () => _confirmDeleteRecord(record),
                  );
                },
              ),

              // Rendering overlay indicator
              if (_isRenderingVideo)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            Text(
                              strings.renderingVideo,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: _renderProgress),
                            const SizedBox(height: 8),
                            Text(
                              '$_currentSlideIndex / $_totalSlideCount',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      // Floating 'Render Video' button at bottom center of the screen
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ValueListenableBuilder<List<BodyRecord>>(
        valueListenable: StorageService.instance.recordsNotifier,
        builder: (context, records, _) {
          if (records.isEmpty) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _isRenderingVideo ? null : _showRenderVideoDialog,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(
              strings.renderVideo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordTodayBanner(AppStrings strings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt,
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.recordToday,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.isKorean
                      ? '오늘의 전신 사진과 몸무게를 기록하세요'
                      : 'Take today\'s 4 body photos and weight',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _navigateToCapture,
            child: Text(strings.shoot),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppStrings strings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.accessibility_new_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              strings.emptyRecordsTitle, // 'Start Recording Your Body!'
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              strings.emptyRecordsSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _navigateToCapture,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                strings.recordToday,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
