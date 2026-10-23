import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/ssh/domain/ssh_host.dart';

void main() {
  group('SshHost payload (format SshPayload desktop)', () {
    test('membaca payload SSH desktop tanpa kind sebagai SSH', () {
      final host = SshHost.fromPayload(
        id: 'a',
        label: 'Prod',
        payloadJson: jsonEncode({
          'host': '10.0.0.5',
          'port': 2222,
          'username': 'root',
          'authType': 'password',
          'password': 'rahasia',
          'workspace': 'Kantor',
        }),
      );
      expect(host.isSsh, isTrue);
      expect(host.port, 2222);
      expect(host.password, 'rahasia');
      expect(host.workspace, 'Kantor');
      expect(host.address, 'root@10.0.0.5:2222');
    });

    test('field RDP yang tidak dikenal tetap utuh setelah round-trip', () {
      final original = {
        'kind': 'rdp',
        'host': 'win.local',
        'port': 3389,
        'username': 'admin',
        'authType': 'password',
        'domain': 'CORP',
        'fullscreen': true,
        'width': 1280,
        'height': 720,
      };
      final host = SshHost.fromPayload(id: 'b', label: 'Win', payloadJson: jsonEncode(original));
      final roundTrip = jsonDecode(host.toPayloadJson()) as Map<String, dynamic>;
      expect(host.isSsh, isFalse);
      expect(roundTrip['domain'], 'CORP');
      expect(roundTrip['fullscreen'], true);
      expect(roundTrip['width'], 1280);
      expect(roundTrip['kind'], 'rdp');
    });

    test('auth key tidak menyimpan password lama', () {
      const host = SshHost(
        id: 'c',
        label: 'Key',
        host: 'h',
        username: 'u',
        authType: SshAuthType.key,
        password: 'jangan-disimpan',
        privateKey: '-----BEGIN OPENSSH PRIVATE KEY-----',
      );
      final map = jsonDecode(host.toPayloadJson()) as Map<String, dynamic>;
      expect(map['authType'], 'key');
      expect(map.containsKey('password'), isFalse);
      expect(map['privateKey'], startsWith('-----BEGIN'));
    });
  });

  group('Quick Connect', () {
    test('parse user@host dan user@host:port', () {
      expect(SshHost.parseQuick('root@1.2.3.4')!.port, 22);
      final h = SshHost.parseQuick(' deploy@example.com:2200 ')!;
      expect(h.username, 'deploy');
      expect(h.host, 'example.com');
      expect(h.port, 2200);
    });

    test('menolak format salah', () {
      expect(SshHost.parseQuick('example.com'), isNull);
      expect(SshHost.parseQuick('a@b:99999'), isNull);
    });
  });

  test('timestamp SQLite desktop dibaca sebagai UTC', () {
    final t = SshConnectionRecord.parseTimestamp('2026-10-21 08:00:00');
    expect(t.isUtc, isTrue);
    expect(t.hour, 8);
    final iso = SshConnectionRecord.parseTimestamp('2026-10-21T08:00:00+07:00');
    expect(iso.toUtc().hour, 1);
  });
}
