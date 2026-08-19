# App-wide Back Button — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every screen, for every role, a working Back button that steps the user back through the screens/tabs they actually visited (hidden on the main Dashboard/Overview), preserve in-progress tab input within a session, and remove the redundant header "«" collapse toggle.

**Architecture:** A custom Riverpod navigation-history stack (`navHistoryProvider`) records each distinct screen the user lands on — including index-based sidebar-tab switches and `context.go` page changes. A recorder widget in each shell feeds it; the existing `AppNavigationBackButton` and the shells' `PopScope` read it to navigate back. The `/home` tab host becomes a lazy keep-alive `IndexedStack` so visited tabs retain their state in memory.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`, `StateNotifierProvider`), Go Router (`go_router`). Package name: `flutter_application_1`. Tests use `flutter_test`; run with `flutter test`.

## Global Constraints

- Package import root is `package:flutter_application_1/...` (exact).
- Navigation between pages uses `context.go(...)` (replace semantics) and sidebar tabs use `portalTabIndexProvider` (an index `StateProvider<int>` defaulting to 0). Do NOT convert call-sites to `context.push` or restructure routing.
- Back is **navigation-only**: never submit, cancel, clear, or mutate any data.
- Phase 1 is in-memory only. Do NOT add disk persistence, logout prompts, or on-launch resume prompts — those are Phase 2.
- Root screen = the main Dashboard/Overview landing screen: portal = `/home` with tab index `0`; super-admin = `/super-admin`.
- Keep each shell's **sidebar** collapse toggle. Only the **header** "«" toggle is removed.

---

### Task 1: Navigation history provider (pure logic)

**Files:**
- Create: `lib/core/navigation/nav_history_provider.dart`
- Test: `test/core/navigation/nav_history_provider_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart + Riverpod).
- Produces:
  - `class NavLocation { final String path; final Map<String,String> query; final int? homeTabIndex; const NavLocation({required this.path, this.query = const {}, this.homeTabIndex}); String get fullLocation; }` with value equality over `(path, query, homeTabIndex)`.
  - `class NavHistoryNotifier extends StateNotifier<List<NavLocation>>` with:
    - `static const int maxEntries = 50;`
    - `bool get canGoBack` → `state.length > 1`
    - `void visit(NavLocation location, {required bool isRoot})`
    - `NavLocation? popForBack()` → new top (target), or null; sets internal suppress flag
    - `void reset()`
  - `final navHistoryProvider = StateNotifierProvider<NavHistoryNotifier, List<NavLocation>>((ref) => NavHistoryNotifier());`

- [ ] **Step 1: Write the failing test**

Create `test/core/navigation/nav_history_provider_test.dart`:

```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/navigation/nav_history_provider_test.dart`
Expected: FAIL — `nav_history_provider.dart` / `NavLocation` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/navigation/nav_history_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One distinct screen the user has visited. Identity is value-based over
/// (path, query, homeTabIndex) so consecutive duplicate visits are detectable.
class NavLocation {
  final String path;
  final Map<String, String> query;

  /// Sidebar tab index when [path] == '/home'; null otherwise.
  final int? homeTabIndex;

  const NavLocation({
    required this.path,
    this.query = const {},
    this.homeTabIndex,
  });

  /// Path + query string suitable for `context.go(...)`.
  String get fullLocation {
    if (query.isEmpty) return path;
    final qs = query.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$path?$qs';
  }

  @override
  bool operator ==(Object other) =>
      other is NavLocation &&
      other.path == path &&
      other.homeTabIndex == homeTabIndex &&
      _mapEquals(other.query, query);

  @override
  int get hashCode => Object.hash(
        path,
        homeTabIndex,
        Object.hashAllUnordered(
          query.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (b[k] != a[k]) return false;
    }
    return true;
  }

  @override
  String toString() => 'NavLocation($path, tab=$homeTabIndex, q=$query)';
}

/// Stack of visited screens driving the app-wide Back button.
class NavHistoryNotifier extends StateNotifier<List<NavLocation>> {
  NavHistoryNotifier() : super(const []);

  static const int maxEntries = 50;

  /// Set when a back navigation just happened so the resulting re-visit of the
  /// target screen is not recorded as a new forward step.
  bool _suppressNextVisit = false;

  bool get canGoBack => state.length > 1;

  /// Records that the user is now on [location]. [isRoot] true means this is
  /// the portal's main Dashboard/Overview (or super-admin Console) landing
  /// screen, which resets the history.
  void visit(NavLocation location, {required bool isRoot}) {
    if (_suppressNextVisit) {
      _suppressNextVisit = false;
      return;
    }
    if (state.isNotEmpty && state.last == location) {
      return; // consecutive duplicate
    }
    if (isRoot) {
      state = [location];
      return;
    }
    final next = [...state, location];
    if (next.length > maxEntries) {
      next.removeRange(0, next.length - maxEntries);
    }
    state = next;
  }

  /// Pops the current screen and returns the previous one to navigate to, or
  /// null if there is nothing to go back to. Suppresses the re-record of the
  /// resulting navigation.
  NavLocation? popForBack() {
    if (state.length < 2) return null;
    final target = state[state.length - 2];
    _suppressNextVisit = true;
    state = state.sublist(0, state.length - 1);
    return target;
  }

  /// Clears history (e.g. on logout / shell teardown).
  void reset() {
    _suppressNextVisit = false;
    state = const [];
  }
}

final navHistoryProvider =
    StateNotifierProvider<NavHistoryNotifier, List<NavLocation>>(
  (ref) => NavHistoryNotifier(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/navigation/nav_history_provider_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/navigation/nav_history_provider.dart test/core/navigation/nav_history_provider_test.dart
git commit -m "feat(nav): navigation history stack for app-wide back button"
```

