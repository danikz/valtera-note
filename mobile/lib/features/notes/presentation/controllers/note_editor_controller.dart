import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../../sync/domain/sync_engine.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../../data/repositories/notes_repository_impl.dart';

class NoteEditorState {
  final Note note;
  final bool isSaving;
  final bool isDirty;
  final bool isDeleted;

  const NoteEditorState({
    required this.note,
    this.isSaving = false,
    this.isDirty = false,
    this.isDeleted = false,
  });

  NoteEditorState copyWith({
    Note? note,
    bool? isSaving,
    bool? isDirty,
    bool? isDeleted,
  }) {
    return NoteEditorState(
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

final noteEditorControllerProvider =
    NotifierProvider.family<NoteEditorController, NoteEditorState, String?>(
  (arg) => NoteEditorController(arg),
);

class NoteEditorController extends Notifier<NoteEditorState> {
  final String? initialNoteId;
  NoteEditorController(this.initialNoteId);

  late final NotesRepository _repo;
  late final SyncEngine _syncEngine;
  Timer? _debounceTimer;

  @override
  NoteEditorState build() {
    _repo = ref.watch(notesRepositoryProvider);
    _syncEngine = ref.watch(syncEngineProvider);

    final initialNote = Note(
      id: (initialNoteId != null && initialNoteId!.isNotEmpty && initialNoteId != 'new')
          ? initialNoteId!
          : const Uuid().v4(),
      title: '',
      content: '',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    if (initialNoteId != null && initialNoteId!.isNotEmpty && initialNoteId != 'new') {
      _loadExistingNote(initialNoteId!);
    }

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    return NoteEditorState(note: initialNote);
  }

  Future<void> _loadExistingNote(String id) async {
    final existing = await _repo.getNoteById(id);
    if (existing != null) {
      var note = existing;
      final e2e = ref.read(e2eControllerProvider);
      final crypto = ref.read(cryptoServiceProvider);
      if (crypto.isEncrypted(note.content) && e2e.isUnlocked) {
        try {
          final decrypted = await crypto.decrypt(e2e.keyBytes!, note.content);
          note = note.copyWith(content: decrypted);
        } catch (_) {}
      }
      state = state.copyWith(note: note);
    }
  }

  void updateTitle(String title) {
    final updated = state.note.copyWith(
      title: title,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    _scheduleAutoSave();
  }

  void updateContent(String content) {
    final updated = state.note.copyWith(
      content: content,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    _scheduleAutoSave();
  }

  void togglePin() {
    final updated = state.note.copyWith(
      isPinned: !state.note.isPinned,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    saveImmediately();
  }

  void updateFolder(String? folder) {
    final updated = state.note.copyWith(
      folder: folder,
      clearFolder: folder == null,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      saveImmediately();
    });
  }

  Future<void> saveImmediately() async {
    _debounceTimer?.cancel();

    // Do not save if title and content are both empty
    if (state.note.title.trim().isEmpty && state.note.content.trim().isEmpty) {
      return;
    }

    state = state.copyWith(isSaving: true);

    final toSave = state.note.copyWith(
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );

    await _repo.saveNote(toSave);
    await _syncEngine.enqueueAndSync(note: toSave, operation: 'update');

    state = state.copyWith(
      note: toSave,
      isSaving: false,
      isDirty: false,
    );
  }

  Future<void> deleteNote() async {
    _debounceTimer?.cancel();
    await _repo.deleteNote(state.note.id);
    await _syncEngine.enqueueAndSync(note: state.note, operation: 'delete');
    state = state.copyWith(isDeleted: true);
  }
}
