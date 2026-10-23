import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/ssh_host.dart';
import '../controllers/ssh_sessions_controller.dart';

/// Buka sesi baru ke [host] lalu tampilkan terminalnya. Kredensial yang tidak
/// disimpan (password kosong / passphrase key) ditanyakan dulu, seperti Termius.
/// [replace] mengganti layar sekarang (mis. form host) dengan terminal.
Future<void> connectToHost(
  BuildContext context,
  WidgetRef ref,
  SshHost host, {
  bool replace = false,
}) async {
  var target = host;

  if (host.authType == SshAuthType.password && host.password.isEmpty) {
    final pw = await promptSecret(
      context,
      title: 'Password untuk ${host.address}',
      label: 'Password',
    );
    if (pw == null) return;
    target = host.copyWith(password: pw);
  } else if (host.authType == SshAuthType.key && host.passphrase.isEmpty) {
    var encrypted = false;
    try {
      encrypted = SSHKeyPair.isEncryptedPem(host.privateKey.trim());
    } catch (_) {
      // Key tidak valid — biarkan sesi yang melaporkan errornya.
    }
    if (encrypted) {
      if (!context.mounted) return;
      final pass = await promptSecret(
        context,
        title: 'Passphrase private key',
        label: 'Passphrase',
      );
      if (pass == null) return;
      target = host.copyWith(passphrase: pass);
    }
  }

  final session = ref.read(sshSessionsControllerProvider.notifier).open(target);
  if (!context.mounted) return;
  final location = '/ssh/terminal/${session.id}';
  if (replace) {
    context.pushReplacement(location);
  } else {
    context.push(location);
  }
}

Future<String?> promptSecret(
  BuildContext context, {
  required String title,
  required String label,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _SecretDialog(title: title, label: label),
  );
}

class _SecretDialog extends StatefulWidget {
  final String title;
  final String label;

  const _SecretDialog({required this.title, required this.label});

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: AppTypography.headingSmall(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Hubungkan'),
        ),
      ],
    );
  }
}

/// Konfirmasi host key (trust on first use). Host key yang BERUBAH bisa
/// berarti server diinstal ulang — atau serangan man-in-the-middle.
Future<bool> showHostKeyDialog(BuildContext context, HostKeyCheck check) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final changed = check.previous != null;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            changed ? Icons.warning_amber_rounded : Icons.fingerprint_rounded,
            color: changed ? AppColors.errorRed : (isDark ? AppColors.emeraldAccent : AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              changed ? 'Host key BERUBAH!' : 'Host baru',
              style: AppTypography.headingSmall(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              changed
                  ? 'Identitas ${check.hostPort} berbeda dari yang tersimpan. Ini bisa '
                      'berarti server diinstal ulang, atau ada yang menyadap koneksi. '
                      'Lanjutkan hanya jika Anda yakin.'
                  : 'Belum pernah terhubung ke ${check.hostPort}. Pastikan fingerprint '
                      'ini sesuai dengan server Anda.',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              '${check.type}\n${check.fingerprint}',
              style: AppTypography.codeFont(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontSize: 12,
              ),
            ),
            if (changed) ...[
              const SizedBox(height: 10),
              Text(
                'Sebelumnya:',
                style: AppTypography.bodySmall(color: AppColors.errorRed),
              ),
              SelectableText(
                check.previous!,
                style: AppTypography.codeFont(color: AppColors.errorRed, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Tolak'),
        ),
        ElevatedButton(
          style: changed
              ? ElevatedButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(changed ? 'Tetap Percaya' : 'Percaya & Lanjut'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> copyToClipboard(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
