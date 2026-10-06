import 'dart:convert';

enum SyncQueueStatus { pending, processing, failed }

class SyncQueueItem {
  final int? id;
  final String operation; // 'create' | 'update' | 'delete'
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;
  final SyncQueueStatus status;

  static const int maxRetryAttempts = 3;

  const SyncQueueItem({
    this.id,
    required this.operation,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
    this.status = SyncQueueStatus.pending,
  });

  bool get isRetryable => attemptCount < maxRetryAttempts;

  SyncQueueItem copyWith({
    int? id,
    String? operation,
    String? entityId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? attemptCount,
    String? lastError,
    SyncQueueStatus? status,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'operation': operation,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'created_at': createdAt.toUtc().toIso8601String(),
      'attempt_count': attemptCount,
      'last_error': lastError,
      'status': status.name,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    try {
      final raw = map['payload'];
      if (raw is String) {
        parsedPayload = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        parsedPayload = raw;
      }
    } catch (_) {}

    return SyncQueueItem(
      id: map['id'] as int?,
      operation: map['operation'] as String,
      entityId: map['entity_id'] as String,
      payload: parsedPayload,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      attemptCount: (map['attempt_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
      status: SyncQueueStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SyncQueueStatus.pending,
      ),
    );
  }
}
