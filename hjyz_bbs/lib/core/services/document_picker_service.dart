import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class PickedDocument {
  final String path;
  final String name;
  final int size;
  final String? mimeType;
  final bool temporary;

  const PickedDocument({
    required this.path,
    required this.name,
    required this.size,
    this.mimeType,
    this.temporary = false,
  });
}

class DocumentPickerService {
  DocumentPickerService._();

  static final DocumentPickerService instance = DocumentPickerService._();

  static const _channel = MethodChannel(
    'com.qingtan.hjyzbbs/document_picker',
  );

  Future<PickedDocument?> pick({
    String mimeType = '*/*',
    List<String> mimeTypes = const [],
    List<String> allowedExtensions = const [],
  }) async {
    if (Platform.isAndroid) {
      try {
        final value = await _channel.invokeMapMethod<String, dynamic>(
          'pickDocument',
          {
            'mimeType': mimeType,
            'mimeTypes': mimeTypes,
          },
        );
        if (value == null) return null;
        final path = value['path']?.toString() ?? '';
        if (path.isEmpty) return null;
        return PickedDocument(
          path: path,
          name: value['name']?.toString() ?? path.split('/').last,
          size: int.tryParse(value['size']?.toString() ?? '') ?? 0,
          mimeType: value['mimeType']?.toString(),
          temporary: value['temporary'] == true,
        );
      } on PlatformException {
        return null;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions:
          allowedExtensions.isEmpty ? null : allowedExtensions,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return PickedDocument(
      path: path,
      name: file.name,
      size: file.size,
    );
  }
}