---

### Task 2: Lazy keep-alive IndexedStack + wire into /home

**Files:**
- Create: `lib/core/widgets/lazy_indexed_stack.dart`
- Test: `test/core/widgets/lazy_indexed_stack_test.dart`
- Modify: `lib/features/home/screens/home_screen.dart` (replace `AnimatedSwitcher`+`KeyedSubtree` body)

**Interfaces:**
- Consumes: nothing.
- Produces: `class LazyIndexedStack extends StatefulWidget { const LazyIndexedStack({super.key, required int index, required List<Widget> children}); }` — builds a child the first time its index is selected, then keeps it alive; unvisited slots render `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/lazy_indexed_stack_test.dart`:

```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/lazy_indexed_stack_test.dart`
Expected: FAIL — `lazy_indexed_stack.dart` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/lazy_indexed_stack.dart`:

```dart
import 'package:flutter/material.dart';

/// Like [IndexedStack] but builds a child only after its index has first been
/// selected, then keeps it alive. Unvisited slots are cheap placeholders, so
/// heavy tabs are not all mounted eagerly, while visited tabs retain their
/// state (controllers, scroll position) when other tabs are shown.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited.contains(i) ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/lazy_indexed_stack_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Wire into the /home tab host**

Replace the entire contents of `lib/features/home/screens/home_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/widgets/lazy_indexed_stack.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';

/// Body for `/home`: switches portal tabs (chrome lives in [PortalShellLayout]).
/// Visited tabs are kept alive so in-progress input survives tab switches and
/// back-navigation within a session.
class HomeTabBodyScreen extends ConsumerWidget {
  const HomeTabBodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(portalWorkspaceProvider);
    final idx = ref.watch(portalTabIndexProvider);
    final tabs = vm.tabs;

    if (vm.phase != PortalWorkspacePhase.ready || tabs == null || tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = idx.clamp(0, tabs.length - 1);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LazyIndexedStack(
        index: selected,
        children: [for (final t in tabs) t.screen],
      ),
    );
  }
}

/// Back-compat alias for routes/tests.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeTabBodyScreen();
}
```

- [ ] **Step 6: Verify the app still analyzes and home tests pass**

Run: `flutter analyze lib/features/home/screens/home_screen.dart lib/core/widgets/lazy_indexed_stack.dart`
Expected: No issues.
Run: `flutter test test/core/widgets/lazy_indexed_stack_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/lazy_indexed_stack.dart test/core/widgets/lazy_indexed_stack_test.dart lib/features/home/screens/home_screen.dart
git commit -m "feat(home): lazy keep-alive tab host so tab input survives switches"
```

---

### Task 3: Back navigation helper + Back button reads history

**Files:**
- Create: `lib/core/navigation/nav_back.dart`
- Modify: `lib/core/widgets/app_navigation_back_button.dart`
- Test: `test/core/widgets/app_navigation_back_button_test.dart`

**Interfaces:**
- Consumes: `navHistoryProvider`, `NavLocation`, `NavHistoryNotifier.popForBack()` (Task 1); `portalTabIndexProvider` (existing).
- Produces:
  - `void navigateBack(BuildContext context, WidgetRef ref)` — pops history and `context.go`s to the previous screen (restoring `portalTabIndexProvider` for `/home` targets). No-op if nothing to go back to.
  - `AppNavigationBackButton` now a `ConsumerWidget`; visible only when history depth > 1.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/app_navigation_back_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/app_navigation_back_button.dart';

