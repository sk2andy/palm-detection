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
            if oldValue.mode != settings.mode
                || oldValue.nativeTapsDisabledConfirmed != settings.nativeTapsDisabledConfirmed
            {
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
    @Published private(set) var blockedCount = 0
    @Published private(set) var matchedCount = 0
    @Published private(set) var unknownSourceCount = 0
    @Published private(set) var hasAccessibility = AXIsProcessTrusted()
    @Published private(set) var identitySupported = false
    @Published private(set) var frameCount = 0

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
        mouse.shouldBlock = { [weak self] matches in self?.shouldBlockClick(matches: matches) ?? false }
        mouse.onPhysicalActivity = { [weak self] in
            self?.engine.cancelCurrentGesture()
            self?.cancelPendingTap()
        }
        mouse.onTapDisabled = { [weak self] in
            self?.isEnabled = false
            self?.resetRecognition()
            self?.status = "Schutz pausiert: Ereignisfilter wurde von macOS unterbrochen."
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
        identitySupported = pd_mt_event_identity_supported()
    }

    func toggleProtection() {
        if isEnabled {
            isEnabled = false
            resetRecognition()
            status = "Vorschau – Schutz pausiert"
            return
        }
        refreshPermissions()
        guard stream.isRunning else {
            status = "Externes Trackpad verbinden und neu verbinden."
            return
        }
        guard hasAccessibility else {
            status = "Bedienungshilfen für PalmGuard freigeben."
            return
        }
        if settings.mode == .filterClicks && !identitySupported {
            status = "Klickquelle auf diesem macOS nicht verfügbar. Eigene Taps verwenden."
            return
        }
        if settings.mode == .deliberateTaps {
            guard settings.nativeTapsDisabledConfirmed, !SettingsStore.nativeTapPreferenceEnabled else {
                status = "Zuerst natives Tippen zum Klicken ausschalten und unten bestätigen."
                return
            }
        }
        guard mouse.start() else {
            status = "Ereigniszugriff fehlt. Bedienungshilfen / Eingabeüberwachung prüfen."
            return
        }
        resetRecognition()
        isEnabled = true
        status = settings.mode == .filterClicks ? "Klickfilter aktiv" : "Eigene Taps aktiv"
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
            guard isEnabled, settings.mode == .deliberateTaps else { return }
            cancelPendingTap()
            guard let releasePosition = CGEvent(source: nil)?.location else { return }
            let releaseApplication = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isEnabled, self.settings.mode == .deliberateTaps,
                    ProcessInfo.processInfo.systemUptime - time < 0.12,
                    NSWorkspace.shared.frontmostApplication?.processIdentifier == releaseApplication,
                    let currentPosition = CGEvent(source: nil)?.location,
                    hypot(currentPosition.x - releasePosition.x, currentPosition.y - releasePosition.y) < 4,
                    !SettingsStore.nativeTapPreferenceEnabled
                else { return }
                _ = self.mouse.postTap(fingers: fingers)
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

    private func shouldBlockClick(matches: Bool) -> Bool {
        guard isEnabled, settings.mode == .filterClicks else { return false }
        guard matches else {
            unknownSourceCount += 1
            return false
        }
        matchedCount += 1
        let block = engine.shouldBlockClick(at: ProcessInfo.processInfo.systemUptime)
        if block { blockedCount += 1 }
        return block
    }

    private func refreshPermissions() {
        hasAccessibility = AXIsProcessTrusted()
        if isEnabled
            && (!hasAccessibility || (settings.mode == .deliberateTaps && SettingsStore.nativeTapPreferenceEnabled))
        {
            isEnabled = false
            resetRecognition()
            status = "Schutz pausiert: Berechtigung oder Tap-Einstellung geändert."
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
