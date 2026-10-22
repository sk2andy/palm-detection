import Testing

@testable import PalmGuard

@Suite("Activation prerequisites and permission recovery")
struct ActivationReadinessTests {
    private var ready: ActivationReadiness {
        ActivationReadiness(
            trackpadConnected: true, accessibilityGranted: true,
            nativeTapSetting: .disabled, nativeTapsDisabledConfirmed: false)
    }

    @Test func missingAccessibilityPreventsSyntheticClicks() {
        var state = ready
        state.accessibilityGranted = false
        #expect(state.problem == .accessibilityRequired)
    }

    @Test func recoveryNamesTheInstalledBundleRatherThanAGuessedApplicationsFolder() {
        let path = "/Users/example/Applications/PalmGuard.app"
        let explanation = ActivationProblem.accessibilityRequired.explanation(appPath: path)
        #expect(explanation.contains(path))
        #expect(explanation.contains("älteren Build"))
        #expect(explanation.contains("erneut hinzu"))
    }

    @Test func disabledNativeTapsNeedNoManualConfirmation() {
        #expect(ready.problem == nil)
    }

    @Test func knownEnabledNativeTapsCannotBeOverriddenByConfirmation() {
        var state = ready
        state.nativeTapSetting = .enabled
        #expect(state.problem == .nativeTapsEnabled)
        state.nativeTapsDisabledConfirmed = true
        #expect(state.problem == .nativeTapsEnabled)
    }

    @Test func unknownNativeTapSettingRequiresExplicitConfirmation() {
        var state = ready
        state.nativeTapSetting = .unknown
        #expect(state.problem == .nativeTapStateUnknown)
        state.nativeTapsDisabledConfirmed = true
        #expect(state.problem == nil)
    }

    @Test func disconnectedDevicePreventsActivationEvenWithPermissions() {
        var state = ready
        state.trackpadConnected = false
        #expect(state.problem == .trackpadDisconnected)
    }
}