void main() {
  testWidgets('hidden when there is nothing to go back to', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: AppNavigationBackButton(),
          ),
        ),
      ),
    ));

    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('shown once a non-root screen is on the stack', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: AppNavigationBackButton(),
          ),
        ),
      ),
    ));

    container
        .read(navHistoryProvider.notifier)
        .visit(const NavLocation(path: '/home', homeTabIndex: 0), isRoot: true);
    container
        .read(navHistoryProvider.notifier)
        .visit(const NavLocation(path: '/home', homeTabIndex: 1), isRoot: false);
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_navigation_back_button_test.dart`
Expected: FAIL — button still keyed off `router.canPop()` (or compile error once button is converted). Confirms the test drives the change.

- [ ] **Step 3: Write the back helper**

Create `lib/core/navigation/nav_back.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';

/// Navigates one step back through the recorded screen history. Navigation
/// only — never submits, cancels, or clears anything. No-op if there is no
/// previous screen.
void navigateBack(BuildContext context, WidgetRef ref) {
  final target = ref.read(navHistoryProvider.notifier).popForBack();
  if (target == null) return;

  final tabIndex = target.homeTabIndex;
  if (tabIndex != null) {
    ref.read(portalTabIndexProvider.notifier).state = tabIndex;
    context.go('/home');
  } else {
    context.go(target.fullLocation);
  }
}
```

- [ ] **Step 4: Rewrite the Back button to read history**

Replace the entire contents of `lib/core/widgets/app_navigation_back_button.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

/// Steps back one screen through the recorded navigation history. Hidden when
/// there is no previous screen (i.e. on the main Dashboard/Overview). Purely
/// navigational — never triggers undo/submit/clear side effects.
class AppNavigationBackButton extends ConsumerWidget {
  final Color? color;

  const AppNavigationBackButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGoBack = ref.watch(navHistoryProvider).length > 1;
    if (!canGoBack) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back_rounded, color: color),
      onPressed: () => navigateBack(context, ref),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_navigation_back_button_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/navigation/nav_back.dart lib/core/widgets/app_navigation_back_button.dart test/core/widgets/app_navigation_back_button_test.dart
git commit -m "feat(nav): back button + system back step through visit history"
```

---

### Task 4: Navigation history recorder widget

**Files:**
- Create: `lib/core/widgets/nav_history_recorder.dart`
- Test: `test/core/widgets/nav_history_recorder_test.dart`

**Interfaces:**
- Consumes: `navHistoryProvider`, `NavLocation` (Task 1).
- Produces: `class NavHistoryRecorder extends ConsumerStatefulWidget { const NavHistoryRecorder({super.key, required NavLocation location, required bool isRoot, required Widget child}); }` — records `visit(location, isRoot: isRoot)` on mount and whenever `location`/`isRoot` change; renders `child` unchanged.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/nav_history_recorder_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';

void main() {
  testWidgets('records visits as location changes', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget host(NavLocation loc, bool isRoot) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: NavHistoryRecorder(
              location: loc,
              isRoot: isRoot,
              child: const SizedBox.shrink(),
            ),
          ),
        );

    await tester.pumpWidget(
        host(const NavLocation(path: '/home', homeTabIndex: 0), true));
    await tester.pump(); // run post-frame callback
    expect(container.read(navHistoryProvider).length, 1);

    await tester.pumpWidget(
        host(const NavLocation(path: '/home', homeTabIndex: 1), false));
    await tester.pump();
    expect(container.read(navHistoryProvider).length, 2);
    expect(container.read(navHistoryProvider.notifier).canGoBack, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/nav_history_recorder_test.dart`
Expected: FAIL — `nav_history_recorder.dart` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/nav_history_recorder.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

/// Feeds the [navHistoryProvider] from a shell. Records a visit on mount and
/// whenever [location] or [isRoot] changes. Renders [child] unchanged.
class NavHistoryRecorder extends ConsumerStatefulWidget {
  final NavLocation location;
  final bool isRoot;
  final Widget child;

  const NavHistoryRecorder({
    super.key,
    required this.location,
    required this.isRoot,
    required this.child,
  });

  @override
  ConsumerState<NavHistoryRecorder> createState() => _NavHistoryRecorderState();
}

class _NavHistoryRecorderState extends ConsumerState<NavHistoryRecorder> {
  @override
  void initState() {
    super.initState();
    _record(widget.location, widget.isRoot);
  }

