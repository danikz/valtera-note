import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/ssh_sessions_controller.dart';
import '../widgets/ssh_dialogs.dart';

final sshFontSizeProvider = NotifierProvider<SshFontSize, double>(SshFontSize.new);

class SshFontSize extends Notifier<double> {
  static const min = 8.0;
  static const max = 24.0;

  @override
  double build() => 13;

  void change(double delta) => state = (state + delta).clamp(min, max);
}

class SshTerminalScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SshTerminalScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SshTerminalScreen> createState() => _SshTerminalScreenState();
}

class _SshTerminalScreenState extends ConsumerState<SshTerminalScreen> {
  late String _currentId = widget.sessionId;
  final _focusNode = FocusNode();
  List<SshTerminalSession> _lastSessions = const [];
  late final SshSessionsController _sessions;

  Future<bool> _prompt(HostKeyCheck check) async {
    if (!mounted) return false;
    return showHostKeyDialog(context, check);
  }

  @override
  void initState() {
    super.initState();
    _sessions = ref.read(sshSessionsControllerProvider.notifier);
    _sessions.hostKeyPrompt = _prompt;
  }

  @override
  void dispose() {
    if (_sessions.hostKeyPrompt == _prompt) _sessions.hostKeyPrompt = null;
    // ref tidak boleh dipakai di dispose — pakai daftar dari build terakhir.
    for (final s in _lastSessions) {
      s.visible = false;
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _select(String id) {
    setState(() => _currentId = id);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sshSessionsControllerProvider);
    final fontSize = ref.watch(sshFontSizeProvider);
    _lastSessions = sessions;

    SshTerminalSession? session;
    for (final s in sessions) {
      s.visible = s.id == _currentId;
      if (s.visible) session = s;
    }
    if (session == null && sessions.isNotEmpty) {
      // Sesi yang tampil ditutup -> pindah ke sesi lain yang masih ada.
      session = sessions.last;
      _currentId = session.id;
      session.visible = true;
    }
    final shown = session;
    if (shown != null && shown.unread) {
      // markRead memberi notifikasi ke listener — jangan saat build.
      WidgetsBinding.instance.addPostFrameCallback((_) => shown.markRead());
    }

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terminal')),
        body: const Center(child: Text('Tidak ada sesi aktif.')),
      );
    }
    final current = session;

    return Scaffold(
      backgroundColor: TerminalThemes.defaultTheme.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: current,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                _statusText(current),
                style: TextStyle(fontSize: 11, color: _statusColor(current.status)),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste_rounded),
            tooltip: 'Tempel',
            onPressed: () => _paste(current),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => _onMenu(v, current),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy', child: Text('Salin teks terpilih')),
              const PopupMenuItem(value: 'font+', child: Text('Perbesar font')),
              const PopupMenuItem(value: 'font-', child: Text('Perkecil font')),
              if (!current.isActive)
                const PopupMenuItem(value: 'reconnect', child: Text('Hubungkan ulang')),
              if (current.isActive)
                const PopupMenuItem(value: 'disconnect', child: Text('Putuskan')),
              const PopupMenuItem(value: 'close', child: Text('Tutup tab')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _SessionTabs(
              sessions: sessions,
              currentId: current.id,
              onSelect: _select,
              onNew: () => context.canPop() ? context.pop() : context.go('/ssh'),
            ),
            Expanded(
              child: TerminalView(
                current.terminal,
                key: ValueKey(current.id),
                controller: current.terminalController,
                focusNode: _focusNode,
                autofocus: true,
                textStyle: TerminalStyle(fontSize: fontSize),
                padding: const EdgeInsets.all(4),
                // Matikan saran/autocorrect keyboard agar input terkirim apa adanya.
                keyboardType: TextInputType.visiblePassword,
                deleteDetection: true,
              ),
            ),
            ListenableBuilder(
              listenable: current,
              builder: (context, _) => current.isActive
                  ? const SizedBox.shrink()
                  : _DisconnectedBar(
                      session: current,
                      onReconnect: () => current.connect(),
                      onClose: () => _closeTab(current),
                    ),
            ),
            _ExtraKeysBar(
              session: current,
              onToggleKeyboard: _toggleKeyboard,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleKeyboard() {
    if (_focusNode.hasFocus && MediaQuery.of(context).viewInsets.bottom > 0) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  Future<void> _paste(SshTerminalSession session) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    session.paste(text);
  }

  void _closeTab(SshTerminalSession session) {
    final remaining = ref.read(sshSessionsControllerProvider).where((s) => s.id != session.id);
    _sessions.close(session.id);
    if (remaining.isEmpty && mounted) {
      context.canPop() ? context.pop() : context.go('/ssh');
    }
  }

  Future<void> _onMenu(String action, SshTerminalSession session) async {
    switch (action) {
      case 'copy':
        final text = session.selectedText();
        if (text == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tekan lama pada terminal untuk memilih teks.')),
          );
        } else {
          await copyToClipboard(context, text, 'Teks disalin');
          session.terminalController.clearSelection();
        }
      case 'font+':
        ref.read(sshFontSizeProvider.notifier).change(1);
      case 'font-':
        ref.read(sshFontSizeProvider.notifier).change(-1);
      case 'reconnect':
        await session.connect();
      case 'disconnect':
        session.disconnect();
      case 'close':
        _closeTab(session);
    }
  }

  static String _statusText(SshTerminalSession s) {
    return switch (s.status) {
      SshSessionStatus.connecting => 'Menghubungkan…',
      SshSessionStatus.connected => s.host.address,
      SshSessionStatus.closed => s.error ?? 'Terputus',
      SshSessionStatus.failed => s.error ?? 'Gagal',
    };
  }

  static Color _statusColor(SshSessionStatus status) {
    return switch (status) {
      SshSessionStatus.connected => AppColors.success,
      SshSessionStatus.connecting => AppColors.warning,
      _ => AppColors.errorRed,
    };
  }
}

class _SessionTabs extends StatelessWidget {
  final List<SshTerminalSession> sessions;
  final String currentId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;

