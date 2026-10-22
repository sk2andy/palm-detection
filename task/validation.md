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

Two agent reviews checked input-device ownership, callback lifetime, delayed event delivery,
geometry, gesture state, and code structure. Findings addressed before initial publication.

No user photo, machine diagnostic reports, credentials, or contact recordings are included.
