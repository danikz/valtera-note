import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/valtera_button.dart';
import '../../../../core/widgets/valtera_text_field.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Daftar Akun Baru',
                    textAlign: TextAlign.center,
                    style: AppTypography.headingLarge(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Buat akun Supabase untuk mengamankan catatan Anda.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (state.errorMessage != null) ...[
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
                              state.errorMessage!,
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

                  if (state.successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withAlpha(isDark ? 90 : 60),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.successMessage!,
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.emeraldAccent : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ValteraTextField(
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'nama@domain.com',
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  ValteraTextField(
                    controller: _passwordController,
                    label: 'Kata Sandi',
                    hintText: 'Minimal 6 karakter',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ValteraTextField(
                    controller: _confirmPasswordController,
                    label: 'Konfirmasi Kata Sandi',
                    hintText: 'Ulangi kata sandi',
                    prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 24),

                  ValteraButton(
                    text: 'Daftar Sekarang',
                    isLoading: state.isLoading,
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: () async {
                      final ok = await ref.read(authControllerProvider.notifier).register(
                            _emailController.text,
                            _passwordController.text,
                            _confirmPasswordController.text,
                          );
                      if (ok && context.mounted) {
                        if (state.isEmailConfirmationRequired) {
                          // Let user read message
                        } else {
                          context.go('/notes');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun? ',
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Masuk',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.emeraldAccent : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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
