import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/body_record.dart';
import '../services/storage_service.dart';
import '../services/config_service.dart';
import '../l10n/app_strings.dart';
import 'record_blur_screen.dart';

class RecordScreen extends StatefulWidget {
  final BodyRecord record;

  const RecordScreen({
    super.key,
    required this.record,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with SingleTickerProviderStateMixin {
  late BodyRecord _record;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
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

    if (confirmed == true && mounted) {
      await StorageService.instance.deleteRecord(_record.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleEnableFaceBlur() async {
    final strings = AppStrings(ConfigService.instance.config.language);

    // Directly open facial blur review & adjustment screen where automatic blur is performed first
    final updatedRecord = await Navigator.of(context).push<BodyRecord>(
      MaterialPageRoute(
        builder: (context) => RecordBlurScreen(
          record: _record,
          initialAngleIndex: _tabController.index,
        ),
      ),
    );

    if (updatedRecord != null && mounted) {
      setState(() {
        _record = updatedRecord;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.faceBlurAppliedSuccess),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings(ConfigService.instance.config.language);
    String dateStr;
    try {
      dateStr = DateFormat.yMMMMd(strings.isKorean ? 'ko_KR' : 'en_US')
          .add_jm()
          .format(_record.date);
    } catch (_) {
      final d = _record.date;
      final timeStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      dateStr = strings.isKorean
          ? '${d.year}년 ${d.month}월 ${d.day}일 $timeStr'
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $timeStr';
    }

    final tabs = [
      strings.angleFront,
      strings.angleLeft,
      strings.angleBack,
      strings.angleRight,
    ];

    final imagePaths = [
      StorageService.instance.resolveImagePath(_record.frontImagePath),
      StorageService.instance.resolveImagePath(_record.leftImagePath),
      StorageService.instance.resolveImagePath(_record.backImagePath),
      StorageService.instance.resolveImagePath(_record.rightImagePath),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.recordDetailTitle),
        actions: [
          if (!_record.isMasked)
            IconButton(
              icon: const Icon(Icons.blur_on),
              tooltip: strings.enableFaceBlur,
              onPressed: _handleEnableFaceBlur,
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: strings.delete,
            onPressed: () => _confirmDelete(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((label) => Tab(text: label)).toList(),
        ),
      ),
      floatingActionButton: !_record.isMasked
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.blur_on),
              label: Text(strings.enableFaceBlur),
              onPressed: _handleEnableFaceBlur,
            )
          : null,
      body: Column(
        children: [
                // Weight & Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${_record.weight.toStringAsFixed(1)} kg',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (_record.isMasked) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    strings.isKorean ? '얼굴 가림' : 'Masked',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ] else ...[
                                const SizedBox(width: 8),
                                ActionChip(
                                  avatar: Icon(
                                    Icons.blur_on,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  label: Text(
                                    strings.enableFaceBlur,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  onPressed: _handleEnableFaceBlur,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      Icon(
                        Icons.lock_clock,
                        color: theme.colorScheme.outline,
                        size: 22,
                      ),
                    ],
                  ),
                ),

          // Photo Viewer
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: imagePaths.map((path) {
                final file = File(path);
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: file.existsSync()
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.file(
                              file,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  strings.isKorean ? '이미지를 불러올 수 없습니다' : 'Failed to load image',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              strings.isKorean ? '파일을 찾을 수 없습니다' : 'File not found',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
