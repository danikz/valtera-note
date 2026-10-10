import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../../core/widgets/valtera_text_field.dart';
import '../../../sync/domain/sync_engine.dart';
import '../controllers/notes_list_controller.dart';
import '../widgets/note_card.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notesListControllerProvider);
    final isOnlineAsync = ref.watch(isOnlineStreamProvider);
    final syncStatusAsync = ref.watch(syncStatusStreamProvider);
    final e2eState = ref.watch(e2eControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOnline = isOnlineAsync.value ?? true;
    final syncInfo = syncStatusAsync.value ?? const SyncStatusInfo();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: isDark ? AppColors.emeraldAccent : AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Valtera Note',
              style: AppTypography.headingMedium(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
            onPressed: () {
              ref.read(themeControllerProvider.notifier).toggleTheme(isDark);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Cari Catatan',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan & Akun',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline) const OfflineBanner(),
          if (e2eState.isLocked) _buildE2eLockedBanner(context, ref, isDark),
          _buildFolderFilterBar(context, ref, state, isDark),
          if (syncInfo.state == SyncEngineState.syncing)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: isDark ? AppColors.emeraldAccent : AppColors.primary,
            ),
          Expanded(
            child: RefreshIndicator(
              color: isDark ? AppColors.emeraldAccent : AppColors.primary,
              onRefresh: () async {
                await ref.read(notesListControllerProvider.notifier).refresh();
              },
              child: _buildBody(context, ref, state, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppColors.emeraldAccent : AppColors.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Catatan Baru',
        onPressed: () => context.push('/notes/new'),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotesListState state,
    bool isDark,
  ) {
    if (state.isLoading && state.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 48),
              const SizedBox(height: 12),
              Text(
                'Terjadi Kesalahan',
                style: AppTypography.headingSmall(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    ref.read(notesListControllerProvider.notifier).loadNotes(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notes.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.note_add_outlined,
                  size: 36,
                  color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Catatan',
                style: AppTypography.headingSmall(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ketuk tombol di bawah untuk membuat catatan pertamamu.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pinned = state.pinnedFilteredNotes;
    final others = state.otherFilteredNotes;

    if (pinned.isEmpty && others.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 32,
                  color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Folder ${state.selectedFolder ?? ''} Kosong',
                style: AppTypography.headingSmall(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Belum ada catatan yang tersimpan di folder ini.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/notes/new');
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Tulis Catatan di ${state.selectedFolder ?? 'Folder Ini'}'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin_rounded,
                  size: 14,
                  color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'DISEMATKAN',
                  style: AppTypography.labelMedium(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 11, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
          ...pinned.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NoteCard(
                  note: n,
                  onTap: () => context.push('/notes/${n.id}'),
                  onTogglePin: () =>
                      ref.read(notesListControllerProvider.notifier).togglePin(n.id),
                ),
              )),
          const SizedBox(height: 12),
        ],
        if (others.isNotEmpty && pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CATATAN LAINNYA',
              style: AppTypography.labelMedium(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ).copyWith(fontSize: 11, letterSpacing: 0.8),
            ),
          ),
        ],
        ...others.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NoteCard(
                note: n,
                onTap: () => context.push('/notes/${n.id}'),
                onTogglePin: () =>
                    ref.read(notesListControllerProvider.notifier).togglePin(n.id),
              ),
            )),
        const SizedBox(height: 80), // Clearance for FAB
      ],
    );
  }

  Widget _buildE2eLockedBanner(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.emeraldAccent.withAlpha(100) : const Color(0xFF86EFAC),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.emeraldAccent.withAlpha(40) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: isDark ? AppColors.emeraldAccent : const Color(0xFF16A34A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catatan Terenkripsi E2E',
                  style: AppTypography.labelMedium(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Masukkan Master Password untuk membaca isi catatan.',
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.emeraldAccent : AppColors.primary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showUnlockDialog(context, ref),
            child: const Text('Buka Kunci', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderFilterBar(
    BuildContext context,
    WidgetRef ref,
    NotesListState state,
    bool isDark,
  ) {
    final available = state.availableFolders;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildFilterChip(
              context: context,
              label: 'Semua',
              count: state.notes.length,
              isSelected: state.selectedFolder == null,
              isDark: isDark,
              onTap: () {
                ref.read(notesListControllerProvider.notifier).selectFolder(null);
              },
            ),
            const SizedBox(width: 8),
            ...available.map((folder) {
              final isSelected = state.selectedFolder == folder;
              final count = state.countForFolder(folder);
              final isCustom = state.customFolders.contains(folder);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  context: context,
                  label: folder,
                  icon: Icons.folder_outlined,
                  count: count,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () {
                    ref.read(notesListControllerProvider.notifier).selectFolder(folder);
                  },
                  onLongPress: isCustom
                      ? () => _showFolderOptionsDialog(context, ref, folder, isDark)
                      : null,
                ),
              );
            }),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showNewFolderDialog(context, ref, isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Folder',
                      style: AppTypography.labelMedium(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    IconData? icon,
    required int count,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final activeBg = isDark ? AppColors.emeraldAccent : AppColors.primary;
    final activeFg = isDark ? Colors.black : Colors.white;

    final inactiveBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final inactiveBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inactiveFg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeBg : inactiveBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? activeFg
                      : (isDark ? AppColors.emeraldAccent : AppColors.primary),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTypography.labelMedium(
                  color: isSelected ? activeFg : inactiveFg,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ).copyWith(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.black.withAlpha(50) : Colors.white.withAlpha(60))
                      : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? activeFg
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewFolderDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'Folder Baru',
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
              }
              Navigator.pop(ctx);
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  void _showFolderOptionsDialog(
    BuildContext context,
    WidgetRef ref,
    String folderName,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Ubah Nama Folder "$folderName"'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameFolderDialog(context, ref, folderName, isDark);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                title: Text(
                  'Hapus Folder "$folderName"',
                  style: const TextStyle(color: AppColors.errorRed),
                ),
                subtitle: const Text('Catatan di dalam folder ini tidak akan terhapus.'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(notesListControllerProvider.notifier).deleteFolder(folderName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    String oldName,
    bool isDark,
  ) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'Ubah Nama Folder',
          style: AppTypography.headingSmall(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nama folder baru...',
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
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                ref.read(notesListControllerProvider.notifier).renameFolder(oldName, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showUnlockDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _UnlockMasterPasswordDialog(),
    );
  }
}

class _UnlockMasterPasswordDialog extends ConsumerStatefulWidget {
  const _UnlockMasterPasswordDialog();

  @override
  ConsumerState<_UnlockMasterPasswordDialog> createState() =>
      _UnlockMasterPasswordDialogState();
}

class _UnlockMasterPasswordDialogState
    extends ConsumerState<_UnlockMasterPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberDevice = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.lock_rounded,
            color: isDark ? AppColors.emeraldAccent : AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            'Buka Kunci E2E',
            style: AppTypography.headingSmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masukkan Master Password yang Anda atur di aplikasi desktop untuk membuka dan mendekripsi catatan.',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorRed.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.bodySmall(color: AppColors.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            ValteraTextField(
              controller: _passwordController,
              label: 'Master Password',
              hintText: 'Minimal 8 karakter',
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _rememberDevice,
                  activeColor: isDark ? AppColors.emeraldAccent : AppColors.primary,
                  onChanged: (val) => setState(() => _rememberDevice = val ?? true),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _rememberDevice = !_rememberDevice),
                    child: Text(
                      'Ingat di perangkat ini',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.emeraldAccent : AppColors.primary,
            foregroundColor: isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  // Ambil navigator sebelum await — context dialog tidak aman
                  // dipakai setelah async gap.
                  final navigator = Navigator.of(context);
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });

                  final ok = await ref.read(e2eControllerProvider.notifier).unlock(
                        _passwordController.text,
                        rememberDevice: _rememberDevice,
                      );

                  if (mounted) {
                    setState(() => _isLoading = false);
                    if (ok) {
                      navigator.pop();
                    } else {
                      final err = ref.read(e2eControllerProvider).errorMessage;
                      setState(() => _error = err ?? 'Password salah');
                    }
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buka Kunci', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
