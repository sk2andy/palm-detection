import PalmGuardCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("PalmGuard", systemImage: "hand.raised.fill")
                            .font(.largeTitle.bold())
                        Text("Platz für deine Hände. Kontrolle für deine Taps.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.isEnabled ? "Pausieren" : "Schutz aktivieren") { model.toggleProtection() }
                        .buttonStyle(.borderedProminent)
                        .tint(model.isEnabled ? .orange : .accentColor)
                        .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Label(model.status, systemImage: model.isEnabled ? "checkmark.shield.fill" : "eye")
                        .font(.headline)
                        .foregroundStyle(model.isEnabled ? .green : .primary)
                        .accessibilityIdentifier("protectionStatus")
                    HStack {
                        Text(model.deviceName).foregroundStyle(.secondary)
                        Spacer()
                        Button("Neu verbinden") { model.reconnect() }
                    }
                    if !model.hasAccessibility {
                        HStack {
                            Text("Zum Erzeugen von Taps braucht PalmGuard die Freigabe für Bedienungshilfen.")
                                .font(.callout)
                            Spacer()
                            Button("Freigeben …") { model.requestAccessibility() }
                        }
                        HStack {
                            Text("Freigabe schon an? PalmGuard entfernen und diese App erneut hinzufügen.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("App im Finder zeigen") { model.revealApp() }
                        }
                    }
                }
                .padding(16)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Deine erlaubte Fläche").font(.title2.bold())
                        Spacer()
                        Button("Standard") { model.settings.configuration.area = .default }
                        Button("Ganze Fläche") {
                            model.settings.configuration.area = TapArea(minX: 0, minY: 0, maxX: 1, maxY: 1)
                        }
                    }
                    Text("Ziehe ein Rechteck. Grün erlaubt Taps; der Rand bleibt für Handgelenke frei.")
                        .font(.callout).foregroundStyle(.secondary)
                    TrackpadAreaView(
                        area: $model.settings.configuration.area,
                        contacts: model.contacts, maximumSize: model.settings.configuration.maximumSize
                    )
                    .frame(height: 260)
                    HStack {
                        Text("← links · oben = Tastatur · unten = zu dir")
                        Spacer()
                        Text("\(model.frameCount) Kontaktbilder")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    AreaControls(area: $model.settings.configuration.area)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Nur Taps innerhalb der Fläche").font(.headline)
                    Text(
                        "Ein Finger = Linksklick. Zwei Finger = Rechtsklick. Druck-Klicks funktionieren überall. Drei-Finger-Drags bleiben auch mit Fingern außerhalb der Fläche frei."
                    )
                    .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Label(
                            nativeTapStatus,
                            systemImage: model.nativeTapSetting == .disabled ? "checkmark.circle" : "info.circle"
                        )
                        .foregroundStyle(model.nativeTapSetting == .disabled ? .green : .secondary)
                        Spacer()
                        Button("Trackpad-Einstellungen …") { model.openSettings("Trackpad") }
                    }
                    if model.nativeTapSetting == .unknown {
                        Toggle(
                            "Natives Tippen zum Klicken ist ausgeschaltet",
                            isOn: $model.settings.nativeTapsDisabledConfirmed)
                    }
                    Text("Erzeugte Tap-Klicks: \(model.postedTapCount)")
                        .font(.caption.monospacedDigit())
                }

                DisclosureGroup("Empfindlichkeit & Diagnose") {
                    VStack(alignment: .leading, spacing: 12) {
                        settingSlider(
                            "Max. Tap-Dauer", value: $model.settings.configuration.maximumDuration,
                            range: 0.08...0.5,
                            valueText: "\(Int(model.settings.configuration.maximumDuration * 1000)) ms")
                        settingSlider(
                            "Max. Bewegung", value: $model.settings.configuration.maximumMovement,
                            range: 0.005...0.08,
                            valueText: "\(Int(model.settings.configuration.maximumMovement * 100)) %")
                        settingSlider(
                            "Max. Kontaktgröße", value: $model.settings.configuration.maximumSize,
                            range: 0.1...5, valueText: String(format: "%.2f", model.settings.configuration.maximumSize))
                        Text(
                            "Kontaktgröße ist ein relativer Sensorwert. Mit Live-Kontakten kalibrieren; kein Maß in mm²."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        Text(model.lastDecision).font(.callout.monospacedDigit())
                        Text(
                            "Tap-Kandidaten: \(model.acceptedCount) erkannt · \(model.rejectedCount) verworfen. Vorschau zählt mit."
                        )
                        .font(.caption)
                        if !model.contacts.isEmpty {
                            Text(
                                model.contacts.map { "#\($0.id): \(String(format: "%.2f", $0.size))" }.joined(
                                    separator: "   ")
                            )
                            .font(.caption.monospaced())
                        }
                        Button("Eingabeüberwachung öffnen …") { model.openSettings("Privacy_ListenEvent") }
                    }.padding(.top, 12)
                }
                Text(
                    "Die Fläche gilt ausschließlich für Taps. Druck-Klicks, Scrollen und native Drags übernimmt macOS. Drei-Finger-Ziehen muss in den macOS-Bedienungshilfen aktiviert sein. Tastatur und Hyperkey bleiben unverändert."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .frame(width: 780, height: 820)
        .alert(item: $model.activationProblem) { problem in
            Alert(
                title: Text("Schutz kann nicht aktiviert werden"),
                message: Text(problem.explanation(appPath: model.appPath)),
                primaryButton: .default(Text(problem.recoveryTitle)) { model.recoverActivation(problem) },
                secondaryButton: .cancel(Text("Schließen")))
        }
    }

    private var nativeTapStatus: String {
        switch model.nativeTapSetting {
        case .disabled: "macOS-Tippen zum Klicken: aus · PalmGuard übernimmt"
        case .enabled: "macOS-Tippen zum Klicken zuerst ausschalten"
        case .unknown: "macOS-Tap-Einstellung bitte selbst prüfen"
        }
    }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String)
        -> some View
    {
        HStack {
            Text(title).frame(width: 145, alignment: .leading)
            Slider(value: value, in: range)
            Text(valueText).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
    }
}

