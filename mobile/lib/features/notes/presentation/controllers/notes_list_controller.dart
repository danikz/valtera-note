import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../setup/data/repositories/setup_repository.dart';
import '../../../sync/domain/sync_engine.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../../data/repositories/notes_repository_impl.dart';

class NotesListState {
  final bool isLoading;
  final List<Note> notes;
  final String? errorMessage;
  final String? selectedFolder;
  final List<String> customFolders;

  static const List<String> defaultFolders = [
    'Personal',
    'Work',
    'Projects',
    'SQL Queries',
  ];

  const NotesListState({
    this.isLoading = false,
    this.notes = const [],
    this.errorMessage,
    this.selectedFolder,
    this.customFolders = const [],
  });

  List<String> get availableFolders {
    final set = <String>{...defaultFolders, ...customFolders};
    for (final note in notes) {
      if (note.folder != null && note.folder!.trim().isNotEmpty) {
        set.add(note.folder!.trim());
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<Note> get filteredNotes {
    if (selectedFolder == null) {
      return notes;
    }
    return notes.where((n) => n.folder == selectedFolder).toList();
  }

  List<Note> get pinnedFilteredNotes =>
      filteredNotes.where((n) => n.isPinned).toList();

  List<Note> get otherFilteredNotes =>
      filteredNotes.where((n) => !n.isPinned).toList();

  List<Note> get pinnedNotes => notes.where((n) => n.isPinned).toList();
  List<Note> get otherNotes => notes.where((n) => !n.isPinned).toList();

  int countForFolder(String? folder) {
    if (folder == null) return notes.length;
    return notes.where((n) => n.folder == folder).length;
  }

  NotesListState copyWith({
    bool? isLoading,
    List<Note>? notes,
    String? errorMessage,
    String? selectedFolder,
    bool clearSelectedFolder = false,
    List<String>? customFolders,
  }) {
    return NotesListState(
      isLoading: isLoading ?? this.isLoading,
      notes: notes ?? this.notes,
      errorMessage: errorMessage,
      selectedFolder:
          clearSelectedFolder ? null : (selectedFolder ?? this.selectedFolder),
      customFolders: customFolders ?? this.customFolders,
    );
  }
}

final notesListControllerProvider =
    NotifierProvider<NotesListController, NotesListState>(NotesListController.new);

class NotesListController extends Notifier<NotesListState> {
  late final NotesRepository _repo;
  late final SyncEngine _syncEngine;
  late final SecureStorageService _storage;

  @override
  NotesListState build() {
    _repo = ref.watch(notesRepositoryProvider);
    _syncEngine = ref.watch(syncEngineProvider);
    _storage = ref.watch(secureStorageServiceProvider);

    // Listen to E2E unlock event to decrypt notes in real-time
    ref.listen(e2eControllerProvider, (prev, next) {
      if ((prev == null || !prev.isUnlocked) && next.isUnlocked) {
        _onE2eUnlocked(next.keyBytes!);
      }
    });

    _loadCustomFolders();
    loadNotes();
    _autoSyncOnLaunch();
    return const NotesListState(isLoading: true);
  }

  Future<void> _loadCustomFolders() async {
    final folders = await _storage.getCustomFolders();
    state = state.copyWith(customFolders: folders);
  }

  Future<void> _autoSyncOnLaunch() async {
    await _syncEngine.syncAll(silent: true);
    await loadNotes();
  }

  Future<void> _onE2eUnlocked(List<int> keyBytes) async {
    await _syncEngine.decryptExistingLocalNotes(keyBytes);
    await loadNotes();
  }

  Future<void> loadNotes() async {
    try {
      final notes = await _repo.getNotes();
      state = state.copyWith(isLoading: false, notes: notes, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() async {
    // 1. Sync with cloud
    await _syncEngine.syncAll();
    // 2. Reload local notes
    await loadNotes();
  }

  void selectFolder(String? folder) {
    state = state.copyWith(
      selectedFolder: folder,
      clearSelectedFolder: folder == null,
    );
  }

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final currentCustom = List<String>.from(state.customFolders);
    if (!currentCustom.contains(trimmed) &&
        !NotesListState.defaultFolders.contains(trimmed)) {
      currentCustom.add(trimmed);
      await _storage.saveCustomFolders(currentCustom);
    }

    state = state.copyWith(
      customFolders: currentCustom,
      selectedFolder: trimmed,
      clearSelectedFolder: false,
    );
  }

  Future<void> deleteFolder(String name) async {
    final currentCustom = List<String>.from(state.customFolders)..remove(name);
    await _storage.saveCustomFolders(currentCustom);

    // Notes in this folder get reset to folder = null
    final affectedNotes = state.notes.where((n) => n.folder == name).toList();
    for (final note in affectedNotes) {
      // copyWith(folder: null) diabaikan (null = "tidak diubah") — wajib clearFolder.
      final updated = note.copyWith(
        clearFolder: true,
        syncStatus: SyncStatus.local,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repo.saveNote(updated);
      await _syncEngine.enqueueAndSync(note: updated, operation: 'update');
    }

    state = state.copyWith(
      customFolders: currentCustom,
      clearSelectedFolder: state.selectedFolder == name,
      selectedFolder: state.selectedFolder == name ? null : state.selectedFolder,
    );
    await loadNotes();
  }

  Future<void> renameFolder(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;

    final currentCustom = List<String>.from(state.customFolders);
    final idx = currentCustom.indexOf(oldName);
    if (idx != -1) {
      currentCustom[idx] = trimmed;
    } else {
      currentCustom.add(trimmed);
    }
    await _storage.saveCustomFolders(currentCustom);

    final affectedNotes = state.notes.where((n) => n.folder == oldName).toList();
    for (final note in affectedNotes) {
      final updated = note.copyWith(
        folder: trimmed,
        syncStatus: SyncStatus.local,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repo.saveNote(updated);
      await _syncEngine.enqueueAndSync(note: updated, operation: 'update');
    }

    state = state.copyWith(
      customFolders: currentCustom,
      selectedFolder:
          state.selectedFolder == oldName ? trimmed : state.selectedFolder,
    );
    await loadNotes();
  }

  Future<void> togglePin(String id) async {
    await _repo.togglePin(id);
    final note = await _repo.getNoteById(id);
    if (note != null) {
      await _syncEngine.enqueueAndSync(note: note, operation: 'update');
    }
    await loadNotes();
  }

  Future<void> deleteNote(String id) async {
    final note = await _repo.getNoteById(id);
    await _repo.deleteNote(id);
    if (note != null) {
      await _syncEngine.enqueueAndSync(note: note, operation: 'delete');
    }
    await loadNotes();
  }
}
