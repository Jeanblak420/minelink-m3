import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:image_picker/image_picker.dart';

class PickedAppFile {
  final XFile file;
  final bool isImage;

  const PickedAppFile({required this.file, required this.isImage});

  String get name => file.name;

  Future<Uint8List> readAsBytes() => file.readAsBytes();
}

class FileSelectionService {
  final ImagePicker _imagePicker;
  final _logger = LoggerFactory.getLogger('FileSelectionService');

  FileSelectionService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  Future<List<PickedAppFile>> pickFiles({
    required bool imagesOnly,
    required bool allowMultiple,
    List<String>? allowedExtensions,
  }) async {
    if (imagesOnly) {
      return _pickImages(allowMultiple: allowMultiple);
    }

    return _pickGenericFiles(
      allowMultiple: allowMultiple,
      allowedExtensions: allowedExtensions,
    );
  }

  Future<List<PickedAppFile>> _pickImages({required bool allowMultiple}) async {
    try {
      if (allowMultiple) {
        final files = await _imagePicker.pickMultiImage();
        return files
            .map((file) => PickedAppFile(file: file, isImage: true))
            .toList(growable: false);
      }

      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        return const [];
      }

      return [PickedAppFile(file: file, isImage: true)];
    } catch (error, stackTrace) {
      _logger.e('Error selecting images', error, stackTrace);
      rethrow;
    }
  }

  Future<List<PickedAppFile>> _pickGenericFiles({
    required bool allowMultiple,
    List<String>? allowedExtensions,
  }) async {
    try {
      final typeGroups = (allowedExtensions == null || allowedExtensions.isEmpty)
          ? const <file_selector.XTypeGroup>[]
          : [
              file_selector.XTypeGroup(
                label: allowedExtensions.map((e) => e.toUpperCase()).join('/'),
                extensions: allowedExtensions,
              ),
            ];

      if (allowMultiple) {
        final files = await file_selector.openFiles(
          confirmButtonText: 'Select',
          acceptedTypeGroups: typeGroups,
        );
        return files
            .map(
              (file) =>
                  PickedAppFile(file: file, isImage: _isImageFile(file.name)),
            )
            .toList(growable: false);
      }

      final file = await file_selector.openFile(
        confirmButtonText: 'Select',
        acceptedTypeGroups: typeGroups,
      );
      if (file == null) {
        return const [];
      }

      return [PickedAppFile(file: file, isImage: _isImageFile(file.name))];
    } catch (error, stackTrace) {
      _logger.e('Error selecting files', error, stackTrace);
      rethrow;
    }
  }

  bool _isImageFile(String fileName) {
    final extension = _extensionFor(fileName);
    return {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'heic',
      'heif',
    }.contains(extension);
  }

  String _extensionFor(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