  @override
  void didUpdateWidget(covariant NavHistoryRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.isRoot != widget.isRoot) {
      _record(widget.location, widget.isRoot);
    }
  }

  void _record(NavLocation location, bool isRoot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(navHistoryProvider.notifier).visit(location, isRoot: isRoot);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/nav_history_recorder_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/nav_history_recorder.dart test/core/widgets/nav_history_recorder_test.dart
git commit -m "feat(nav): recorder widget feeding the navigation history"
```

---

### Task 5: Wire portal shell — recorder, system back, remove header «

**Files:**
- Modify: `lib/features/portal/widgets/portal_shell_layout.dart`

**Interfaces:**
- Consumes: `NavLocation` (Task 1), `NavHistoryRecorder` (Task 4), `navigateBack` (Task 3), `navHistoryProvider` (Task 1).
- Produces: portal shell records visits, system back steps through history, header "«" gone.

- [ ] **Step 1: Add imports**

In `lib/features/portal/widgets/portal_shell_layout.dart`, add to the import block:

```dart
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
```

(`app_navigation_back_button.dart` is already imported.)

- [ ] **Step 2: Compute the current NavLocation**

In `build`, immediately after the existing line `final sectionTitle = portalShellSectionTitle(uri, tabs, navIndex);` (around line 225), add:

```dart
    final onHome = location == '/home';
    final navLocation = NavLocation(
      path: location,
      query: uri.queryParameters,
      homeTabIndex: onHome ? navIndex : null,
    );
    final isRootScreen = onHome && navIndex == 0;
```

- [ ] **Step 3: Remove the header "«" toggle**

Delete this block from the `AppBar.actions` list (currently lines ~324–336):

```dart
        if (!narrowNav)
          IconButton(
            tooltip: _portalSidebarExpanded ? 'Collapse navigation' : 'Expand navigation',
            icon: Icon(
              _portalSidebarExpanded
                  ? Icons.keyboard_double_arrow_left_rounded
                  : Icons.keyboard_double_arrow_right_rounded,
            ),
            onPressed: () {
              setState(() => _portalSidebarExpanded = !_portalSidebarExpanded);
              AppSidebarPrefs.writePortalExpanded(_portalSidebarExpanded);
            },
          ),
```

(Leave everything else in `actions` intact. The sidebar's own toggle in `portal_scaffold.dart` is untouched, and `_portalSidebarExpanded` is still used by `PortalScaffold`.)

- [ ] **Step 4: Wrap the shell body in the recorder**

In the `PortalScaffold(...)` call, change the `body:` argument from:

```dart
      body: widget.child,
```

to:

```dart
      body: NavHistoryRecorder(
        location: navLocation,
        isRoot: isRootScreen,
        child: widget.child,
      ),
```

- [ ] **Step 5: Repoint system back to the history**

Replace the `PopScope` block near the end of `build` (currently lines ~386–397):

```dart
    content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
      },
      child: content,
    );
```

with:

```dart
    content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ref.read(navHistoryProvider.notifier).canGoBack) {
          navigateBack(context, ref);
        }
      },
      child: content,
    );
```

(The `go_router` import may now be unused for `GoRouter.of`; keep it only if still referenced elsewhere in the file — `GoRouterState.of` is still used at line ~222, so the import stays.)

- [ ] **Step 6: Verify analysis and full test suite**

Run: `flutter analyze lib/features/portal/widgets/portal_shell_layout.dart`
Expected: No issues (no unused-import warnings).
Run: `flutter test test/core/`
Expected: PASS (all nav + widget tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/portal/widgets/portal_shell_layout.dart
git commit -m "feat(portal): record visits, history back, remove header collapse toggle"
```

---

### Task 6: Wire super-admin shell — recorder, system back, remove header «

**Files:**
- Modify: `lib/features/super_admin/widgets/super_admin_shell_layout.dart`

**Interfaces:**
- Consumes: `NavLocation` (Task 1), `NavHistoryRecorder` (Task 4), `navigateBack` (Task 3), `navHistoryProvider` (Task 1).
- Produces: super-admin shell records visits, system back steps through history, header "«" gone.

- [ ] **Step 1: Add imports**

In `lib/features/super_admin/widgets/super_admin_shell_layout.dart`, add:

```dart
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
```

(`app_navigation_back_button.dart` is already imported.)

- [ ] **Step 2: Compute the current NavLocation**

In `build`, just after `final location = GoRouterState.of(context).uri.path;` (line ~62), add:

