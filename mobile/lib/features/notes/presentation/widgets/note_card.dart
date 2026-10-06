import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onTogglePin;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onTogglePin,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} m yang lalu';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} j yang lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} h yang lalu';
    } else {
      return DateFormat('dd MMM yyyy').format(dt.toLocal());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note.title.trim().isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headingSmall(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    if (onTogglePin != null)
                      GestureDetector(
                        onTap: onTogglePin,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            note.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            size: 18,
                            color: note.isPinned
                                ? (isDark ? AppColors.emeraldAccent : AppColors.primary)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
                if (note.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  if (note.content.startsWith('enc:v1:'))
                    Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Terkunci (E2E) — Butuh Master Password',
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ).copyWith(fontStyle: FontStyle.italic, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      note.content.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      _formatDate(note.updatedAt),
                      style: AppTypography.bodySmall(
                        color: isDark
                            ? AppColors.darkTextSecondary.withAlpha(160)
                            : AppColors.lightTextSecondary.withAlpha(160),
                      ).copyWith(fontSize: 11),
                    ),
                    if (note.folder != null && note.folder!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.emeraldAccent.withAlpha(20)
                                : AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.emeraldAccent.withAlpha(50)
                                  : AppColors.primary.withAlpha(50),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 11,
                                color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  note.folder!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall(
                                    color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                                  ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: note.syncStatus == SyncStatus.synced
                            ? AppColors.success
                            : (note.syncStatus == SyncStatus.error
                                ? AppColors.errorRed
                                : AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
