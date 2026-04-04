import 'dart:io';
import 'package:flutter/material.dart';

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

  int get fileSizeBytes => file.lengthSync();

  double get fileSizeMB => fileSizeBytes / (1024 * 1024);

  int getFileSizeKB() => fileSizeBytes ~/ 1024;

  String getFormattedFileSize() {
    if (fileSizeMB >= 1) {
      return '${fileSizeMB.toStringAsFixed(1)} MB';
    } else {
      return '${getFileSizeKB()} KB';
    }
  }

  bool isSupportedType() {
    final supportedTypes = [
      'pdf',
      'txt',
      'doc',
      'docx',
      'ppt',
      'pptx',
      'xls',
      'xlsx',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'mp3',
      'mp4',
      'wav',
      'avi',
    ];
    final ext = fileName.split('.').last.toLowerCase();
    return supportedTypes.contains(ext);
  }

  Future<bool> isReadable() async {
    try {
      await file.readAsBytes();
      return true;
    } catch (e) {
      return false;
    }
  }

  String getMimeType() {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'wav':
        return 'audio/wav';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  IconData getFileIcon() {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.text_snippet;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp3':
      case 'wav':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }
}
