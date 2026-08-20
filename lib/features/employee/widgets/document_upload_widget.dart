import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

enum DocumentType { idDocument, passport, workVisa, license }

class DocumentUploadWidget extends ConsumerStatefulWidget {
  final DocumentType documentType;
  final String? existingDocumentUrl;
  final bool enabled;

  const DocumentUploadWidget({
    super.key,
    required this.documentType,
    this.existingDocumentUrl,
    this.enabled = true,
  });

  @override
  ConsumerState<DocumentUploadWidget> createState() =>
      _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends ConsumerState<DocumentUploadWidget> {
  final _imagePicker = ImagePicker();
  bool _isUploading = false;
  String? _errorMessage;

  String get _documentTypeName {
    switch (widget.documentType) {
      case DocumentType.idDocument:
        return 'ID Document';
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.workVisa:
        return 'Work Visa';
      case DocumentType.license:
        return 'License Document';
    }
  }

  Future<void> _pickAndUploadDocument() async {
    if (!widget.enabled) return;

    try {
      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final fileName = pickedFile.name;

        String? documentUrl;

        switch (widget.documentType) {
          case DocumentType.idDocument:
            documentUrl = await ref
                .read(employeeProvider.notifier)
                .uploadIdDocument(bytes, fileName);
            break;
          case DocumentType.passport:
            documentUrl = await ref
                .read(employeeProvider.notifier)
                .uploadPassportDocument(bytes, fileName);
            break;
          case DocumentType.workVisa:
            documentUrl = await ref
                .read(employeeProvider.notifier)
                .uploadWorkVisaDocument(bytes, fileName);
            break;
          case DocumentType.license:
            documentUrl = await ref
                .read(employeeProvider.notifier)
                .uploadLicenseDocument(bytes, fileName);
            break;
        }

        if (documentUrl == null) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to upload document';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error. ${friendlyError(e)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _viewDocument() {
    if (widget.existingDocumentUrl != null) {
      // Launch URL to view document
      launchUrl(Uri.parse(widget.existingDocumentUrl!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = widget.existingDocumentUrl != null;
    final semantic = MlSemantic.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semantic.surfaceSunken,
        borderRadius: MlShape.radiusSmall,
        border: Border.all(color: semantic.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file, size: 20, color: semantic.textMuted),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  text: 'Upload photo of ',
                  children: [
                    TextSpan(
                      text: _documentTypeName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: widget.enabled ? _pickAndUploadDocument : null,
                  icon: _isUploading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MlTokens.accent,
                          ),
                        )
                      : Icon(Icons.add_a_photo),
                  label: Text(_isUploading ? 'Uploading...' : 'Choose File'),
                  style: FilledButton.styleFrom(
                    backgroundColor: semantic.surfaceSunken,
                    foregroundColor: semantic.textStrong,
                    disabledBackgroundColor: semantic.surfaceSunken,
                    disabledForegroundColor: semantic.textFaint,
                  ),
                ),
              ),
              if (hasDocument) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _viewDocument,
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('View'),
                  style: TextButton.styleFrom(foregroundColor: MlTokens.accent),
                ),
              ],
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: MlTokens.red600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper function to launch URLs
Future<void> launchUrl(Uri url) async {
  try {
    await url_launcher.launchUrl(
      url,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  } catch (e) {
    debugPrint('Could not launch $url: $e');
  }
}
