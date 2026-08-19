import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/file_selection_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// A file upload widget that supports images and generic files.
class FileUploadWidget extends StatefulWidget {
  /// The bucket name in Supabase storage
  final String bucketName;

  /// The folder path within the bucket
  final String folderPath;

  /// The maximum file size in bytes
  final int maxSizeBytes;

  /// Whether to allow multiple files
  final bool allowMultiple;

  /// Whether to allow only images
  final bool imagesOnly;

  /// Callback when files are uploaded successfully
  final Function(List<String> fileUrls) onUploadComplete;

  /// Whether upload results should return storage paths instead of public URLs
  final bool returnStoragePath;

  /// Callback when an error occurs
  final Function(String error)? onError;

  /// The button text
  final String buttonText;

  /// The button icon
  final IconData buttonIcon;

  /// The button style
  final ButtonStyle? buttonStyle;

  /// Whether to show a preview of the selected files
  final bool showPreview;

  /// Whether to show the upload progress
  final bool showProgress;

  const FileUploadWidget({
    super.key,
    required this.bucketName,
    required this.folderPath,
    required this.onUploadComplete,
    this.maxSizeBytes = 10 * 1024 * 1024,
    this.allowMultiple = false,
    this.imagesOnly = true,
    this.onError,
    this.buttonText = 'Upload Image',
    this.buttonIcon = Icons.image,
    this.buttonStyle,
    this.showPreview = true,
    this.showProgress = true,
    this.returnStoragePath = false,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final _logger = LoggerFactory.getLogger('FileUploadWidget');
  final _supabase = SupabaseConfig.client;
  final _fileSelectionService = FileSelectionService();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  List<PickedAppFile> _selectedFiles = [];
  Map<String, Uint8List> _previewBytes = {};

  Future<void> _pickFiles() async {
    try {
      final pickedFiles = await _fileSelectionService.pickFiles(
        imagesOnly: widget.imagesOnly,
        allowMultiple: widget.allowMultiple,
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final previewBytes = <String, Uint8List>{};
      for (final pickedFile in pickedFiles.where((file) => file.isImage)) {
        previewBytes[pickedFile.name] = await pickedFile.readAsBytes();
      }

      if (mounted) {
        setState(() {
          _selectedFiles = pickedFiles;
          _previewBytes = previewBytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _logger.e('Error picking files', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error selecting files. ${friendlyError(e)}';
        });
      }
      if (widget.onError != null) {
        widget.onError!('Error selecting files. ${friendlyError(e)}');
      }
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _errorMessage = 'Please select files first';
      });
      if (widget.onError != null) {
        widget.onError!('Please select files first');
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final List<String> uploadedFiles = [];

      for (int i = 0; i < _selectedFiles.length; i++) {
        final selectedFile = _selectedFiles[i];
        final bytes = await selectedFile.readAsBytes();

        if (bytes.lengthInBytes > widget.maxSizeBytes) {
          throw Exception(
            'File ${selectedFile.name} exceeds maximum size of ${widget.maxSizeBytes / 1024 / 1024}MB',
          );
        }

        final safeFileName = _safeFileName(selectedFile.name);
        final fileName = '${const Uuid().v4()}_$safeFileName';
        final filePath = '${widget.folderPath}/$fileName';

        await _supabase.storage
            .from(widget.bucketName)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: _contentTypeFor(fileName),
              ),
            );

        final uploadedValue = widget.returnStoragePath
            ? filePath
            : _supabase.storage.from(widget.bucketName).getPublicUrl(filePath);
        uploadedFiles.add(uploadedValue);

        if (mounted) {
          setState(() {
            _uploadProgress = (i + 1) / _selectedFiles.length;
          });
        }
      }

      widget.onUploadComplete(uploadedFiles);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedFiles = [];
          _previewBytes = {};
        });
      }
    } catch (e) {
      _logger.e('Error uploading files', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error uploading files. ${friendlyError(e)}';
          _isUploading = false;
        });
      }
      if (widget.onError != null) {
        widget.onError!('Error uploading files. ${friendlyError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickFiles,
              icon: Icon(widget.buttonIcon),
              label: Text(widget.buttonText),
              style: widget.buttonStyle,
            ),
            const SizedBox(width: 16),
            if (_selectedFiles.isNotEmpty)
              FilledButton.icon(
                onPressed: _isUploading ? null : _uploadFiles,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),

        if (_isUploading && widget.showProgress)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _uploadProgress),
              ],
            ),
          ),

        if (widget.showPreview && _selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: _buildPreview(),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          final selectedFile = _selectedFiles[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: selectedFile.isImage
                ? _buildImagePreview(selectedFile)
                : _buildFilePreview(context, selectedFile),
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(PickedAppFile selectedFile) {
    final bytes = _previewBytes[selectedFile.name];
    if (bytes == null) {
      return const SizedBox(
        width: 100,
        child: Center(child: Icon(Icons.image)),
      );
    }

    return Image.memory(bytes, height: 100, width: 100, fit: BoxFit.cover);
  }

  Widget _buildFilePreview(BuildContext context, PickedAppFile selectedFile) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconForFile(selectedFile.name),
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(selectedFile.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  String _safeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _contentTypeFor(String fileName) {
    switch (_extensionFor(fileName)) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _iconForFile(String fileName) {
    switch (_extensionFor(fileName)) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.attach_file;
    }
  }

  String _extensionFor(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
