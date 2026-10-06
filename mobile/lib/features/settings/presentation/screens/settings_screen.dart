import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/valtera_button.dart';
import '../../../../core/widgets/valtera_text_field.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../setup/data/repositories/setup_repository.dart';
import '../../../setup/presentation/controllers/setup_controller.dart';
import '../../../sync/domain/sync_engine.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _supabaseUrl;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final repo = ref.read(setupRepositoryProvider);
    final config = await repo.getConfig();
    if (mounted) {
      setState(() {
        _supabaseUrl = config.url;
      });
    }
  }

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final engine = ref.read(syncEngineProvider);
    await engine.syncAll();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi selesai')),
      );
    }
  }

  Future<void> _confirmDisconnect() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'Putuskan Koneksi Supabase?',
          style: AppTypography.headingSmall(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'Aplikasi akan beralih ke mode offline penuh. Kredensial URL dan Anon Key akan dihapus dari perangkat ini.',
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
            child: const Text('Putuskan', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(setupControllerProvider.notifier).disconnect();
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/setup');
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final syncInfoAsync = ref.watch(syncStatusStreamProvider);
    final e2eState = ref.watch(e2eControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final syncInfo = syncInfoAsync.value ?? const SyncStatusInfo();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: AppTypography.headingMedium(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Akun Pengguna
          Text(
            'AKUN SUPABASE',
            style: AppTypography.labelMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ).copyWith(letterSpacing: 0.8, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
                      child: Icon(
                        Icons.person_rounded,
                        color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.isLoggedIn
                                ? (authState.userEmail ?? 'Pengguna')
                                : 'Mode Anonim (Belum Login)',
                            style: AppTypography.headingSmall(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authState.isLoggedIn
                                ? 'Sesi aktif tersimpan di Android Keystore'
                                : 'Login untuk mengunci catatan dengan RLS',
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (authState.isLoggedIn) ...[
                  const SizedBox(height: 16),
                  ValteraButton(
                    text: 'Keluar dari Akun',
                    variant: ValteraButtonVariant.outline,
                    icon: Icons.logout_rounded,
                    onPressed: _handleLogout,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  ValteraButton(
                    text: 'Masuk / Daftar',
                    variant: ValteraButtonVariant.primary,
                    icon: Icons.login_rounded,
                    onPressed: () => context.push('/login'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Tampilan & Tema
          _buildThemeSection(isDark, themeMode),
          const SizedBox(height: 24),

          // Section: Keamanan & E2E
          _buildE2eSection(isDark, e2eState),
          const SizedBox(height: 24),

          // Section: Supabase Project
          Text(
            'SINKRONISASI CLOUD',
            style: AppTypography.labelMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ).copyWith(letterSpacing: 0.8, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dns_rounded, size: 18, color: isDark ? AppColors.emeraldAccent : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Project URL',
                      style: AppTypography.labelMedium(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _supabaseUrl ?? 'Belum terhubung',
                  style: AppTypography.codeFont(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terakhir disinkronkan:',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      syncInfo.lastSyncedAt != null
                          ? DateFormat('HH:mm:ss').format(syncInfo.lastSyncedAt!.toLocal())
                          : 'Belum pernah',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ValteraButton(
                        text: 'Sync Sekarang',
                        variant: ValteraButtonVariant.secondary,
                        isLoading: _isSyncing,
                        icon: Icons.sync_rounded,
                        onPressed: _handleSyncNow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ValteraButton(
                        text: 'Putuskan',
                        variant: ValteraButtonVariant.danger,
                        icon: Icons.link_off_rounded,
                        onPressed: _confirmDisconnect,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Tentang Aplikasi
          Center(
            child: Text(
              'Valtera Note Android • Versi 1.0.0 (MVP)\nPT Valtera Teknologi Digital',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(
                color: isDark
                    ? AppColors.darkTextSecondary.withAlpha(140)
                    : AppColors.lightTextSecondary.withAlpha(140),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(bool isDark, ThemeMode currentMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAMPILAN & TEMA',
          style: AppTypography.labelMedium(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(letterSpacing: 0.8, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 18,
                    color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mode Tema',
                    style: AppTypography.labelMedium(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih tema tampilan aplikasi yang Anda inginkan.',
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildThemeOption(
                      title: 'Terang',
                      icon: Icons.light_mode_outlined,
                      mode: ThemeMode.light,
                      isSelected: currentMode == ThemeMode.light,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      title: 'Gelap',
                      icon: Icons.dark_mode_outlined,
                      mode: ThemeMode.dark,
                      isSelected: currentMode == ThemeMode.dark,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildThemeOption(
                      title: 'Ikuti Sistem',
                      icon: Icons.settings_brightness_outlined,
                      mode: ThemeMode.system,
                      isSelected: currentMode == ThemeMode.system,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeColor = isDark ? AppColors.emeraldAccent : AppColors.primary;
    final inactiveBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bgColor = isSelected
        ? activeColor.withAlpha(isDark ? 35 : 25)
        : (isDark ? AppColors.darkSurfaceVariant.withAlpha(100) : AppColors.lightMuted.withAlpha(100));

    return InkWell(
      onTap: () {
        ref.read(themeControllerProvider.notifier).setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : inactiveBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildE2eSection(bool isDark, E2eState e2e) {
    final statusColor = e2e.isUnlocked
        ? (isDark ? AppColors.emeraldAccent : const Color(0xFF16A34A))
        : e2e.isLocked
            ? const Color(0xFFEAB308)
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    final statusText = e2e.isUnlocked
        ? 'Aktif & Terbuka'
        : e2e.isLocked
            ? 'Terkunci (Perlu Password)'
            : 'Belum Dikonfigurasi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KEAMANAN & E2E ENCRYPTION',
          style: AppTypography.labelMedium(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ).copyWith(letterSpacing: 0.8, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        e2e.isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 20,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'End-to-End Encryption',
                        style: AppTypography.labelMedium(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withAlpha(80)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Argon2id + XChaCha20-Poly1305. Konten catatan dienkripsi dengan Master Password Anda.',
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              if (e2e.isLocked) ...[
                ValteraButton(
                  text: 'Buka Kunci Master Password',
                  variant: ValteraButtonVariant.primary,
                  icon: Icons.key_rounded,
                  onPressed: () => _showUnlockDialog(context),
                ),
              ] else if (e2e.isUnlocked) ...[
                Row(
                  children: [
                    Expanded(
                      child: ValteraButton(
                        text: 'Kunci Sekarang',
                        variant: ValteraButtonVariant.secondary,
                        icon: Icons.lock_outline_rounded,
                        onPressed: () {
                          ref.read(e2eControllerProvider.notifier).lock();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Catatan dikunci')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValteraButton(
                        text: 'Lupakan Kunci',
                        variant: ValteraButtonVariant.danger,
                        icon: Icons.delete_outline_rounded,
                        onPressed: () async {
                          await ref.read(e2eControllerProvider.notifier).forgetDevice();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kunci dihapus dari perangkat ini')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Atur Master Password melalui aplikasi desktop untuk mengamankan catatan.',
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showUnlockDialog(BuildContext context) {
    showDialog(
      context: context,
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
              'Masukkan Master Password yang Anda atur di aplikasi desktop.',
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('E2E Berhasil dibuka! Catatan terdekripsi.')),
                      );
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
