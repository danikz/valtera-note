import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../crypto/e2e_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'valtera_text_field.dart';

/// Dialog Master Password E2E — dipakai layar catatan dan SSH.
Future<void> showUnlockMasterPasswordDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const UnlockMasterPasswordDialog(),
  );
}

class UnlockMasterPasswordDialog extends ConsumerStatefulWidget {
  const UnlockMasterPasswordDialog({super.key});

  @override
  ConsumerState<UnlockMasterPasswordDialog> createState() =>
      UnlockMasterPasswordDialogState();
}

class UnlockMasterPasswordDialogState
    extends ConsumerState<UnlockMasterPasswordDialog> {
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
