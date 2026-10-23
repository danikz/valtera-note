import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../setup/data/repositories/setup_repository.dart';
import '../../domain/ssh_host.dart';

enum SshSessionStatus { connecting, connected, closed, failed }

/// Host key yang belum dikenal / berubah — harus dikonfirmasi user (TOFU).
class HostKeyCheck {
  final String hostPort;
  final String type;
  final String fingerprint;
  final String? previous; // terisi bila host key BERUBAH sejak terakhir

  const HostKeyCheck({
    required this.hostPort,
    required this.type,
    required this.fingerprint,
    this.previous,
  });
}

typedef HostKeyPrompt = Future<bool> Function(HostKeyCheck check);

/// Satu sesi shell hidup = satu Terminal. Tetap hidup saat user pindah layar,
/// jadi scrollback dan output sesi di background tidak hilang.
class SshTerminalSession extends ChangeNotifier {
  final String id = const Uuid().v4();
  final SshHost host;
  final SecureStorageService _storage;
  final HostKeyPrompt Function() _hostKeyPrompt;

  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController terminalController = TerminalController();

  SshSessionStatus status = SshSessionStatus.connecting;
  String? error;
  String title;
  bool unread = false;
  bool visible = false; // sedang ditampilkan layar terminal

  // Modifier "sticky" dari toolbar: berlaku untuk satu input berikutnya.
  bool ctrlArmed = false;
  bool altArmed = false;

  SSHClient? _client;
  SSHSession? _shell;
  final List<StreamSubscription> _subs = [];
  bool _disposed = false;

  SshTerminalSession({
    required this.host,
    required SecureStorageService storage,
    required HostKeyPrompt Function() hostKeyPrompt,
  })  : _storage = storage,
        _hostKeyPrompt = hostKeyPrompt,
        title = host.label {
    terminal.onOutput = _onTerminalOutput;
    terminal.onResize = (w, h, pw, ph) {
      try {
        _shell?.resizeTerminal(w, h, pw, ph);
      } catch (_) {}
    };
    terminal.onTitleChange = (t) {
      if (t.trim().isNotEmpty) {
        title = t.trim();
        _notify();
      }
    };
  }

  bool get isActive =>
      status == SshSessionStatus.connecting || status == SshSessionStatus.connected;