private struct AreaControls: View {
    @Binding var area: TapArea

    var body: some View {
        HStack(spacing: 18) {
            edge("Links", keyPath: \.minX, range: 0...(area.maxX - 0.02))
            edge("Rechts", keyPath: \.maxX, range: (area.minX + 0.02)...1)
            edge("Unten", keyPath: \.minY, range: 0...(area.maxY - 0.02))
            edge("Oben", keyPath: \.maxY, range: (area.minY + 0.02)...1)
        }
    }

    private func edge(_ label: String, keyPath: WritableKeyPath<TapArea, Double>, range: ClosedRange<Double>)
        -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label) \(Int(area[keyPath: keyPath] * 100)) %").font(.caption.monospacedDigit())
            Slider(value: Binding(get: { area[keyPath: keyPath] }, set: { area[keyPath: keyPath] = $0 }), in: range)
                .accessibilityLabel(label)
        }
    }
}

private struct TrackpadAreaView: View {
    @Binding var area: TapArea
    let contacts: [TouchContact]
    let maximumSize: Double
    @State private var dragArea: TapArea?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let shown = dragArea ?? area
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color.secondary.opacity(0.13))
                Path { path in
                    for fraction in [0.25, 0.5, 0.75] {
                        path.move(to: CGPoint(x: size.width * fraction, y: 0))
                        path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                        path.move(to: CGPoint(x: 0, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                }.stroke(.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                RoundedRectangle(cornerRadius: 8)
                    .fill(.green.opacity(0.13))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.green, lineWidth: 2))
                    .frame(
                        width: (shown.maxX - shown.minX) * size.width,
                        height: (shown.maxY - shown.minY) * size.height
                    )
                    .position(
                        x: (shown.minX + shown.maxX) / 2 * size.width,
                        y: (1 - (shown.minY + shown.maxY) / 2) * size.height)
                Text("TAP-BEREICH").font(.caption.weight(.semibold)).tracking(2)
                    .foregroundStyle(.green.opacity(0.7))
                    .position(
                        x: (shown.minX + shown.maxX) / 2 * size.width,
                        y: (1 - (shown.minY + shown.maxY) / 2) * size.height)
                ForEach(contacts, id: \.id) { contact in
                    let allowed = area.contains(contact.position) && contact.size <= maximumSize
                    Circle().fill(allowed ? Color.green : Color.orange)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(
                            width: 18 + min(32, max(0, contact.size * 10)),
                            height: 18 + min(32, max(0, contact.size * 10))
                        )
                        .position(x: contact.position.x * size.width, y: (1 - contact.position.y) * size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { drag in dragArea = rectangle(from: drag.startLocation, to: drag.location, size: size) }
                    .onEnded { drag in
                        area = rectangle(from: drag.startLocation, to: drag.location, size: size).sanitized
                        dragArea = nil
                    }
            )
            .accessibilityLabel("Erlaubte Trackpad-Fläche. Alternativ die vier Regler verwenden.")
        }
    }

    private func rectangle(from start: CGPoint, to end: CGPoint, size: CGSize) -> TapArea {
        TapArea(
            minX: Double(min(start.x, end.x) / size.width),
            minY: 1 - Double(max(start.y, end.y) / size.height),
            maxX: Double(max(start.x, end.x) / size.width),
            maxY: 1 - Double(min(start.y, end.y) / size.height)
        ).sanitized
    }
}
