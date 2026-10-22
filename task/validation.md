# Validation — 2026-10-22

| Check | Result |
| --- | --- |
| Swift 6 debug and release builds | Passed locally on macOS 15.7.4 / Apple Silicon |
| Automated tests | 75 tests, 7 suites passed |
| Swift formatting | Strict lint passed |
| C bridge warnings | `-Wall -Wextra -Werror` passed |
| App bundle | Ad hoc signature verified |
| External Magic Trackpad enumeration | Passed; built-in excluded |
| Bridge lifecycle | Five start/stop cycles passed |
| Real raw contact delivery | Live UI received >170 frames after callback fix |
| Settings UI | Full-area preset persisted; standard preset restored successfully |
| Runtime regression | Background callback actor-isolation crash fixed and covered by two tests |
| Effective click suppression on physical trackpad | Pending Accessibility permission and human touch test |
| Raycast Hyperkey shortcuts | Event mask excludes keyboard; actual user shortcuts not yet tested |

## Activation recovery — 0.1.1

| Check | Result |
| --- | --- |
| Root cause | macOS rejected the stored Accessibility code requirement from an older build |
| Recovery scope | Only PalmGuard Accessibility reset, with explicit user approval |
| Regrant | Final installed bundle added through macOS Settings after building |
| Actual activation | Passed: installed app showed “Klickfilter aktiv” and “Pausieren” |
| User configuration | Custom area preserved across update and permission repair |
| Failed activation feedback | Native alert displayed, with real bundle path and recovery action |
| Tests after activation changes | 80 tests, 8 suites passed |
| Formatting and release bundle | Passed; installed signature verified |

Do not rebuild or re-sign the installed ad hoc app after granting permission without planning
another explicit permission repair. Source commits and CI builds do not modify the installed app.

## Preserve native pressure clicks and three-finger dragging — 0.2.0

| Check | Result |
| --- | --- |
| Automated tests | 71 tests, 8 suites passed |
| System mouse event preservation | Observer uses `listenOnly`; tests verify event data unchanged |
| Keyboard / modifier hooks | Excluded from the observation mask |
| Raw three fingers with one outside area | Synthetic tap vetoed before area selection |
| Staggered three-finger release | Cannot become a synthetic one-/two-finger tap |
| Broad resting palm plus two fingers | Deliberate tap remains possible |
| Settings migration | Both legacy modes preserve the calibrated rectangle |
| Selected-driver native tap setting | Live getter replaces stale defaults reads |
| C warnings / Swift formatting / release signing | Passed |
| macOS native tap-to-click | Switched off with explicit user approval; app confirmed live driver state |
| Native three-finger dragging | Enabled in macOS before update; hardware check remains human-operated |
| Updated Accessibility permission | Awaiting user's macOS authentication dialog |

The native-click suppression mode, private sender-identity SPI and suppression sequence state
have been removed. Physical clicks and drags are always delivered by macOS; PalmGuard adds
only approved tap events. No new installed build should follow the pending permission grant.

Two agent reviews checked input-device ownership, callback lifetime, delayed event delivery,
geometry, gesture state, and code structure. Findings addressed before initial publication.

No user photo, machine diagnostic reports, credentials, or contact recordings are included.
