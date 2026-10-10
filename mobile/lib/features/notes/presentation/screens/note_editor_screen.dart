import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/note_editor_controller.dart';
import '../controllers/notes_list_controller.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;

  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Isi text field SEKALI, setelah catatan selesai dimuat (bukan dari note
  /// kosong awal — kalau tidak, editor tampil kosong dan ketikan pertama
  /// menimpa isi catatan asli).
  void _syncControllersWithState(NoteEditorState state) {
    if (!_isInitialized && !state.isLoading) {
      _titleController.text = state.note.title;
      _contentController.text = state.note.content;
      _isInitialized = true;
    }
  }

  Future<void> _handleBack() async {
    final controller = ref.read(noteEditorControllerProvider(widget.noteId).notifier);
    await controller.saveImmediately();
    ref.read(notesListControllerProvider.notifier).loadNotes();
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'Hapus Catatan?',
          style: AppTypography.headingSmall(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Catatan ini akan dipindahkan ke tempat sampah dan dihapus dari semua perangkat tersinkron.',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(noteEditorControllerProvider(widget.noteId).notifier).deleteNote();
      ref.read(notesListControllerProvider.notifier).loadNotes();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteEditorControllerProvider(widget.noteId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _syncControllersWithState(state);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali & Simpan',
            onPressed: _handleBack,
          ),
          title: Text(
            state.isSaving
                ? 'Menyimpan...'
                : (state.isDirty ? 'Draf Lokal' : 'Tersimpan'),
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                state.note.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                color: state.note.isPinned
                    ? (isDark ? AppColors.emeraldAccent : AppColors.primary)
                    : null,
              ),
              tooltip: state.note.isPinned ? 'Lepas Sematan' : 'Sematkan Catatan',
              onPressed: () {
                ref.read(noteEditorControllerProvider(widget.noteId).notifier).togglePin();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
              tooltip: 'Hapus Catatan',
              onPressed: _confirmDelete,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (state.isEncryptedLocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Catatan terenkripsi — buka E2E (master password) untuk membaca & mengedit.',
                      style: AppTypography.bodySmall(color: AppColors.errorRed),
                    ),
                  ),
                _buildFolderSelector(context, ref, state.note.folder, isDark),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  readOnly: state.isLoading || state.isEncryptedLocked,
                  autofocus: !state.isLoading && state.note.title.isEmpty,
                  style: AppTypography.headingLarge(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Judul catatan...',
                    hintStyle: AppTypography.headingLarge(
                      color: isDark
                          ? AppColors.darkTextSecondary.withAlpha(100)
                          : AppColors.lightTextSecondary.withAlpha(100),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    ref.read(noteEditorControllerProvider(widget.noteId).notifier).updateTitle(val);
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    readOnly: state.isLoading || state.isEncryptedLocked,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTypography.bodyLarge(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ).copyWith(height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Ketik isi catatan di sini...',
                      hintStyle: AppTypography.bodyLarge(
                        color: isDark
                            ? AppColors.darkTextSecondary.withAlpha(100)
                            : AppColors.lightTextSecondary.withAlpha(100),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      ref.read(noteEditorControllerProvider(widget.noteId).notifier).updateContent(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderSelector(
    BuildContext context,
    WidgetRef ref,
    String? currentFolder,
    bool isDark,
  ) {
    final hasFolder = currentFolder != null && currentFolder.trim().isNotEmpty;
    final label = hasFolder ? currentFolder : 'Pilih Folder';

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showFolderPickerBottomSheet(context, ref, isDark, currentFolder),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFolder
                ? (isDark
                    ? AppColors.emeraldAccent.withAlpha(80)
                    : AppColors.primary.withAlpha(80))
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFolder ? Icons.folder_rounded : Icons.folder_open_rounded,
              size: 14,
              color: hasFolder
                  ? (isDark ? AppColors.emeraldAccent : AppColors.primary)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelMedium(
                color: hasFolder
                    ? (isDark ? AppColors.emeraldAccent : AppColors.primary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                fontWeight: hasFolder ? FontWeight.w600 : FontWeight.normal,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderPickerBottomSheet(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    String? currentFolder,
  ) {
    final notesListState = ref.read(notesListControllerProvider);
    final available = notesListState.availableFolders;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Folder',
                      style: AppTypography.headingSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Option: Tanpa Folder
                    ListTile(
                      leading: Icon(
                        Icons.folder_off_outlined,
                        color: currentFolder == null
                            ? (isDark ? AppColors.emeraldAccent : AppColors.primary)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      title: Text(
                        'Tanpa Folder',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: currentFolder == null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: currentFolder == null
                          ? Icon(
                              Icons.check_rounded,
                              color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                            )
                          : null,
                      onTap: () {
                        ref.read(noteEditorControllerProvider(widget.noteId).notifier).updateFolder(null);
                        Navigator.pop(ctx);
                      },
                    ),

                    // Available Folders
                    ...available.map((f) {
                      final isSelected = currentFolder == f;
                      return ListTile(
                        leading: Icon(
                          Icons.folder_outlined,
                          color: isSelected
                              ? (isDark ? AppColors.emeraldAccent : AppColors.primary)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        title: Text(
                          f,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          ref.read(noteEditorControllerProvider(widget.noteId).notifier).updateFolder(f);
                          Navigator.pop(ctx);
                        },
                      );
                    }),

                    const Divider(height: 1),

                    // Add new folder button
                    ListTile(
                      leading: Icon(
                        Icons.add_rounded,
                        color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                      ),
                      title: Text(
                        'Buat Folder Baru...',
                        style: TextStyle(
                          color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreateFolderAndAssignDialog(context, ref, isDark);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFolderAndAssignDialog(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'Buat Folder Baru',
          style: AppTypography.headingSmall(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nama folder...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.emeraldAccent : AppColors.primary,
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                ref.read(notesListControllerProvider.notifier).createFolder(text);
                ref.read(noteEditorControllerProvider(widget.noteId).notifier).updateFolder(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Buat & Pilih'),
          ),
        ],
      ),
    );
  }
}
