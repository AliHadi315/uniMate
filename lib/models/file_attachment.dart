import 'dart:io';

class FileAttachment {
  final String fileName;
  final String filePath;
  final File file;
  final String fileType;

  FileAttachment({
    required this.fileName,
    required this.filePath,
    required this.file,
    required this.fileType,
  });

  int getFileSizeKB() => file.lengthSync() ~/ 1024;

  bool isSupportedType() {
    final supportedTypes = [
      'pdf',
      'txt',
      'doc',
      'docx',
      'jpg',
      'jpeg',
      'png',
      'gif',
    ];
    final ext = fileName.split('.').last.toLowerCase();
    return supportedTypes.contains(ext);
  }
}
