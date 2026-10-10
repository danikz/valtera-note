import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  /// true selama catatan yang sudah ada sedang dimuat dari DB lokal.
  final bool isLoading;

  /// Konten masih terenkripsi (E2E terkunci / kunci tidak cocok): editor
  /// read-only agar ciphertext tidak tersimpan sebagai teks hasil editan.
  final bool isEncryptedLocked;

  const NoteEditorState({
    required this.note,
    this.isSaving = false,
    this.isDirty = false,
    this.isDeleted = false,
    this.isLoading = false,
    this.isEncryptedLocked = false,
  });

  NoteEditorState copyWith({
    Note? note,
    bool? isSaving,
    bool? isDirty,
    bool? isDeleted,
    bool? isLoading,
    bool? isEncryptedLocked,
  }) {
    return NoteEditorState(
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      isDeleted: isDeleted ?? this.isDeleted,
      isLoading: isLoading ?? this.isLoading,
      isEncryptedLocked: isEncryptedLocked ?? this.isEncryptedLocked,
    );
  }
}

final noteEditorControllerProvider =
    NotifierProvider.autoDispose.family<NoteEditorController, NoteEditorState, String?>(
  (arg) => NoteEditorController(arg),
);

class NoteEditorController extends Notifier<NoteEditorState> {
  final String? initialNoteId;
  NoteEditorController(this.initialNoteId);

  late final NotesRepository _repo;
  late final SyncEngine _syncEngine;
  Timer? _debounceTimer;
  bool _disposed = false;
  // Salinan catatan yang menunggu autosave — `state` tidak boleh dibaca di onDispose.
  Note? _pendingAutoSave;

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

    final isExisting =
        initialNoteId != null && initialNoteId!.isNotEmpty && initialNoteId != 'new';
    if (isExisting) {
      _loadExistingNote(initialNoteId!);
    }

    ref.onDispose(() {
      _disposed = true;
      // Editan yang masih menunggu debounce jangan hilang saat layar ditutup.
      final pending = _pendingAutoSave;
      if ((_debounceTimer?.isActive ?? false) &&
          pending != null &&
          (pending.title.trim().isNotEmpty || pending.content.trim().isNotEmpty)) {
        _debounceTimer!.cancel();
        _persist(pending);
      }
    });

    return NoteEditorState(note: initialNote, isLoading: isExisting);
  }

  Future<void> _loadExistingNote(String id) async {
    final existing = await _repo.getNoteById(id);
    if (_disposed) return;
    if (existing == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    var note = existing;
    final e2e = ref.read(e2eControllerProvider);
    final crypto = ref.read(cryptoServiceProvider);
    if (crypto.isEncrypted(note.content) && e2e.isUnlocked) {
      try {
        final decrypted = await crypto.decrypt(e2e.keyBytes!, note.content);
        note = note.copyWith(content: decrypted);
      } catch (_) {}
    }
    if (_disposed) return;
    state = state.copyWith(
      note: note,
      isLoading: false,
      isEncryptedLocked: crypto.isEncrypted(note.content),
    );
  }

  /// Editan diabaikan selama catatan dimuat atau masih terenkripsi.
  bool get _editable => !state.isLoading && !state.isEncryptedLocked;

  void updateTitle(String title) {
    if (!_editable) return;
    final updated = state.note.copyWith(
      title: title,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    _scheduleAutoSave();
  }

  void updateContent(String content) {
    if (!_editable) return;
    final updated = state.note.copyWith(
      content: content,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    _scheduleAutoSave();
  }

  void togglePin() {
    if (!_editable) return;
    final updated = state.note.copyWith(
      isPinned: !state.note.isPinned,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    state = state.copyWith(note: updated, isDirty: true);
    saveImmediately();
  }

  void updateFolder(String? folder) {
    if (!_editable) return;
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
    _pendingAutoSave = state.note;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      saveImmediately();
    });
  }

  Future<void> saveImmediately() async {
    _debounceTimer?.cancel();
    _pendingAutoSave = null;
    // Tidak ada perubahan (atau masih memuat / terenkripsi) -> jangan menulis
    // ulang catatan; mencegah salinan kosong/basi menimpa data.
    if (!state.isDirty || !_editable) return;

    final snapshot = state.note;
    if (snapshot.title.trim().isEmpty && snapshot.content.trim().isEmpty) {
      return;
    }

    state = state.copyWith(isSaving: true);
    final saved = await _persist(snapshot);
    if (_disposed) return;

    // User bisa terus mengetik selama await: hanya bersihkan status dirty bila
    // catatan belum berubah sejak snapshot — jangan timpa ketikan baru.
    if (identical(state.note, snapshot)) {
      state = state.copyWith(note: saved, isSaving: false, isDirty: false);
    } else {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<Note> _persist(Note note) async {
    final toSave = note.copyWith(
      updatedAt: DateTime.now().toUtc(),
      syncStatus: SyncStatus.local,
    );
    await _repo.saveNote(toSave);
    await _syncEngine.enqueueAndSync(note: toSave, operation: 'update');
    return toSave;
  }

  Future<void> deleteNote() async {
    _debounceTimer?.cancel();
    if (state.isLoading) return;
    await _repo.deleteNote(state.note.id);
    await _syncEngine.enqueueAndSync(note: state.note, operation: 'delete');
    state = state.copyWith(isDeleted: true);
  }
}
