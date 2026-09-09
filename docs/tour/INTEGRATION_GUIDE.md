# Coach-Mark Tour Integration Guide

This guide explains how to integrate the new coach-mark tour system into MineLink screens.

## Overview

The new tour system replaces the old full-screen onboarding with contextual coach marks that highlight actual UI elements. The system consists of:

1. **TourTarget widget** - Wraps UI elements to make them tour targets
2. **TourOverlay** - The overlay that shows spotlights and tooltips
3. **TourService** - Defines tour steps per role/org type
4. **TourProvider** - Manages active tour state
5. **TourSeenProvider** - Persists tour completion

## Integration Steps

### Step 1: Define Tour Keys

Create a file to hold the GlobalKeys for your screen's tour targets:

```dart
// lib/features/tour/examples/my_screen_keys.dart
import 'package:flutter/material.dart';

class MyScreenTourKeys {
  static final primaryAction = GlobalKey();
  static final secondaryAction = GlobalKey();
  static final dataList = GlobalKey();
  static final filterButton = GlobalKey();
}
```

### Step 2: Wrap UI Elements with TourTarget

Wrap the UI elements you want to highlight with `TourTarget` widgets:

```dart
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/my_screen_keys.dart';

// In your screen's build method:
Column(
  children: [
    TourTarget(
      id: 'my_screen.primary_action',
      targetKey: MyScreenTourKeys.primaryAction,
      child: ElevatedButton(
        onPressed: () { /* ... */ },
        child: Text('Primary Action'),
      ),
    ),
    
    TourTarget(
      id: 'my_screen.data_list',
      targetKey: MyScreenTourKeys.dataList,
      child: ListView.builder(
        // ...
      ),
    ),
  ],
)
```

### Step 3: Define Tour Steps

Add tour steps to the appropriate role-specific method in `TourService`:

```dart
// lib/features/tour/services/tour_service.dart
import 'package:flutter_application_1/features/tour/examples/my_screen_keys.dart';

List<TourStep> _myRoleTour() {
  return [
    TourStep(
      id: 'my_screen.primary_action',
      targetKey: MyScreenTourKeys.primaryAction,
      title: 'Primary Action',
      description: 'This is the main action for this screen. Use it to...',
      icon: Icons.star,
    ),
    TourStep(
      id: 'my_screen.data_list',
      targetKey: MyScreenTourKeys.dataList,
      title: 'Data List',
      description: 'View and manage your data here. Tap items to see details.',
      icon: Icons.list,
    ),
  ];
}
```

### Step 4: Test the Tour

Use the debug provider to test your tour integration:

```dart
// In debug mode, you can call:
ref.read(tourDebugProvider.notifier).startTourFromStep(0);
ref.read(tourDebugProvider.notifier).logTourState();
ref.read(tourDebugProvider.notifier).debugTarget(MyScreenTourKeys.primaryAction, 'primary_action');
```

## Best Practices

### Target Selection

- **Choose stable elements**: Target UI elements that are always present, not conditional
- **Avoid dynamic lists**: Don't target individual list items that change
- **Focus on key actions**: Highlight the most important actions on each screen
- **Keep it simple**: 5-7 steps maximum per tour to avoid overwhelming users

### Cross-Screen Navigation

Use the `navigateTo` parameter to move between screens:

```dart
TourStep(
  id: 'step_on_another_screen',
  targetKey: AnotherScreenTourKeys.target,
  title: 'Another Screen',
  description: 'Navigate to this screen to...',
  navigateTo: '/path/to/screen',
)
```

### Tooltip Positioning

The system auto-positions tooltips, but you can specify preference:

```dart
TourStep(
  // ...
  position: TooltipPosition.bottom, // or top, left, right, auto
)
```

### Target Interaction

Allow users to interact with the highlighted element if needed:

```dart
TourStep(
  // ...
  allowTargetInteraction: true, // Allows tapping the target
)
```

### Missing Targets

The system gracefully handles missing targets:
- Retries up to 3 times with delays
- Logs warnings in development
- Skips the step if target cannot be found
- Never crashes the app

## Example: Transporter Dashboard

Here's a complete example for the transporter dashboard:

### 1. Define Keys

```dart
// lib/features/tour/examples/transporter_dashboard_keys.dart
class TransporterDashboardTourKeys {
  static final fleetStatus = GlobalKey();
  static final availableRoutes = GlobalKey();
  static final activeTrips = GlobalKey();
  static final earnings = GlobalKey();
}
```

### 2. Wrap Elements

```dart
// In transporter_portal_dashboard_screen.dart
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/transporter_dashboard_keys.dart';

// Wrap the fleet status cards
TourTarget(
  id: 'transporter.fleet_status',
  targetKey: TransporterDashboardTourKeys.fleetStatus,
  child: FleetStatusCard(...),
)

// Wrap the available routes section
TourTarget(
  id: 'transporter.available_routes',
  targetKey: TransporterDashboardTourKeys.availableRoutes,
  child: AvailableRoutesSection(...),
)
```

### 3. Define Steps

```dart
// In tour_service.dart
List<TourStep> _transporterAdminTour() {
  return [
    TourStep(
      id: 'transporter.fleet_status',
      targetKey: TransporterDashboardTourKeys.fleetStatus,
      title: 'Fleet Status',
      description: 'See how many trucks are on route, available, or in maintenance.',
      icon: Icons.directions_bus_outlined,
    ),
    TourStep(
      id: 'transporter.available_routes',
      targetKey: TransporterDashboardTourKeys.availableRoutes,
      title: 'Available Routes',
      description: 'Accept new routes from mines here. Review pricing and details.',
      icon: Icons.alt_route_outlined,
    ),
  ];
}
```

