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

Native mouse events do not expose reliable tap provenance. Prefer replacing native tap-to-click
with deliberate synthetic taps, rather than guessing which mouse events to suppress. Clarify
pressure-click behavior with the user before adding suppression.

## Activation recovery

- Every failed activation shows an actionable error dialog, including repeated attempts.
- Missing Accessibility trust explains stale local-build grants and shows the actual bundle path.
- Only PalmGuard's own stale permission entry may be replaced; user approval precedes a new grant.
- Rebuild and install before repairing the grant so the permission matches the final binary.
- Verify the installed app reaches active state; preserve the configured area.
