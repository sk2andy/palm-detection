# PalmGuard acceptance criteria

- Native macOS menu-bar app, built locally as an app bundle.
- Configurable permitted trackpad area with live contact preview and persistent settings.
- Recognize short, stationary one- and two-finger taps; reject outside-area, long, moving,
  and broad contacts. Report decisions locally for calibration.
- Keep keyboard and modifier events untouched, including Raycast Hyperkey shortcuts.
- Isolate undocumented MultitouchSupport integration from pure, tested recognition logic.
- Explicit permission/setup status, pause, reconnect, and safe behavior on missing devices.
- Public GitHub repository with clean ignore rules, build instructions, CI, tests, and limitations.
- Confirm real-device input behavior with user; do not claim hardware or Raycast verification
  based only on unit tests.

## Implementation units

1. Pure geometry and temporal tap recognizer with meaningful tests.
2. Narrow runtime-loaded C bridge for raw external trackpad contacts.
3. SwiftUI area editor, status, persistence, and macOS event integration.
4. Build bundle, review, run tests, smoke-check app, publish source.

## Important boundary

Native mouse events do not expose reliable tap provenance. Never suppress native mouse events.
Use a listen-only pointer observer and generate approved taps with native tap-to-click disabled.
Pressure clicks, force clicks and native drags must work across the entire trackpad.
Native three-finger dragging remains independent of the permitted tap rectangle.

## Preserve native clicks and dragging — 0.2.0

- Remove the native-click filtering mode and its private event-identity integration.
- Preserve all native mouse events using `listenOnly`; do not suppress any event sequence.
- Recognize one- and two-finger taps only inside the configured rectangle.
- Veto synthetic taps for three or more finger-sized raw contacts before area selection;
  retain the veto through staggered releases so a native drag cannot become a two-finger tap.
- Keep broad resting palms independent of finger taps; document relative-size ambiguity.
- Read native tap-to-click from the selected trackpad's active driver, not cached defaults.
- Preserve previously configured areas when migrating from either old mode.
- Verify native tap-to-click is off and maintain the separately configured three-finger drag.

## Activation recovery

- Every failed activation shows an actionable error dialog, including repeated attempts.
- Missing Accessibility trust explains stale local-build grants and shows the actual bundle path.
- Only PalmGuard's own stale permission entry may be replaced; user approval precedes a new grant.
- Rebuild and install before repairing the grant so the permission matches the final binary.
- Verify the installed app reaches active state; preserve the configured area.
