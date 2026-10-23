import 'dart:convert';

enum SshAuthType { password, key }

/// Satu baris koneksi tersimpan (tabel `ssh_connections`, lokal & cloud).
/// [payload] adalah JSON kredensial — ciphertext `enc:v1:` bila E2E aktif.
class SshConnectionRecord {
  final String id;
  final String label;
  final String payload;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool dirty;

  const SshConnectionRecord({
    required this.id,
    required this.label,
    required this.payload,
    required this.updatedAt,
    this.isDeleted = false,
    this.dirty = false,
  });

  factory SshConnectionRecord.fromMap(Map<String, dynamic> map) {
    return SshConnectionRecord(
      id: map['id'] as String,
      label: (map['label'] as String?) ?? '',
      payload: (map['payload'] as String?) ?? '',
      updatedAt: parseTimestamp(map['updated_at'] as String?),
      isDeleted: map['is_deleted'] == true || map['is_deleted'] == 1,
      dirty: map['dirty'] == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'payload': payload,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
        'dirty': dirty ? 1 : 0,
      };

  /// Format CURRENT_TIMESTAMP SQLite desktop ("YYYY-MM-DD HH:MM:SS") adalah UTC.
  static DateTime parseTimestamp(String? ts) {
    if (ts == null || ts.trim().isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final t = ts.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(t)) {
      return DateTime.tryParse('${t.replaceFirst(' ', 'T')}Z') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.tryParse(t)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

/// Koneksi SSH/RDP yang sudah didekripsi. Field yang tidak dikenal mobile
/// (mis. pengaturan RDP) disimpan di [extra] agar tidak hilang saat diedit.
class SshHost {
  final String id;
  final String label;
  final String kind; // 'ssh' | 'rdp'
  final String host;
  final int port;
  final String username;
  final SshAuthType authType;
  final String password;
  final String privateKey;
  final String passphrase;
  final String workspace;
  final Map<String, dynamic> extra;

  const SshHost({
    required this.id,
    required this.label,
    this.kind = 'ssh',
    required this.host,
    this.port = 22,
    required this.username,
    this.authType = SshAuthType.password,
    this.password = '',
    this.privateKey = '',
    this.passphrase = '',
    this.workspace = '',
    this.extra = const {},
  });

  bool get isSsh => kind == 'ssh';

  String get address => port == 22 ? '$username@$host' : '$username@$host:$port';

  static const _knownKeys = {
    'kind',
    'host',
    'port',
    'username',
    'authType',
    'password',
    'privateKey',
    'passphrase',
    'workspace',
  };

  factory SshHost.fromPayload({
    required String id,
    required String label,
    required String payloadJson,
  }) {
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    return SshHost(
      id: id,
      label: label,
      kind: (map['kind'] as String?) ?? 'ssh',
      host: (map['host'] as String?) ?? '',
      port: (map['port'] as num?)?.toInt() ?? 22,
      username: (map['username'] as String?) ?? '',
      authType: map['authType'] == 'key' ? SshAuthType.key : SshAuthType.password,
      password: (map['password'] as String?) ?? '',
      privateKey: (map['privateKey'] as String?) ?? '',
      passphrase: (map['passphrase'] as String?) ?? '',
      workspace: (map['workspace'] as String?) ?? '',
      extra: Map.of(map)..removeWhere((k, _) => _knownKeys.contains(k)),
    );
  }

  /// JSON payload dengan bentuk yang sama seperti SshPayload di desktop.
  String toPayloadJson() {
    final map = <String, dynamic>{
      ...extra,
      'kind': kind,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType == SshAuthType.key ? 'key' : 'password',
    };
    if (authType == SshAuthType.password) {
      if (password.isNotEmpty) map['password'] = password;
    } else {
      if (privateKey.isNotEmpty) map['privateKey'] = privateKey;
      if (passphrase.isNotEmpty) map['passphrase'] = passphrase;
    }
    if (workspace.trim().isNotEmpty) map['workspace'] = workspace.trim();
    return jsonEncode(map);
  }

  SshHost copyWith({String? password, String? passphrase}) {
    return SshHost(
      id: id,
      label: label,
      kind: kind,
      host: host,
      port: port,
      username: username,
      authType: authType,
      password: password ?? this.password,
      privateKey: privateKey,
      passphrase: passphrase ?? this.passphrase,
      workspace: workspace,
      extra: extra,
    );
  }

  /// Parse "user@host:port" untuk Quick Connect.
  static SshHost? parseQuick(String input) {
    final m = RegExp(r'^\s*([^@\s]+)@([^:\s]+)(?::(\d{1,5}))?\s*$').firstMatch(input);
    if (m == null) return null;
    final port = int.tryParse(m.group(3) ?? '') ?? 22;
    if (port < 1 || port > 65535) return null;
    return SshHost(
      id: 'quick:${m.group(1)}@${m.group(2)}:$port',
      label: '${m.group(1)}@${m.group(2)}',
      host: m.group(2)!,
      port: port,
      username: m.group(1)!,
    );
  }
}
