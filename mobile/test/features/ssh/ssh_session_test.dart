import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/features/ssh/domain/ssh_host.dart';
import 'package:valtera_note/features/ssh/presentation/controllers/ssh_sessions_controller.dart';

void main() {
  test('koneksi ditolak -> status failed dengan pesan, tanpa exception', () async {
    final session = SshTerminalSession(
      host: const SshHost(id: 'x', label: 'Mati', host: '127.0.0.1', port: 1, username: 'u', password: 'p'),
      storage: const SecureStorageService(),
      hostKeyPrompt: () => (_) async => false,
    );
    await session.connect();
    expect(session.status, SshSessionStatus.failed);
    expect(session.error, isNotEmpty);
    expect(session.isActive, isFalse);
    session.dispose();
  });

  test('modifier CTRL sticky dilepas setelah satu tombol', () {
    final session = SshTerminalSession(
      host: const SshHost(id: 'y', label: 'L', host: 'h', username: 'u'),
      storage: const SecureStorageService(),
      hostKeyPrompt: () => (_) async => false,
    );
    session.toggleCtrl();
    expect(session.ctrlArmed, isTrue);
    // Belum terhubung: input dibuang tapi modifier tidak boleh "nyangkut".
    session.sendKey(TerminalKey.escape);
    expect(session.ctrlArmed, isFalse);
    session.dispose();
  });
}
