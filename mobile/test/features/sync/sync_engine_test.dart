import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/sync/domain/models/sync_queue_item.dart';

void main() {
  group('SyncQueueItem Model Tests', () {
    final now = DateTime.utc(2026, 10, 5, 14, 0, 0);
    final item = SyncQueueItem(
      id: 1,
      operation: 'update',
      entityId: 'note-uuid-1',
      payload: {'title': 'Updated Title', 'content': 'Updated Content'},
      createdAt: now,
      attemptCount: 1,
      lastError: 'Network timeout',
      status: SyncQueueStatus.failed,
    );

    test('toMap and fromMap preserves all fields', () {
      final map = item.toMap();
      expect(map['id'], 1);
      expect(map['operation'], 'update');
      expect(map['entity_id'], 'note-uuid-1');
      expect(map['payload'], jsonEncode({'title': 'Updated Title', 'content': 'Updated Content'}));
      expect(map['status'], 'failed');
      expect(map['attempt_count'], 1);
      expect(map['last_error'], 'Network timeout');

      final reconstructed = SyncQueueItem.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.operation, 'update');
      expect(reconstructed.entityId, 'note-uuid-1');
      expect(reconstructed.payload['title'], 'Updated Title');
      expect(reconstructed.status, SyncQueueStatus.failed);
      expect(reconstructed.attemptCount, 1);
      expect(reconstructed.lastError, 'Network timeout');
    });

    test('isRetryable returns false after max attempts (3)', () {
      final retriedMax = item.copyWith(attemptCount: 3);
      expect(retriedMax.isRetryable, isFalse);

      final fresh = item.copyWith(attemptCount: 1);
      expect(fresh.isRetryable, isTrue);
    });
  });
}
