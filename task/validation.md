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

Two agent reviews checked input-device ownership, callback lifetime, delayed event delivery,
geometry, gesture state, and code structure. Findings addressed before initial publication.

No user photo, machine diagnostic reports, credentials, or contact recordings are included.
