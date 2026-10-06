enum SyncStatus { local, syncing, synced, error }

class Note {
  final String id;
  final String? userId;
  final String title;
  final String content;
  final String fileExtension;
  final String? folder;
  final bool isPinned;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Note({
    required this.id,
    this.userId,
    this.title = 'Untitled',
    this.content = '',
    this.fileExtension = 'md',
    this.folder,
    this.isPinned = false,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.local,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? fileExtension,
    String? folder,
    bool clearFolder = false,
    bool? isPinned,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      fileExtension: fileExtension ?? this.fileExtension,
      folder: clearFolder ? null : (folder ?? this.folder),
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'file_extension': fileExtension,
      'folder': folder,
      'is_pinned': isPinned ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      title: map['title'] as String? ?? 'Untitled',
      content: map['content'] as String? ?? '',
      fileExtension: map['file_extension'] as String? ?? 'md',
      folder: map['folder'] as String?,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['sync_status'],
        orElse: () => SyncStatus.local,
      ),
    );
  }

  Map<String, dynamic> toPostgresJson() {
    final json = <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'file_extension': fileExtension,
      'folder': folder,
      'is_pinned': isPinned,
      'is_deleted': isDeleted,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
    return json;
  }

  factory Note.fromPostgresJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      content: json['content'] as String? ?? '',
      fileExtension: json['file_extension'] as String? ?? 'md',
      folder: json['folder'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      syncStatus: SyncStatus.synced,
    );
  }
}
