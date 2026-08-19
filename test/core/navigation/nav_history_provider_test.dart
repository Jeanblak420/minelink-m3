import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

NavLocation _home(int tab) => NavLocation(path: '/home', homeTabIndex: tab);
NavLocation _page(String path) => NavLocation(path: path);

void main() {
  late NavHistoryNotifier n;

  setUp(() => n = NavHistoryNotifier());

  test('starts empty and cannot go back', () {
    expect(n.state, isEmpty);
    expect(n.canGoBack, isFalse);
  });

  test('visiting root then a tab enables back', () {
    n.visit(_home(0), isRoot: true);
    expect(n.canGoBack, isFalse);
    n.visit(_home(1), isRoot: false);
    expect(n.canGoBack, isTrue);
    expect(n.state.length, 2);
  });

  test('consecutive duplicate visit is ignored', () {
    n.visit(_home(0), isRoot: true);
    n.visit(_home(1), isRoot: false);
    n.visit(_home(1), isRoot: false);
    expect(n.state.length, 2);
  });

  test('landing on root resets the stack', () {
    n.visit(_home(0), isRoot: true);
    n.visit(_home(1), isRoot: false);
    n.visit(_page('/profile'), isRoot: false);
    expect(n.state.length, 3);
    n.visit(_home(0), isRoot: true);
    expect(n.state, [_home(0)]);
    expect(n.canGoBack, isFalse);
  });

  test('popForBack returns previous and suppresses its re-record', () {
    n.visit(_home(0), isRoot: true);
    n.visit(_home(1), isRoot: false);
    final target = n.popForBack();
    expect(target, _home(0));
    expect(n.state, [_home(0)]);
    // The navigation back to target re-fires visit(); it must be ignored.
    n.visit(_home(0), isRoot: true);
    expect(n.state, [_home(0)]);
  });

  test('popForBack returns null when nothing to go back to', () {
    n.visit(_home(0), isRoot: true);
    expect(n.popForBack(), isNull);
  });

  test('stack is capped at maxEntries', () {
    n.visit(_home(0), isRoot: true);
    for (var i = 0; i < 100; i++) {
      n.visit(_page('/p$i'), isRoot: false);
    }
    expect(n.state.length, NavHistoryNotifier.maxEntries);
    expect(n.state.last, _page('/p99'));
  });

  test('fullLocation includes query string', () {
    expect(const NavLocation(path: '/n', query: {'title': 'Hi there'}).fullLocation,
        '/n?title=Hi%20there');
    expect(const NavLocation(path: '/home').fullLocation, '/home');
  });

  test('reset clears the stack and re-enables recording', () {
    n.visit(_home(0), isRoot: true);
    n.visit(_home(1), isRoot: false);
    n.reset();
    expect(n.state, isEmpty);
    expect(n.canGoBack, isFalse);
    // After reset, a fresh visit records normally (suppress flag cleared too).
    n.visit(_page('/profile'), isRoot: false);
    expect(n.state, [_page('/profile')]);
  });

  test('a non-root first visit keeps the stack at length 1 (back hidden)', () {
    n.visit(_page('/profile'), isRoot: false);
    expect(n.state, [_page('/profile')]);
    expect(n.canGoBack, isFalse);
  });

  test('reset clears a previously-set suppress flag', () {
    n.visit(_home(0), isRoot: true);
    n.visit(_home(1), isRoot: false);
    n.popForBack(); // sets the internal suppress flag
    n.reset();      // must clear it
    n.visit(_page('/x'), isRoot: false);
    expect(n.state, [_page('/x')]); // records normally => flag was cleared
  });
}
