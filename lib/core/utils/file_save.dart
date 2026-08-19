import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Outcome of a [saveBytesToDevice] call.
class SaveOutcome {
  const SaveOutcome({this.path, this.shared = false});

  /// Absolute path the file was written to (desktop). Null when [shared].
  final String? path;

  /// True when the bytes were handed to the mobile share sheet instead of a
  /// folder (mobile has no native "save to folder" dialog).
  final bool shared;
}

/// Persist [bytes] to the user's device the way a browser download does.
///
/// - **Desktop (Windows/macOS/Linux):** opens the native **Save As** dialog so
///   the user chooses the folder + filename, then writes the file there.
/// - **Mobile (Android/iOS):** hands the file to the system share sheet
///   (Files / Drive / …), since mobile has no folder picker.
///
/// Returns the [SaveOutcome], or `null` if the user cancelled the dialog.
Future<SaveOutcome?> saveBytesToDevice({
  required List<int> bytes,
  required String suggestedName,
  required String mimeType,
  required String typeLabel,
  required String extension,
}) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  // Mobile: no folder picker — share sheet lets the user save to Files/Drive.
  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$suggestedName');
    await file.writeAsBytes(data);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: suggestedName)],
      ),
    );
    return const SaveOutcome(shared: true);
  }

  // Desktop: real "Save As" dialog — choose folder + filename.
  final location = await fs.getSaveLocation(
    acceptedTypeGroups: [
      fs.XTypeGroup(
        label: typeLabel,
        extensions: [extension],
        mimeTypes: [mimeType],
      ),
    ],
    suggestedName: suggestedName,
  );
  if (location == null) return null; // cancelled

  await fs.XFile.fromData(
    data,
    mimeType: mimeType,
    name: suggestedName,
  ).saveTo(location.path);
  return SaveOutcome(path: location.path);
}
