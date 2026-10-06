import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/valtera_button.dart';
import '../../../../core/widgets/valtera_text_field.dart';
import '../controllers/setup_controller.dart';
import '../../data/repositories/setup_repository.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }

  Future<void> _loadInitialValues() async {
    final repo = ref.read(setupRepositoryProvider);
    final config = await repo.getConfig();
    if (config.url != null) _urlController.text = config.url!;
    if (config.anonKey != null) _keyController.text = config.anonKey!;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Header
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hubungkan Supabase',
                    textAlign: TextAlign.center,
                    style: AppTypography.headingLarge(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Masukkan URL & Anon Key Supabase project Anda untuk mengaktifkan sinkronisasi catatan.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Status Message Banner
                  if (state.generalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.errorRed.withAlpha(isDark ? 90 : 60),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.generalError!,
                              style: AppTypography.bodySmall(
                                color: isDark ? Colors.red[200] : AppColors.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (state.connectionResult != null && state.connectionResult!.isSuccess) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (state.connectionResult!.isTableReady
                                ? AppColors.success
                                : AppColors.warning)
                            .withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (state.connectionResult!.isTableReady
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withAlpha(isDark ? 90 : 60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            state.connectionResult!.isTableReady
                                ? Icons.check_circle_outline_rounded
                                : Icons.warning_amber_rounded,
                            color: state.connectionResult!.isTableReady
                                ? AppColors.success
                                : AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.connectionResult!.message,
                              style: AppTypography.bodySmall(
                                color: state.connectionResult!.isTableReady
                                    ? (isDark ? AppColors.emeraldAccent : AppColors.success)
                                    : (isDark ? Colors.amber[200] : Colors.amber[900]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Fields
                  ValteraTextField(
                    controller: _urlController,
                    label: 'Project URL',
                    hintText: 'https://xyzproject.supabase.co',
                    prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                    keyboardType: TextInputType.url,
                    errorText: state.urlError,
                  ),
                  const SizedBox(height: 16),

                  ValteraTextField(
                    controller: _keyController,
                    label: 'Anon Public Key',
                    hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                    prefixIcon: const Icon(Icons.key_rounded, size: 18),
                    obscureText: _obscureKey,
                    errorText: state.anonKeyError,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  ValteraButton(
                    text: 'Test Connection',
                    variant: ValteraButtonVariant.secondary,
                    isLoading: state.isTesting,
                    icon: Icons.network_check_rounded,
                    onPressed: () {
                      ref.read(setupControllerProvider.notifier).testConnection(
                            _urlController.text,
                            _keyController.text,
                          );
                    },
                  ),
                  const SizedBox(height: 12),

                  ValteraButton(
                    text: 'Simpan & Lanjutkan',
                    isLoading: state.isSaving,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () async {
                      final ok = await ref
                          .read(setupControllerProvider.notifier)
                          .saveAndConnect(
                            _urlController.text,
                            _keyController.text,
                          );
                      if (ok && context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
