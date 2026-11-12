// Describe an attached file and its owning entry without opening or playing the file

class MediaAttachment {
  final int? id;
  final int? entryId;
  final String fileType; // 'Photo', 'video', 'audio', 'document'
  final String fileName;
  // Keep a user label separate from the original filename and storage path
  final String? displayName;
  String get audioTitle =>
      displayName?.trim().isNotEmpty == true ? displayName! : fileName;
  // Store a reference to the file rather than loading its bytes into the entity
  final String localPath;
  final String? mimeType;
  final int? fileSize;

  // The constructor name must exactly match the class name
  const MediaAttachment({
    this.id,
    this.entryId,
    required this.fileType,
    required this.fileName,
    required this.localPath,
    this.mimeType,
    this.fileSize,
    this.displayName,
  });
  MediaAttachment withDisplayName(String name) => MediaAttachment(
    id: id,
    entryId: entryId,
    fileType: fileType,
    fileName: fileName,
    localPath: localPath,
    mimeType: mimeType,
    fileSize: fileSize,
    displayName: name.trim(),
  );
}
