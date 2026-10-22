import AppKit
import Combine
import MultitouchBridge
import PalmGuardCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            SettingsStore.save(settings)
            engine.configuration = settings.configuration
            cancelPendingTap()
            if oldValue.nativeTapsDisabledConfirmed != settings.nativeTapsDisabledConfirmed {
                isEnabled = false
                status = "Vorschau – Schutz pausiert"
            }
        }
    }
    @Published private(set) var isEnabled = false
    @Published private(set) var contacts: [TouchContact] = []
    @Published private(set) var status = "Vorschau – Schutz pausiert"
    @Published private(set) var deviceName = "Suche externes Trackpad …"
    @Published private(set) var lastDecision = "Trackpad einmal vollständig loslassen."
    @Published private(set) var acceptedCount = 0
    @Published private(set) var rejectedCount = 0
    @Published private(set) var postedTapCount = 0
    @Published private(set) var hasAccessibility = AXIsProcessTrusted()
    @Published private(set) var nativeTapSetting: NativeTapSetting = .unknown
    @Published private(set) var frameCount = 0
    @Published var activationProblem: ActivationProblem?
    var appPath: String { Bundle.main.bundleURL.path }

    private let stream = TouchStream()
    private let mouse = MouseEventService()
    private var engine: PalmGestureEngine
    private var pendingTap: DispatchWorkItem?
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastPreviewTime: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0
    private var previewStarted = false

    init() {
        let saved = SettingsStore.load()
        settings = saved
        engine = PalmGestureEngine(configuration: saved.configuration)
        stream.onFrame = { [weak self] contacts, time in self?.receive(contacts, at: time) }
        mouse.onPhysicalActivity = { [weak self] in
            self?.engine.cancelCurrentGesture()
            self?.cancelPendingTap()
        }
        mouse.onTapDisabled = { [weak self] in
            self?.isEnabled = false
            self?.resetRecognition()
            self?.status = "Schutz pausiert: Mausbeobachtung wurde von macOS unterbrochen."
        }
    }

    func startPreview() {
        guard !previewStarted else { return }
        previewStarted = true
        reconnect()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.pauseForSleep() }
            })
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reconnect() }
            })
    }

    func reconnect() {
        isEnabled = false
        resetRecognition()
        if let error = stream.start() {
            status = "Trackpad nicht bereit: \(error)"
            deviceName = "Kein externes Trackpad"
        } else {
            deviceName = stream.deviceName
            status = "Vorschau – Schutz pausiert"
        }
        refreshNativeTapSetting()
    }

    func toggleProtection() {
        activationProblem = nil
        if isEnabled {
            isEnabled = false
            resetRecognition()
            status = "Vorschau – Schutz pausiert"
            return
        }
        refreshPermissions()
        let readiness = ActivationReadiness(
            trackpadConnected: stream.isRunning, accessibilityGranted: hasAccessibility,
            nativeTapSetting: nativeTapSetting,
            nativeTapsDisabledConfirmed: settings.nativeTapsDisabledConfirmed)
        if let problem = readiness.problem {
            reportActivationProblem(problem)
            return
        }
        guard mouse.start() else {
            reportActivationProblem(.eventAccessRequired)
            return
        }
        resetRecognition()
        isEnabled = true
        status = "Tap-Schutz aktiv · Druck-Klicks und Drags frei"
    }

    func recoverActivation(_ problem: ActivationProblem) {
        switch problem {
        case .accessibilityRequired: requestAccessibility()
        case .eventAccessRequired: openSettings("Privacy_ListenEvent")
        case .nativeTapsEnabled, .nativeTapStateUnknown: openSettings("Trackpad")
        case .trackpadDisconnected: reconnect()
        }
    }

    func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func reportActivationProblem(_ problem: ActivationProblem) {
        isEnabled = false
        resetRecognition()
        status = problem.status
        activationProblem = problem
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings("Privacy_Accessibility")
    }

    func openSettings(_ pane: String) {
        let address =
            pane == "Trackpad"
            ? "x-apple.systempreferences:com.apple.Trackpad-Settings.extension"
            : "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }

    func shutdown() {
        isEnabled = false
        cancelPendingTap()
        timer?.invalidate()
        timer = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        stream.stop()
        mouse.stop()
    }

    private func receive(_ newContacts: [TouchContact], at time: TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        guard (0..<0.12).contains(now - time) else {
            resetRecognition()
            return
        }
        lastFrameTime = time
        let decision = engine.process(contacts: newContacts, timestamp: time)
        if newContacts.isEmpty || time - lastPreviewTime >= 1.0 / 30 {
            contacts =
                newContacts.allSatisfy(\.isValid)
                    && Set(newContacts.map(\.id)).count == newContacts.count ? newContacts : []
            frameCount += 1
            lastPreviewTime = time
        }
        guard let decision else { return }
        switch decision {
        case .accepted(let fingers):
            acceptedCount += 1
            lastDecision = "\(fingers)-Finger-Tap erkannt"
            guard isEnabled else { return }
            cancelPendingTap()
            guard let releasePosition = CGEvent(source: nil)?.location else { return }
            let releaseApplication = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isEnabled, self.nativeTapsAreDisabled(),
                    ProcessInfo.processInfo.systemUptime - time < 0.12,
                    NSWorkspace.shared.frontmostApplication?.processIdentifier == releaseApplication,
                    let currentPosition = CGEvent(source: nil)?.location,
                    hypot(currentPosition.x - releasePosition.x, currentPosition.y - releasePosition.y) < 4
                else { return }
                if self.mouse.postTap(fingers: fingers) { self.postedTapCount += 1 }
                self.pendingTap = nil
            }
            pendingTap = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: work)
        case .rejected(let reason):
            cancelPendingTap()
            rejectedCount += 1
            lastDecision = "Verworfen: \(reason.rawValue)"
        }
    }

    private func refreshNativeTapSetting() {
        nativeTapSetting = NativeTapSetting(rawValue: Int(pd_mt_native_tap_setting())) ?? .unknown
    }

    private func nativeTapsAreDisabled() -> Bool {
        refreshNativeTapSetting()
        return nativeTapSetting == .disabled
            || (nativeTapSetting == .unknown && settings.nativeTapsDisabledConfirmed)
    }

    private func refreshPermissions() {
        hasAccessibility = AXIsProcessTrusted()
        let nativeTapsDisabled = nativeTapsAreDisabled()
        if isEnabled && (!hasAccessibility || !nativeTapsDisabled) {
            isEnabled = false
            resetRecognition()
            status =
                hasAccessibility
                ? "Schutz pausiert: macOS-Tap-Einstellung geändert."
                : "Schutz pausiert: Bedienungshilfen-Freigabe fehlt."
        }
        if !contacts.isEmpty && ProcessInfo.processInfo.systemUptime - lastFrameTime > 0.5 {
            resetRecognition()
        }
    }

    private func pauseForSleep() {
        isEnabled = false
        resetRecognition()
        stream.stop()
        status = "Schutz pausiert: Ruhezustand"
    }

    private func resetRecognition() {
        engine.reset()
        contacts = []
        cancelPendingTap()
    }

    private func cancelPendingTap() {
        pendingTap?.cancel()
        pendingTap = nil
    }
}
