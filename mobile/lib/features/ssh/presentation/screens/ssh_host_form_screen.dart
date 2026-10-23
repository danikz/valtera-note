import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/valtera_button.dart';
import '../../../../core/widgets/valtera_text_field.dart';
import '../../data/ssh_repository.dart';
import '../../domain/ssh_host.dart';
import '../controllers/ssh_hosts_controller.dart';
import '../widgets/ssh_dialogs.dart';

class SshHostFormScreen extends ConsumerStatefulWidget {
  final String? hostId; // null = host baru

  const SshHostFormScreen({super.key, this.hostId});

  @override
  ConsumerState<SshHostFormScreen> createState() => _SshHostFormScreenState();
}

class _SshHostFormScreenState extends ConsumerState<SshHostFormScreen> {
  final _label = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();
  final _workspace = TextEditingController();

  SshAuthType _authType = SshAuthType.password;
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  SshHost? _original;

  @override
  void initState() {
    super.initState();
    final id = widget.hostId;
    if (id != null) {
      final h = ref.read(sshHostsControllerProvider.notifier).hostById(id);
      if (h != null) {
        _original = h;
        _label.text = h.label;
        _host.text = h.host;
        _port.text = '${h.port}';
        _username.text = h.username;
        _password.text = h.password;
        _privateKey.text = h.privateKey;
        _passphrase.text = h.passphrase;
        _workspace.text = h.workspace;
        _authType = h.authType;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_label, _host, _port, _username, _password, _privateKey, _passphrase, _workspace]) {
      c.dispose();
    }
    super.dispose();
  }

  SshHost? _buildHost() {
    final host = _host.text.trim();
    final user = _username.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || user.isEmpty) {
      setState(() => _error = 'Host dan username wajib diisi.');
      return null;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Port harus 1–65535.');
      return null;
    }
    if (_authType == SshAuthType.key) {
      final key = _privateKey.text.trim();
      if (key.isEmpty) {
        setState(() => _error = 'Private key wajib diisi.');
        return null;
      }
      try {
        SSHKeyPair.isEncryptedPem(key);
      } catch (_) {
        setState(() => _error = 'Private key tidak dikenali. Gunakan format OpenSSH atau PEM (RSA/EC).');
        return null;
      }
    }
    return SshHost(
      id: _original?.id ?? '',
      label: _label.text.trim(),
      kind: 'ssh',
      host: host,
      port: port,
      username: user,
      authType: _authType,
      password: _password.text,
      privateKey: _privateKey.text.trim(),
      passphrase: _passphrase.text,
      workspace: _workspace.text.trim(),
      extra: _original?.extra ?? const {},
    );
  }

  Future<void> _save({bool connect = false}) async {
    final host = _buildHost();
    if (host == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sshHostsControllerProvider.notifier).save(host);
      if (!mounted) return;
      if (connect) {
        await connectToHost(context, ref, host, replace: true);
      } else {
        context.pop();
      }
    } on SshLockedException catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() => _privateKey.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.emeraldAccent : AppColors.primary;
    final workspaces = {
      for (final e in ref.watch(sshHostsControllerProvider).entries)
        if (e.workspace.isNotEmpty) e.workspace,
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _original == null ? 'Host Baru' : 'Edit Host',
          style: AppTypography.headingMedium(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.hostId != null && _original == null)
              _errorBox('Host tidak ditemukan atau masih terkunci E2E.'),
            if (_error != null) _errorBox(_error!),
            ValteraTextField(
              controller: _label,
              label: 'Label',
              hintText: 'mis. Server Produksi',
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ValteraTextField(
                    controller: _host,
                    label: 'Host / IP',
                    hintText: '192.168.1.10',
                    keyboardType: TextInputType.url,
                    prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValteraTextField(
                    controller: _port,
                    label: 'Port',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ValteraTextField(
              controller: _username,
              label: 'Username',
              hintText: 'root',
              keyboardType: TextInputType.visiblePassword,
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
            ),
            const SizedBox(height: 14),
            ValteraTextField(
              controller: _workspace,
              label: 'Workspace (opsional)',
              hintText: 'Pengelompokan, mis. nama kantor',
              prefixIcon: const Icon(Icons.folder_outlined, size: 18),
            ),
            if (workspaces.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final w in workspaces)
                    ActionChip(
                      label: Text(w, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _workspace.text = w),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SegmentedButton<SshAuthType>(
              segments: const [
                ButtonSegment(
                  value: SshAuthType.password,
                  label: Text('Password'),
                  icon: Icon(Icons.password_rounded, size: 18),
                ),
                ButtonSegment(
                  value: SshAuthType.key,
                  label: Text('Private Key'),
                  icon: Icon(Icons.key_rounded, size: 18),
                ),
              ],
              selected: {_authType},
              onSelectionChanged: (s) => setState(() => _authType = s.first),
            ),
            const SizedBox(height: 14),
            if (_authType == SshAuthType.password)
              ValteraTextField(
                controller: _password,
                label: 'Password',
                helperText: 'Kosongkan untuk ditanyakan setiap kali terhubung.',
                obscureText: _obscure,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Private Key',
                      style: AppTypography.labelMedium(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pasteKey,
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: const Text('Tempel'),
                  ),
                ],
              ),
              TextField(
                controller: _privateKey,
                minLines: 5,
                maxLines: 10,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.multiline,
                style: AppTypography.codeFont(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 11,
                ),
                decoration: InputDecoration(
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              ValteraTextField(
                controller: _passphrase,
                label: 'Passphrase (opsional)',
                helperText: 'Kosongkan untuk ditanyakan saat terhubung bila key terenkripsi.',
                obscureText: _obscure,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Kredensial dienkripsi E2E sebelum disinkronkan ke cloud.',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ).copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ValteraButton(
              text: 'Simpan & Hubungkan',
              icon: Icons.terminal_rounded,
              isLoading: _saving,
              onPressed: _saving ? null : () => _save(connect: true),
            ),
            const SizedBox(height: 10),
            ValteraButton(
              text: 'Simpan',
              variant: ValteraButtonVariant.secondary,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.errorRed.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTypography.bodySmall(color: AppColors.errorRed))),
        ],
      ),
    );
  }
}
