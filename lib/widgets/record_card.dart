import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/body_record.dart';
import '../services/storage_service.dart';

class RecordCard extends StatelessWidget {
  final BodyRecord record;
  final bool isKorean;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RecordCard({
    super.key,
    required this.record,
    required this.isKorean,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String dateStr;
    try {
      dateStr = DateFormat.yMMMMd(isKorean ? 'ko_KR' : 'en_US').format(record.date);
    } catch (_) {
      dateStr = isKorean
          ? '${record.date.year}년 ${record.date.month}월 ${record.date.day}일'
          : '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Date, Weight & Delete button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.monitor_weight_outlined,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${record.weight.toStringAsFixed(1)} kg',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (record.isMasked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isKorean ? '얼굴 가림' : 'Masked',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error.withValues(alpha: 0.8),
                    ),
                    onPressed: onDelete,
                    tooltip: isKorean ? '삭제' : 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4 photo thumbnails: Front, Left, Back, Right
              Row(
                children: [
                  Expanded(
                    child: _buildThumbnail(
                      context,
                      record.frontImagePath,
                      isKorean ? '정면' : 'Front',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThumbnail(
                      context,
                      record.leftImagePath,
                      isKorean ? '좌측' : 'Left',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThumbnail(
                      context,
                      record.backImagePath,
                      isKorean ? '후면' : 'Back',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThumbnail(
                      context,
                      record.rightImagePath,
                      isKorean ? '우측' : 'Right',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, String path, String label) {
    final theme = Theme.of(context);
    final resolvedPath = StorageService.instance.resolveImagePath(path);
    final file = File(resolvedPath);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 20),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 20),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