```dart
          final navLocation = NavLocation(
            path: location,
            query: GoRouterState.of(context).uri.queryParameters,
          );
          final isRootScreen = location == '/super-admin';
```

- [ ] **Step 3: Remove the header "«" toggle**

Delete this block from the header `Row` (currently lines ~115–124):

```dart
                              if (!useDrawer)
                                IconButton(
                                  tooltip: _sidebarExpanded ? 'Collapse navigation' : 'Expand navigation',
                                  icon: Icon(
                                    _sidebarExpanded
                                        ? Icons.keyboard_double_arrow_left_rounded
                                        : Icons.keyboard_double_arrow_right_rounded,
                                  ),
                                  onPressed: () => _setSidebarExpanded(!_sidebarExpanded),
                                ),
```

(The drawer `menu` button just above it stays. The sidebar's own `onToggleRailExpanded` toggle in `_SidebarNav` is untouched, so `_setSidebarExpanded` is still used.)

- [ ] **Step 4: Wrap the shell body in the recorder**

In the `AnimatedSwitcher`'s `KeyedSubtree`, change:

```dart
                          child: KeyedSubtree(
                            key: ValueKey(location),
                            child: ColoredBox(
                              color: cs.surface,
                              child: widget.child,
                            ),
                          ),
```

to:

```dart
                          child: KeyedSubtree(
                            key: ValueKey(location),
                            child: ColoredBox(
                              color: cs.surface,
                              child: NavHistoryRecorder(
                                location: navLocation,
                                isRoot: isRootScreen,
                                child: widget.child,
                              ),
                            ),
                          ),
```

- [ ] **Step 5: Repoint system back to the history**

Replace the `PopScope` block near the end of `build` (currently lines ~212–222):

```dart
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              }
            },
            child: shell,
          );
```

with:

```dart
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (ref.read(navHistoryProvider.notifier).canGoBack) {
                navigateBack(context, ref);
              }
            },
            child: shell,
          );
```

(`GoRouterState.of` is still used at line ~62, so the `go_router` import stays.)

- [ ] **Step 6: Verify analysis and full test suite**

Run: `flutter analyze lib/features/super_admin/widgets/super_admin_shell_layout.dart`
Expected: No issues.
Run: `flutter test`
Expected: PASS (whole suite green).

- [ ] **Step 7: Commit**

```bash
git add lib/features/super_admin/widgets/super_admin_shell_layout.dart
git commit -m "feat(super-admin): record visits, history back, remove header collapse toggle"
```

---

### Task 7: Manual smoke verification

**Files:** none (verification only).

- [ ] **Step 1: Build and run, then verify behaviours**

Run: `flutter run` (or the project's usual launch). Sign in as a Buyer (or any portal user) and confirm:
- On the Dashboard/Overview tab: **no** Back button in the header.
- Tap a sidebar tab (e.g. Routes & Mines): Back button **appears**; pressing it returns to Dashboard and the button disappears.
- Tab A → type into any inline field → tab B → press Back to return to A → the typed text is **still there**.
- Open a detail page (e.g. from a list) → Back returns to the list.
- The header "«" collapse toggle is **gone**; the sidebar's own collapse toggle still works.
- Android/hardware back gesture mirrors the Back button.
Sign in as super-admin and confirm the Console hides Back while inner pages show it, and the header "«" is gone.

- [ ] **Step 2: Final full suite + analyze**

Run: `flutter analyze`
Expected: No new issues.
Run: `flutter test`
Expected: All green.

---

## Self-Review

**Spec coverage:**
- Back button on every screen / role → Tasks 3, 5, 6 (button reads history; recorder in both shells). ✓
- Hidden on Dashboard/Overview → Task 1 root-reset + Task 3 visibility; isRoot computed in Tasks 5/6. ✓
- Navigation-only, never clears input → Task 3 `navigateBack` (pure `context.go`). ✓
- In-session tab resume → Task 2 `LazyIndexedStack`. ✓
- Remove header "«" (portal + super-admin), keep sidebar toggle → Tasks 5 & 6 Step 3. ✓
- System/hardware back parity → Tasks 5 & 6 Step 5. ✓
- Phase 2 items (persistence/prompts) excluded → not present. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step has full code. ✓

**Type consistency:** `NavLocation`, `NavHistoryNotifier.{visit,popForBack,canGoBack,reset}`, `navHistoryProvider`, `navigateBack(context, ref)`, `NavHistoryRecorder({location,isRoot,child})`, `LazyIndexedStack({index,children})` used identically across Tasks 1–6. ✓
