import Testing

@testable import PalmGuard

@Suite("Activation prerequisites and permission recovery")
struct ActivationReadinessTests {
    private var ready: ActivationReadiness {
        ActivationReadiness(
            trackpadConnected: true, accessibilityGranted: true,
            identityAvailable: true, mode: .filterClicks,
            nativeTapsDisabledConfirmed: false, nativeTapPreferenceEnabled: false)
    }

    @Test func missingAccessibilityBlocksBothModes() {
        for mode in ProtectionMode.allCases {
            var state = ready
            state.mode = mode
            state.accessibilityGranted = false
            #expect(state.problem == .accessibilityRequired)
        }
    }

    @Test func recoveryNamesTheInstalledBundleRatherThanAGuessedApplicationsFolder() {
        let path = "/Users/example/Applications/PalmGuard.app"
        let explanation = ActivationProblem.accessibilityRequired.explanation(appPath: path)
        #expect(explanation.contains(path))
        #expect(explanation.contains("älteren Build"))
        #expect(explanation.contains("erneut hinzu"))
    }

    @Test func nativeClickFilteringRequiresKnownDeviceIdentity() {
        var state = ready
        #expect(state.problem == nil)
        state.identityAvailable = false
        #expect(state.problem == .identityUnavailable)
    }

    @Test func generatedTapsRequireConfirmationAndDisabledNativeTaps() {
        var state = ready
        state.mode = .deliberateTaps
        state.identityAvailable = false
        #expect(state.problem == .nativeTapsEnabled)
        state.nativeTapsDisabledConfirmed = true
        #expect(state.problem == nil)
        state.nativeTapPreferenceEnabled = true
        #expect(state.problem == .nativeTapsEnabled)
    }

    @Test func disconnectedDevicePreventsActivationEvenWithPermissions() {
        var state = ready
        state.trackpadConnected = false
        #expect(state.problem == .trackpadDisconnected)
    }
}