## Debug Mode

In debug builds, you can access tour debugging utilities:

```dart
// Reset tour completion to see the tour again
await ref.read(tourDebugProvider.notifier).resetTourCompletion();

// Start from a specific step
ref.read(tourDebugProvider.notifier).startTourFromStep(2);

// Log current tour state
ref.read(tourDebugProvider.notifier).logTourState();

// Debug a specific target
ref.read(tourDebugProvider.notifier).debugTarget(
  MyScreenTourKeys.primaryAction,
  'primary_action',
);
```

## Troubleshooting

### Target Not Found

If a target isn't found:
1. Check that the GlobalKey is correctly assigned to the TourTarget
2. Verify the target is actually rendered (not in a conditional branch)
3. Check debug logs for the target context
4. Use `debugTarget()` to verify the target exists

### Tooltip Off-Screen

If the tooltip goes off-screen:
1. The system auto-repositions, but you can specify `position` preference
2. Check that the target isn't too close to screen edges
3. Consider increasing screen-safe margins

### Cross-Screen Navigation Issues

If navigation fails:
1. Verify the route path is correct
2. Check that the target exists on the destination screen
3. The system waits 300ms for the screen to render before finding targets
4. Increase delay if your screen loads slowly

## Migration from Old Tutorial System

The old `TutorialOverlay` and related files have been removed. To migrate:

1. Remove any references to `tutorialOverlayProvider`, `tutorialSeenProvider`, `tutorialStepsProvider`
2. Replace with `tourProvider`, `tourSeenProvider`, `tourStepsProvider`
3. Convert full-screen tutorial steps to contextual tour steps with actual targets
4. Wrap UI elements with `TourTarget` widgets
5. Update tour definitions in `TourService`

## Performance Considerations

- The tour overlay only renders when active
- Target measurement happens on-demand when a step becomes active
- Scroll-to-target uses Flutter's built-in `ensureVisible` for efficiency
- Animations use the existing MlTokens animation system
- No impact on app performance when tour is not active

## Patterns Learned During the Rollout (2026-09-08)

These came out of wiring the fleet, routes, requests and reconciliations
screens into the tours — follow them for any new screen.

### A step that navigates must target the DESTINATION screen

`navigateTo` runs `go()` BEFORE the target is looked up. A step whose
`targetKey` is wrapped on the screen the tour is LEAVING can never be found —
the overlay skips it after its retries. Both original cross-screen steps had
this bug (`buyer.requests` and `transporter.available_routes` targeted
dashboard keys while navigating away). Rules that follow:

1. Order each role's tour so every step targeting screen A comes before the
   first step that navigates away from it.
2. A navigated step's `targetKey` must reference a key wrapped on the route it
   navigates TO.
3. Cross-screen steps are one-directional: pressing Back to a step whose
   screen is behind you skips forward again. Keep the narrative moving
   forward.

### Conditional sections need an auto-skip story

A key wrapped in `if (waiting.isNotEmpty) ...` is unmounted whenever the list
is empty — the overlay logs a warning and skips the step after ~500ms. That
is the designed behaviour; prefer it over wrapping an always-present
placeholder. Mention nothing about the skip in the tooltip copy.

### A step cannot `navigateTo` a PUSHED screen

`RequestTransportationScreen` (and any other `Navigator.push` screen, dialogs
included) has no go_router path, so `navigateTo` cannot reach it. Wrap its
elements for contextual tours anyway (`mine_requests_keys.dart`), but do not
add a role-tour step pointing at them.

### Wrap sections, not individual cards

Spotlight the section title TOGETHER with its content by wrapping both in one
`TourTarget > Column`. Never reuse one GlobalKey on two cards — duplicate
GlobalKeys crash the build. For lists rendered in a spread
(`for (final x in items) ...[...]`), wrap the whole `if/else` + loop in the
TourTarget's Column.

### Mount TourOverlay inside a Stack

The portal shell mounts the overlay in a Stack over the page content. Putting
it in a flex Column makes the full-screen overlay participate in layout and
overflows. Any test harness must mirror the production mounting.

### Header actions are wrappable

`MlPageHeader.actions` takes plain widgets — wrapping an `MlButton` in a
`TourTarget` inside the list works, and the guided tour can spotlight the
screen's primary action directly.

### Update neighbour tests when wrapping widgets

Tests that find widgets through the tree (`actions.cast<MlButton>()`,
`expect(w, isA<MlButton>())`) now see the `TourTarget` wrapper. Unwrap before
asserting — see `screenActions()` in
`test/features/portal/requests_screen_copy_and_actions_test.dart`.

### Automated coverage

`test/features/tour/tour_system_test.dart` covers the state machine
(start/next/previous/goToStep/stop), seen-flag persistence across container
restarts, every `TourDebugNotifier` method (with `tourStepsProvider`
overridden — the real one pulls in Supabase), and the overlay's
skip-on-missing-target rule. Extend it when you add tour behaviour; device
checks stay in `REMAINING_WORK.md`.

### Troubleshooting (additions)

- A step flashes and skips on arrival: its key is wrapped on a different
  screen than `navigateTo` lands on (see first pattern above).
- `RenderFlex overflowed` in a tour test: the harness mounted the overlay in
  a Column, not a Stack.
- `You must initialize the supabase instance` in a tour test: override
  `tourStepsProvider` instead of booting Supabase.
- A wrapped element never spotlights on device: check the element is actually
  built at that step (conditional branch / wrong tab), then check the key is
  the SAME static final the screen wraps — not a fresh `GlobalKey()`.

