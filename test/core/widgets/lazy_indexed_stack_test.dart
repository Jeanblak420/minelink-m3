import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/widgets/lazy_indexed_stack.dart';

class _Field extends StatefulWidget {
  const _Field({super.key});
  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final controller = TextEditingController();
  @override
  Widget build(BuildContext context) => TextField(controller: controller);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

void main() {
  Widget host(int index) => MaterialApp(
        home: Scaffold(
          body: LazyIndexedStack(
            index: index,
            children: const [_Field(key: ValueKey('a')), _Field(key: ValueKey('b'))],
          ),
        ),
      );

  testWidgets('preserves input of a visited child across index changes',
      (tester) async {
    await tester.pumpWidget(host(0));
    await tester.enterText(find.byType(TextField), 'half typed');
    await tester.pump();

    await tester.pumpWidget(host(1)); // switch away
    await tester.pumpWidget(host(0)); // come back

    expect(find.text('half typed'), findsOneWidget);
  });

  testWidgets('does not build a child until first visited', (tester) async {
    await tester.pumpWidget(host(0));
    // Child 'b' not visited yet -> its State should not exist.
    expect(find.byKey(const ValueKey('b')), findsNothing);
    await tester.pumpWidget(host(1));
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
  });

  testWidgets('forgets a visited index after the children list shrinks',
      (tester) async {
    Widget hostN(int index, int count) => MaterialApp(
          home: Scaffold(
            body: LazyIndexedStack(
              index: index,
              children: [
                for (var i = 0; i < count; i++)
                  _Field(key: ValueKey('f$i')),
              ],
            ),
          ),
        );

    await tester.pumpWidget(hostN(1, 2)); // visit index 1
    expect(find.byKey(const ValueKey('f1')), findsOneWidget);

    await tester.pumpWidget(hostN(0, 1)); // list shrinks to 1 child
    await tester.pumpWidget(hostN(0, 2)); // grows back, index 1 not selected
    // index 1 was forgotten on shrink, so it is deferred again (placeholder).
    expect(find.byKey(const ValueKey('f1')), findsNothing);
  });
}
