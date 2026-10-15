import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A text file the user picked.
class PickedText {
  const PickedText({required this.name, required this.text});

  /// The file name without its extension, e.g. "Weekly shop".
  final String name;
  final String text;
}

/// Saving and opening text files, behind an interface so screens can be tested
/// without a real file dialog. Works on Windows and Android.
abstract class FileService {
  /// Asks where to save and writes [text]. Returns false if cancelled.
  Future<bool> saveText({required String fileName, required String text});

  /// Asks for a file and reads it as text. Null if cancelled.
  Future<PickedText?> pickText();
}

class PlatformFileService implements FileService {
  const PlatformFileService();

  @override
  Future<bool> saveText({
    required String fileName,
    required String text,
  }) async {
    // A byte-order mark so Excel reads accented characters correctly.
    final bytes = Uint8List.fromList(utf8.encode('﻿$text'));
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export list',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    return saved != null;
  }

  @override
  Future<PickedText?> pickText() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import a list',
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final dot = file.name.lastIndexOf('.');
    return PickedText(
      name: dot > 0 ? file.name.substring(0, dot) : file.name,
      text: utf8.decode(bytes, allowMalformed: true),
    );
  }
}

final fileServiceProvider = Provider<FileService>(
  (ref) => const PlatformFileService(),
);
