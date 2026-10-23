import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/unlock_master_password_dialog.dart';
import '../../domain/ssh_host.dart';
import '../controllers/ssh_hosts_controller.dart';
import '../controllers/ssh_sessions_controller.dart';
import '../widgets/ssh_dialogs.dart';

class SshHostsScreen extends ConsumerStatefulWidget {
  const SshHostsScreen({super.key});

  @override
  ConsumerState<SshHostsScreen> createState() => _SshHostsScreenState();
}

class _SshHostsScreenState extends ConsumerState<SshHostsScreen> {
  String _query = '';
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sshHostsControllerProvider);
    final sessions = ref.watch(sshSessionsControllerProvider);
    final e2e = ref.watch(e2eControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.emeraldAccent : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SSH',
          style: AppTypography.headingMedium(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            tooltip: 'Quick Connect',
            onPressed: _quickConnect,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sinkronkan',
            onPressed: state.isSyncing
                ? null
                : () => ref.read(sshHostsControllerProvider.notifier).sync(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        foregroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Host Baru',
        onPressed: () => context.push('/ssh/host/new'),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Column(
        children: [
          if (state.isSyncing)
            LinearProgressIndicator(minHeight: 2, color: accent, backgroundColor: Colors.transparent),
          if (e2e.isLocked && state.lockedCount > 0) _buildLockedBanner(isDark, accent),
          Expanded(
            child: RefreshIndicator(
              color: accent,
              onRefresh: () => ref.read(sshHostsControllerProvider.notifier).sync(),
              child: _buildList(state, sessions, isDark, accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    SshHostsState state,
    List<SshTerminalSession> sessions,
    bool isDark,
    Color accent,
  ) {
    if (state.isLoading) return const Center(child: CircularProgressIndicator());

    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final q = _query.trim().toLowerCase();
    final entries = state.entries.where((e) {
      if (q.isEmpty) return true;
      final h = e.host;
      return e.label.toLowerCase().contains(q) ||
          (h != null && ('${h.host} ${h.username} ${h.workspace}').toLowerCase().contains(q));
    }).toList();

    final groups = <String, List<SshHostEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.workspace, () => []).add(e);
    }
    final groupNames = groups.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1; // tanpa workspace di paling bawah
        if (b.isEmpty) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari host…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (state.message != null && state.message!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(state.message!, style: AppTypography.bodySmall(color: secondary)),
          ),
        if (sessions.isNotEmpty) ...[
          _sectionHeader('Sesi Aktif', isDark),
          for (final s in sessions) _buildSessionTile(s, isDark, accent),
        ],
        if (state.entries.isEmpty)
          _buildEmpty(isDark, accent)
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('Tidak ada host yang cocok.', style: AppTypography.bodyMedium(color: secondary)),
            ),
          )
        else
          for (final g in groupNames) ...[
            _groupHeader(g, groups[g]!.length, isDark),
            if (!_collapsed.contains(g))
              for (final e in groups[g]!) _buildHostTile(e, isDark, accent),
          ],
      ],
    );
  }

  Widget _sectionHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelMedium(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          fontWeight: FontWeight.w700,
        ).copyWith(letterSpacing: 0.8, fontSize: 11),
      ),
    );
  }

  Widget _groupHeader(String name, int count, bool isDark) {
    final collapsed = _collapsed.contains(name);
    return InkWell(
      onTap: () => setState(() => collapsed ? _collapsed.remove(name) : _collapsed.add(name)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                (name.isEmpty ? 'Tanpa workspace' : name).toUpperCase(),
                style: AppTypography.labelMedium(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                ).copyWith(letterSpacing: 0.8, fontSize: 11),
              ),
            ),
            Text(
              '$count',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(SshTerminalSession s, bool isDark, Color accent) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final color = switch (s.status) {
          SshSessionStatus.connected => AppColors.success,
          SshSessionStatus.connecting => AppColors.warning,
          _ => AppColors.errorRed,
        };
        return ListTile(
          leading: Icon(Icons.terminal_rounded, color: accent),
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(s.host.address, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Tutup sesi',
                onPressed: () => ref.read(sshSessionsControllerProvider.notifier).close(s.id),
              ),
            ],
          ),
          onTap: () => context.push('/ssh/terminal/${s.id}'),
        );
      },
    );
  }

  Widget _buildHostTile(SshHostEntry e, bool isDark, Color accent) {
    final host = e.host;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isRdp = host != null && !host.isSsh;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              e.isLocked
                  ? Icons.lock_outline_rounded
                  : (isRdp ? Icons.desktop_windows_outlined : Icons.dns_rounded),
              color: e.isLocked ? secondary : accent,
              size: 20,
            ),
          ),
          title: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            e.isLocked
                ? 'Terkunci — buka E2E untuk melihat'
                : isRdp
                    ? 'RDP · ${host.host} (hanya di desktop)'
                    : host!.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall(color: secondary),
          ),
          trailing: e.isLocked
              ? null
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) => _onHostMenu(v, e),
                  itemBuilder: (_) => [
                    if (!isRdp) const PopupMenuItem(value: 'connect', child: Text('Hubungkan')),
                    if (!isRdp) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (!isRdp) const PopupMenuItem(value: 'copy', child: Text('Salin perintah ssh')),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
          onTap: () {
            if (e.isLocked) {
              showUnlockMasterPasswordDialog(context);
            } else if (isRdp) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Koneksi RDP hanya bisa dibuka dari aplikasi desktop.')),
              );
            } else {
              connectToHost(context, ref, host!);
            }
          },
          onLongPress: e.isLocked || isRdp ? null : () => context.push('/ssh/host/${e.id}'),
        ),
      ),
    );
  }

  Future<void> _onHostMenu(String action, SshHostEntry e) async {
    final host = e.host!;
    switch (action) {
      case 'connect':
        await connectToHost(context, ref, host);
      case 'edit':
        context.push('/ssh/host/${e.id}');
      case 'copy':
        final port = host.port == 22 ? '' : ' -p ${host.port}';
        await copyToClipboard(context, 'ssh$port ${host.username}@${host.host}', 'Perintah disalin');
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus koneksi?'),
            content: Text('"${e.label}" akan dihapus dari semua perangkat yang tersinkron.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
              ),
            ],
          ),
        );
        if (ok == true) await ref.read(sshHostsControllerProvider.notifier).delete(e.id);
    }
  }

  Future<void> _quickConnect() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Connect'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'user@host:22'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Hubungkan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.trim().isEmpty || !mounted) return;
    final host = SshHost.parseQuick(input);
    if (host == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format salah. Contoh: root@192.168.1.10:22')),
      );
      return;
    }
    await connectToHost(context, ref, host);
  }

  Widget _buildLockedBanner(bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
          Icon(Icons.lock_outline_rounded, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kredensial SSH terenkripsi E2E. Masukkan Master Password untuk membukanya.',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => showUnlockMasterPasswordDialog(context),
            child: const Text('Buka', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.terminal_rounded, size: 36, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Host',
            style: AppTypography.headingSmall(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tambah host baru, pakai Quick Connect, atau sinkronkan koneksi '
            'dari SSH Manager di desktop.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
