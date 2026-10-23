import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../data/ssh_repository.dart';
import '../../domain/ssh_host.dart';

class SshHostEntry {
  final SshConnectionRecord record;
  final SshHost? host; // null = terkunci E2E

  const SshHostEntry(this.record, this.host);

  String get id => record.id;
  String get label => record.label;
  bool get isLocked => host == null;
  String get workspace => host?.workspace.trim() ?? '';
}

class SshHostsState {
  final List<SshHostEntry> entries;
  final bool isLoading;
  final bool isSyncing;
  final String? message;

  const SshHostsState({
    this.entries = const [],
    this.isLoading = true,
    this.isSyncing = false,
    this.message,
  });

  int get lockedCount => entries.where((e) => e.isLocked).length;

  SshHostsState copyWith({
    List<SshHostEntry>? entries,
    bool? isLoading,
    bool? isSyncing,
    String? message,
  }) {
    return SshHostsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      message: message ?? this.message,
    );
  }
}

final sshHostsControllerProvider =
    NotifierProvider<SshHostsController, SshHostsState>(SshHostsController.new);

class SshHostsController extends Notifier<SshHostsState> {
  late SshRepository _repo;

  @override
  SshHostsState build() {
    _repo = ref.watch(sshRepositoryProvider);
    // Buka/kunci E2E mengubah apa yang bisa didekripsi -> muat ulang.
    ref.listen(e2eControllerProvider.select((s) => s.keyBytes), (_, _) => reload());
    Future.microtask(() async {
      await reload();
      await sync();
    });
    return const SshHostsState();
  }

  Future<void> reload() async {
    final records = await _repo.listRecords();
    final entries = <SshHostEntry>[];
    for (final r in records) {
      entries.add(SshHostEntry(r, await _repo.decode(r)));
    }
    state = state.copyWith(entries: entries, isLoading: false);
  }

  Future<void> sync() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);
    String? message;
    try {
      message = await _repo.sync();
    } catch (e) {
      message = 'Gagal sinkron: $e';
    }
    state = state.copyWith(isSyncing: false, message: message ?? '');
    await reload();
  }

  Future<void> save(SshHost host) async {
    await _repo.save(host);
    await reload();
    unawaited(sync());
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await reload();
    unawaited(sync());
  }

  SshHost? hostById(String id) {
    for (final e in state.entries) {
      if (e.id == id) return e.host;
    }
    return null;
  }
}
