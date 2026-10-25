// The phone top bar never breaks a word in the page title.
//
// Found on Jean's SM-G780G on 2026-08-23, at his raised system font: the Load
// Controller's bar — drawer, title, FOUR actions — gave the title a column
// narrower than the word "controller", and Flutter broke it:
//
//     Load co
//     ntroller
//
// and on the next screen `Compli` over `ance`. Two lines had already been
// allowed; they cannot help a single word that is wider than the column.
//
// The fix is Material 3's medium top app bar: when the title cannot sit
// beside the icons on two lines without splitting a word, it drops onto its
// own full-width row under them. Short titles keep the 72px bar.
//
// Sabotage: make `titleNeedsOwnRow` always false in `MlAppShell._buildTopBar`
// and the first case fails — `controller` lands on two different lines. The
// second case stays green under that sabotage, and FAILS if the fallback is
// made unconditional, which is how the fix is proven not to have gone too far.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

import '../test_helpers/real_fonts.dart';

final _tree = <MlNavNode>[
  const MlNavNode.leaf(label: 'Dashboard', icon: Icons.dashboard, route: '/a'),
  const MlNavNode.leaf(label: 'Second', icon: Icons.list, route: '/b'),
];

/// The Load Controller's bar on a 412px phone: drawer + back, and four
/// actions — the shape that broke the word on glass.
Widget _phone(String title, {required double scale, int actions = 4}) =>
    MediaQuery(
      data: MediaQueryData(
        size: const Size(412, 915),
        textScaler: TextScaler.linear(scale),
      ),
      child: MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: MlAppShell(
          tree: _tree,
          selectedRoute: '/a',
          onNavigate: (_) {},
          title: title,
          leading: const BackButton(),
          actions: [
            for (final icon in const [
              Icons.help_outline_rounded,
              Icons.campaign_outlined,
              Icons.notifications_outlined,
              Icons.more_vert,
            ].take(actions))
              IconButton(onPressed: () {}, icon: Icon(icon)),
          ],
          child: const SizedBox.expand(),
        ),
      ),
    );

/// The distinct line tops the characters [start]..[end] of [text] sit on.
Set<double> _lineTopsOf(WidgetTester tester, String text, int start, int end) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  return {for (final b in boxes) b.top.roundToDouble()};
}

void main() {
  setUpAll(loadRealFonts);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1.0;
  });

  testWidgets('"Load controller" at a raised scale keeps its word whole',
      (tester) async {
    await tester.pumpWidget(_phone('Load controller', scale: 1.6));
    await tester.pumpAndSettle();

    const title = 'Load controller';
    final word = title.indexOf('controller');
    final tops = _lineTopsOf(tester, title, word, word + 'controller'.length);
    expect(tops, hasLength(1),
        reason: '"controller" must sit on ONE line — it was rendered as '
            '"Load co" over "ntroller" on the handset');

    final paragraph =
        tester.renderObject<RenderParagraph>(find.text(title));
    expect(paragraph.didExceedMaxLines, isFalse,
        reason: 'the title is never ellipsised on a phone');

    // The headline took its own row UNDER the icons — M3's medium bar.
    final titleRect = tester.getRect(find.text(title));
    expect(titleRect.top, greaterThanOrEqualTo(MlTokens.appBarHeight - 1),
        reason: 'the title moved below the 72px icon row');
    expect(titleRect.left, closeTo(16, 1),
        reason: 'and starts at the bar\'s left padding, not beside the icons');
  });

  // On Jean's S25 Ultra (411dp, system font 1.3, 2026-10-25) "My profile" fit
  // beside the four icons only by wrapping: "My" over "profile", squeezed into
  // the bar between the back arrow and the chat icon, while the pages either
  // side of it carried their titles on the row below. Two lines beside the
  // icons was the answer before the own row existed; with it, a title that
  // needs a second line takes the row.
  testWidgets('a title that would wrap beside the icons takes its own row',
      (tester) async {
    await tester.pumpWidget(_phone('My profile', scale: 1.3));
    await tester.pumpAndSettle();

    final titleRect = tester.getRect(find.text('My profile'));
    expect(titleRect.top, greaterThanOrEqualTo(MlTokens.appBarHeight - 1),
        reason: 'it was wrapped onto two lines inside the icon row');
    expect(_lineTopsOf(tester, 'My profile', 0, 'My profile'.length),
        hasLength(1),
        reason: 'on its own row it reads on one line');
  });

  testWidgets('a short title stays beside the icons in the 72px bar',
      (tester) async {
    // The console's phone bar: drawer + back and TWO actions. `Overview`
    // rather than `Dashboard`, which is also a bottom-nav label here.
    await tester.pumpWidget(_phone('Overview', scale: 1.0, actions: 2));
    await tester.pumpAndSettle();

    final titleRect = tester.getRect(find.text('Overview'));
    expect(titleRect.bottom, lessThanOrEqualTo(MlTokens.appBarHeight),
        reason: 'a title that fits keeps the small bar');
    expect(_lineTopsOf(tester, 'Overview', 0, 'Overview'.length),
        hasLength(1));
  });
}