  Future<void> connect() async {
    _teardown();
    status = SshSessionStatus.connecting;
    error = null;
    _notify();
    terminal.write('\x1b[90mMenghubungkan ke ${host.address}…\x1b[0m\r\n');

    try {
      final identities = <SSHKeyPair>[];
      if (host.authType == SshAuthType.key) {
        try {
          identities.addAll(SSHKeyPair.fromPem(
            host.privateKey.trim(),
            host.passphrase.isEmpty ? null : host.passphrase,
          ));
        } on SSHKeyDecryptError {
          throw 'Passphrase private key salah atau belum diisi.';
        } catch (e) {
          throw 'Private key tidak valid ($e). Gunakan format OpenSSH/PEM.';
        }
      }

      final socket = await SSHSocket.connect(
        host.host,
        host.port,
        timeout: const Duration(seconds: 15),
      );

      final client = SSHClient(
        socket,
        username: host.username,
        identities: identities.isEmpty ? null : identities,
        onPasswordRequest:
            host.authType == SshAuthType.password ? () => host.password : null,
        // Banyak server hanya menawarkan keyboard-interactive untuk password.
        onUserInfoRequest: host.authType == SshAuthType.password
            ? (request) => request.prompts.map((_) => host.password).toList()
            : null,
        onVerifyHostKey: _verifyHostKey,
        keepAliveInterval: const Duration(seconds: 15),
        handshakeTimeout: const Duration(seconds: 20),
        authTimeout: const Duration(seconds: 30),
      );
      _client = client;
      await client.authenticated;

      final shell = await client.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );
      _shell = shell;

      _subs.add(const Utf8Decoder(allowMalformed: true)
          .bind(shell.stdout)
          .listen(_onRemoteOutput));
      _subs.add(const Utf8Decoder(allowMalformed: true)
          .bind(shell.stderr)
          .listen(_onRemoteOutput));

      status = SshSessionStatus.connected;
      _notify();

      unawaited(shell.done.whenComplete(() {
        if (_shell != shell) return;
        _markClosed('Sesi berakhir');
      }));
      unawaited(client.done.catchError((Object e) {
        if (_client != client) return;
        _markClosed('Koneksi terputus: ${_describe(e)}');
      }));
    } catch (e) {
      _teardown();
      status = SshSessionStatus.failed;
      error = _describe(e);
      terminal.write('\r\n\x1b[31m✗ $error\x1b[0m\r\n');
      _notify();
    }
  }

  Future<bool> _verifyHostKey(String type, Uint8List fingerprintBytes) async {
    final fingerprint = utf8.decode(fingerprintBytes, allowMalformed: true);
    final hostPort = '${host.host}:${host.port}';
    final value = '$type $fingerprint';
    final known = await _storage.getSshKnownHosts();
    final previous = known[hostPort];
    if (previous == value) return true;

    final accepted = await _hostKeyPrompt()(HostKeyCheck(
      hostPort: hostPort,
      type: type,
      fingerprint: fingerprint,
      previous: previous,
    ));
    if (!accepted) return false;
    known[hostPort] = value;
    await _storage.saveSshKnownHosts(known);
    return true;
  }

  void _onRemoteOutput(String data) {
    terminal.write(data);
    if (!visible && !unread) {
      unread = true;
      _notify();
    }
  }

  void _onTerminalOutput(String data) {
    final shell = _shell;
    if (shell == null || status != SshSessionStatus.connected) return;
    var out = data;
    if (ctrlArmed || altArmed) {
      if (ctrlArmed && out.length == 1) out = _ctrlChar(out);
      if (altArmed) out = '\x1b$out';
      ctrlArmed = false;
      altArmed = false;
      _notify();
    }
    shell.write(Uint8List.fromList(utf8.encode(out)));
  }

  static String _ctrlChar(String ch) {
    final c = ch.codeUnitAt(0);
    if (c >= 0x61 && c <= 0x7a) return String.fromCharCode(c - 0x60); // a-z
    if (c >= 0x40 && c <= 0x5f) return String.fromCharCode(c - 0x40); // @ A-Z [ \ ] ^ _
    if (c == 0x20) return '\x00';
    if (c == 0x3f) return '\x7f';
    return ch;
  }

  /// Tombol toolbar (Esc, panah, dll) — modifier aktif ikut diterapkan.
  void sendKey(TerminalKey key) {
    final ctrl = ctrlArmed, alt = altArmed;
    ctrlArmed = false;
    altArmed = false;
    terminal.keyInput(key, ctrl: ctrl, alt: alt);
    _notify();
  }

  void sendText(String text) => terminal.textInput(text);

  void paste(String text) {
    ctrlArmed = false;
    altArmed = false;
    terminal.paste(text);
    _notify();
  }

  void toggleCtrl() {
    ctrlArmed = !ctrlArmed;
    _notify();
  }

  void toggleAlt() {
    altArmed = !altArmed;
    _notify();
  }

  void markRead() {
    if (unread) {
      unread = false;
      _notify();
    }
  }

  String? selectedText() {
    final range = terminalController.selection;
    if (range == null) return null;
    final text = terminal.buffer.getText(range);
    return text.isEmpty ? null : text;
  }

  void _markClosed(String reason) {
    if (status == SshSessionStatus.closed || status == SshSessionStatus.failed) return;
    _teardown();
    status = SshSessionStatus.closed;
    error = reason;
    terminal.write('\r\n\x1b[33m[$reason]\x1b[0m\r\n');
    _notify();
  }

  void disconnect() => _markClosed('Diputus');

  void _teardown() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final shell = _shell, client = _client;
    _shell = null;
    _client = null;
    try {
      shell?.close();
    } catch (_) {}
    try {
      client?.close();
    } catch (_) {}
  }

  static String _describe(Object e) {
    if (e is String) return e;
    if (e is SSHAuthFailError || e is SSHAuthAbortError) {
      return 'Autentikasi gagal — periksa username, password, atau private key.';
    }
    if (e is SSHHostkeyError) return 'Host key ditolak.';
    if (e is TimeoutException) return 'Waktu koneksi habis.';
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return 'Tidak bisa terhubung ke host ($s)';
    }
    return s;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _teardown();
    super.dispose();
  }
}

final sshSessionsControllerProvider =
    NotifierProvider<SshSessionsController, List<SshTerminalSession>>(
        SshSessionsController.new);

class SshSessionsController extends Notifier<List<SshTerminalSession>> {
  /// Diisi oleh layar terminal yang sedang tampil; tanpa UI host key ditolak.
  HostKeyPrompt? hostKeyPrompt;

  @override
  List<SshTerminalSession> build() {
    ref.onDispose(() {
      for (final s in state) {
        s.dispose();
      }
    });
    return const [];
  }

  SshTerminalSession open(SshHost host) {
    final session = SshTerminalSession(
      host: host,
      storage: ref.read(secureStorageServiceProvider),
      hostKeyPrompt: () => _promptHostKey,
    );
    state = [...state, session];
    unawaited(session.connect());
    return session;
  }

  /// Sesi mulai terhubung sebelum layar terminal sempat memasang prompt —
  /// beri waktu sebentar, lalu tolak bila tetap tidak ada UI.
  Future<bool> _promptHostKey(HostKeyCheck check) async {
    for (var i = 0; i < 30 && hostKeyPrompt == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final prompt = hostKeyPrompt;
    return prompt == null ? false : prompt(check);
  }

  SshTerminalSession? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  void close(String id) {
    final session = byId(id);
    if (session == null) return;
    state = state.where((s) => s.id != id).toList();
    session.dispose();
  }

  void closeAll() {
    final sessions = state;
    state = const [];
    for (final s in sessions) {
      s.dispose();
    }
  }
}
