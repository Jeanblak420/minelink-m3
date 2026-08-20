import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/services/file_selection_service.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';

/// XFile.fromData only honours `name` on web, so fake at the PickedAppFile
/// level to control both the file name and its bytes.
class _FakePickedFile extends PickedAppFile {
  final String _name;
  final Uint8List _bytes;

  _FakePickedFile(this._name, this._bytes)
    : super(file: XFile.fromData(_bytes), isImage: false);

  @override
  String get name => _name;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;
}

/// Stands in for the OS file dialog: returns a canned list of files.
class _FakeFileSelectionService extends FileSelectionService {
  _FakeFileSelectionService(this.results);

  final List<PickedAppFile> results;
  List<String>? lastAllowedExtensions;

  @override
  Future<List<PickedAppFile>> pickFiles({
    required bool imagesOnly,
    required bool allowMultiple,
    List<String>? allowedExtensions,
  }) async {
    lastAllowedExtensions = allowedExtensions;
    return results;
  }
}

PickedAppFile _fakeFile(String name, {int size = 10}) {
  return _FakePickedFile(name, Uint8List(size));
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Taps the drop zone via its hint text (chips add their own InkWells, so
/// find.byType(InkWell) is ambiguous once files are listed).
Future<void> _tapDropZone(WidgetTester tester, String hint) async {
  await tester.tap(find.text(hint));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders label + hint and adds picked files as chips', (
    tester,
  ) async {
    final service = _FakeFileSelectionService([
      _fakeFile('a.pdf'),
      _fakeFile('b.pdf'),
    ]);
    var files = <PickedRequestFile>[];

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MultiFileDropPicker(
            label: 'Lab results / reports (PDF)',
            hint: 'Drag & drop PDFs here, or click to browse.',
            allowedExtensions: const ['pdf'],
            files: files,
            onChanged: (next) => setState(() => files = next),
            fileSelectionService: service,
          ),
        ),
      ),
    );

    expect(find.text('Lab results / reports (PDF)'), findsOneWidget);
    expect(find.textContaining('Drag & drop PDFs'), findsOneWidget);

    await _tapDropZone(tester, 'Drag & drop PDFs here, or click to browse.');

    expect(service.lastAllowedExtensions, ['pdf']);
    expect(files.map((f) => f.name), ['a.pdf', 'b.pdf']);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);
  });

  testWidgets(
    'rejects files with a disallowed extension and shows the reason',
    (tester) async {
      final service = _FakeFileSelectionService([_fakeFile('notes.txt')]);
      var changed = false;

      await tester.pumpWidget(
        _host(
          MultiFileDropPicker(
            label: 'Lab results',
            hint: 'Drop here',
            allowedExtensions: const ['pdf'],
            files: const [],
            onChanged: (_) => changed = true,
            fileSelectionService: service,
          ),
        ),
      );

      await _tapDropZone(tester, 'Drop here');

      expect(changed, isFalse);
      expect(find.text('notes.txt — not a PDF file'), findsOneWidget);
    },
  );

  testWidgets('rejects files above the size limit', (tester) async {
    final service = _FakeFileSelectionService([
      _fakeFile('big.pdf', size: 2 * 1024 * 1024),
    ]);
    var changed = false;

    await tester.pumpWidget(
      _host(
        MultiFileDropPicker(
          label: 'Lab results',
          hint: 'Drop here',
          allowedExtensions: const ['pdf'],
          maxSizeBytes: 1024 * 1024,
          files: const [],
          onChanged: (_) => changed = true,
          fileSelectionService: service,
        ),
      ),
    );

    await _tapDropZone(tester, 'Drop here');

    expect(changed, isFalse);
    expect(find.text('big.pdf — larger than 1 MB'), findsOneWidget);
  });

  testWidgets('single-file mode replaces the previous selection', (
    tester,
  ) async {
    final service = _FakeFileSelectionService([_fakeFile('new.png')]);
    var files = <PickedRequestFile>[
      PickedRequestFile(name: 'old.png', bytes: Uint8List(4)),
    ];

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MultiFileDropPicker(
            label: 'Picture',
            hint: 'Drop here',
            allowMultiple: false,
            allowedExtensions: const ['png'],
            files: files,
            onChanged: (next) => setState(() => files = next),
            fileSelectionService: service,
          ),
        ),
      ),
    );

    await _tapDropZone(tester, 'Drop here');

    expect(files.map((f) => f.name), ['new.png']);
    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('chip delete removes the file', (tester) async {
    var files = <PickedRequestFile>[
      PickedRequestFile(name: 'lab.pdf', bytes: Uint8List(4)),
    ];

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MultiFileDropPicker(
            label: 'Lab results',
            hint: 'Drop here',
            allowedExtensions: const ['pdf'],
            files: files,
            onChanged: (next) => setState(() => files = next),
            fileSelectionService: _FakeFileSelectionService(const []),
          ),
        ),
      ),
    );

    expect(find.byType(InputChip), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(files, isEmpty);
    expect(find.byType(InputChip), findsNothing);
  });
}
