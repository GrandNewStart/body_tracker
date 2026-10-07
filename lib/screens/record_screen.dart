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
  final List<BodyRecord>? allRecords;

  const RecordScreen({
    super.key,
    required this.record,
    this.allRecords,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with SingleTickerProviderStateMixin {
  late List<BodyRecord> _records;
  late int _currentIndex;
  late PageController _pageController;
  late TabController _tabController;
  bool _isPhotoZoomed = false;

  BodyRecord get _currentRecord =>
      _records.isNotEmpty ? _records[_currentIndex.clamp(0, _records.length - 1)] : widget.record;

  @override
  void initState() {
    super.initState();
    _initRecords();
    _tabController = TabController(length: 4, vsync: this);
    StorageService.instance.recordsNotifier.addListener(_onRecordsNotifierChanged);
  }

  void _initRecords() {
    final available = widget.allRecords ?? StorageService.instance.records;
    if (available.isNotEmpty) {
      _records = List<BodyRecord>.from(available);
      final idx = _records.indexWhere((r) => r.id == widget.record.id);
      if (idx != -1) {
        _currentIndex = idx;
      } else {
        _records.insert(0, widget.record);
        _currentIndex = 0;
      }
    } else {
      _records = [widget.record];
      _currentIndex = 0;
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _onRecordsNotifierChanged() {
    if (!mounted || widget.allRecords != null) return;
    final stored = StorageService.instance.records;
    if (stored.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      final currentId = _currentRecord.id;
      _records = List<BodyRecord>.from(stored);
      final newIdx = _records.indexWhere((r) => r.id == currentId);
      if (newIdx != -1) {
        _currentIndex = newIdx;
      } else {
        _currentIndex = _currentIndex.clamp(0, _records.length - 1);
      }
    });
  }

  @override
  void dispose() {
    StorageService.instance.recordsNotifier.removeListener(_onRecordsNotifierChanged);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final targetRecord = _currentRecord;

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
      await StorageService.instance.deleteRecord(targetRecord.id);
      if (!mounted) return;
      setState(() {
        _records.removeWhere((r) => r.id == targetRecord.id);
        if (_records.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        if (_currentIndex >= _records.length) {
          _currentIndex = _records.length - 1;
        }
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  Future<void> _handleEnableFaceBlur() async {
    final strings = AppStrings(ConfigService.instance.config.language);
    final targetRecord = _currentRecord;

    final updatedRecord = await Navigator.of(context).push<BodyRecord>(
      MaterialPageRoute(
        builder: (context) => RecordBlurScreen(
          record: targetRecord,
          initialAngleIndex: _tabController.index,
        ),
      ),
    );

    if (updatedRecord != null && mounted) {
      setState(() {
        final idx = _records.indexWhere((r) => r.id == updatedRecord.id);
        if (idx != -1) {
          _records[idx] = updatedRecord;
        }
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

    final tabs = [
      strings.angleFront,
      strings.angleLeft,
      strings.angleBack,
      strings.angleRight,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.recordDetailTitle),
        actions: [
          if (!_currentRecord.isMasked)
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
      floatingActionButton: !_currentRecord.isMasked
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.blur_on),
              label: Text(strings.enableFaceBlur),
              onPressed: _handleEnableFaceBlur,
            )
          : null,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: _isPhotoZoomed
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: _records.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final record = _records[index];
          return _buildRecordPage(record, index, strings, theme);
        },
      ),
    );
  }

  Widget _buildRecordPage(
    BodyRecord record,
    int pageIndex,
    AppStrings strings,
    ThemeData theme,
  ) {
    String dateStr;
    try {
      dateStr = DateFormat.yMMMMd(strings.isKorean ? 'ko_KR' : 'en_US')
          .add_jm()
          .format(record.date);
    } catch (_) {
      final d = record.date;
      final timeStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      dateStr = strings.isKorean
          ? '${d.year}년 ${d.month}월 ${d.day}일 $timeStr'
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $timeStr';
    }

    final imagePaths = [
      StorageService.instance.resolveImagePath(record.frontImagePath),
      StorageService.instance.resolveImagePath(record.leftImagePath),
      StorageService.instance.resolveImagePath(record.backImagePath),
      StorageService.instance.resolveImagePath(record.rightImagePath),
    ];

    return Column(
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
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_records.length > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${pageIndex + 1}/${_records.length})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${record.weight.toStringAsFixed(1)} kg',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (record.isMasked) ...[
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
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TabBarView(
                  controller: _tabController,
                  children: imagePaths.map((path) {
                    final file = File(path);
                    return Center(
                      child: file.existsSync()
                          ? InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              onInteractionUpdate: (details) {
                                if (details.scale > 1.05 != _isPhotoZoomed) {
                                  setState(() => _isPhotoZoomed = details.scale > 1.05);
                                }
                              },
                              onInteractionEnd: (_) {
                                if (_isPhotoZoomed) {
                                  setState(() => _isPhotoZoomed = false);
                                }
                              },
                              child: Image.file(
                                file,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(
                                    strings.isKorean ? '이미지를 불러올 수 없습니다' : 'Failed to load image',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                strings.isKorean ? '파일을 찾을 수 없습니다' : 'File not found',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