  const _SessionTabs({
    required this.sessions,
    required this.currentId,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppColors.darkSurface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        children: [
          for (final s in sessions)
            ListenableBuilder(
              listenable: s,
              builder: (context, _) {
                final selected = s.id == currentId;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelect(s.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.darkSurfaceVariant : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppColors.emeraldAccent.withAlpha(140) : AppColors.darkBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switch (s.status) {
                                SshSessionStatus.connected => AppColors.success,
                                SshSessionStatus.connecting => AppColors.warning,
                                _ => AppColors.errorRed,
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              s.host.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary,
                                fontWeight: s.unread ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.darkTextSecondary),
            tooltip: 'Sesi baru',
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

class _DisconnectedBar extends StatelessWidget {
  final SshTerminalSession session;
  final VoidCallback onReconnect;
  final VoidCallback onClose;

  const _DisconnectedBar({
    required this.session,
    required this.onReconnect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurfaceVariant,
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          const Icon(Icons.link_off_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.error ?? 'Terputus',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.darkTextPrimary),
            ),
          ),
          TextButton(onPressed: onClose, child: const Text('Tutup')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emeraldAccent,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onReconnect,
            child: const Text('Hubungkan Ulang'),
          ),
        ],
      ),
    );
  }
}

/// Baris tombol yang tidak ada di keyboard HP: Esc, Ctrl, Alt, Tab, panah, dll.
class _ExtraKeysBar extends StatelessWidget {
  final SshTerminalSession session;
  final VoidCallback onToggleKeyboard;

  const _ExtraKeysBar({required this.session, required this.onToggleKeyboard});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        Widget key(String label, VoidCallback onTap, {bool active = false, IconData? icon}) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: active ? AppColors.emeraldAccent : AppColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  child: icon != null
                      ? Icon(icon, size: 18, color: active ? Colors.black : AppColors.darkTextPrimary)
                      : Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: active ? Colors.black : AppColors.darkTextPrimary,
                          ),
                        ),
                ),
              ),
            ),
          );
        }

        void send(TerminalKey k) => session.sendKey(k);
        void text(String t) => session.sendText(t);

        return Container(
          color: AppColors.darkSurface,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                key('', onToggleKeyboard, icon: Icons.keyboard_rounded),
                key('ESC', () => send(TerminalKey.escape)),
                key('CTRL', session.toggleCtrl, active: session.ctrlArmed),
                key('ALT', session.toggleAlt, active: session.altArmed),
                key('TAB', () => send(TerminalKey.tab)),
                key('', () => send(TerminalKey.arrowUp), icon: Icons.keyboard_arrow_up_rounded),
                key('', () => send(TerminalKey.arrowDown), icon: Icons.keyboard_arrow_down_rounded),
                key('', () => send(TerminalKey.arrowLeft), icon: Icons.keyboard_arrow_left_rounded),
                key('', () => send(TerminalKey.arrowRight), icon: Icons.keyboard_arrow_right_rounded),
                key('/', () => text('/')),
                key('-', () => text('-')),
                key('|', () => text('|')),
                key('~', () => text('~')),
                key('_', () => text('_')),
                key(':', () => text(':')),
                key('HOME', () => send(TerminalKey.home)),
                key('END', () => send(TerminalKey.end)),
                key('PGUP', () => send(TerminalKey.pageUp)),
                key('PGDN', () => send(TerminalKey.pageDown)),
                key('^C', () => text('\x03')),
                key('^D', () => text('\x04')),
                key('^Z', () => text('\x1a')),
              ],
            ),
          ),
        );
      },
    );
  }
}
