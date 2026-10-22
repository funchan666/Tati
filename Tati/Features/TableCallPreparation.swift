import SwiftUI
import AVFoundation

private enum TableCallControl: Int {
    case microphone, microphoneOff, camera, cameraOff, flipCamera, leave
}

private struct TableCallControlArt: View {
    let control: TableCallControl
    var side: CGFloat = 64
    var body: some View {
        Image("table-call-controls").resizable()
            .frame(width: side * 3, height: side * 2)
            .offset(x: -CGFloat(control.rawValue % 3) * side, y: -CGFloat(control.rawValue / 3) * side)
            .frame(width: side, height: side, alignment: .topLeading).clipped()
            .accessibilityHidden(true)
    }
}

struct TableCallPreparationView: View {
    let person: TableMember
    let kind: ConversationCallKind
    @EnvironmentObject private var store: MemberKitchenStore
    @EnvironmentObject private var playback: FoodFilmPlayback
    @EnvironmentObject private var roomSession: CookingRoomSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var camera = KitchenCameraController()
    @State private var preparation: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var ownerID: String?
    @State private var phase = Phase.preparing
    @State private var microphoneReady = false
    private let ink = Color(red: 0.13, green: 0.18, blue: 0.08)
    private let porcelain = Color(red: 0.99, green: 0.96, blue: 0.88)
    private let sage = Color(red: 0.81, green: 0.86, blue: 0.70)
    private enum Phase: Equatable { case preparing, ready, paused, cameraOff, cameraSettings, microphoneSettings, cameraRestricted, unavailable }
    private var eligible: Bool { ownerID == store.account.profile.id && store.canCommunicate(with: person.id) }
    private var busy: Bool { phase == .preparing || camera.starting }
    private var needsSettings: Bool { phase == .cameraSettings || phase == .microphoneSettings }
    private var status: String {
        switch phase {
        case .preparing: return "Preparing your call…"
        case .ready: return "Ready on your side"
        case .paused: return "Call preparation paused"
        case .cameraOff: return "Camera is off"
        case .cameraSettings: return "Camera access is off"
        case .microphoneSettings: return "Microphone access is off"
        case .cameraRestricted: return "Camera access is restricted"
        case .unavailable: return "The camera couldn't be started. Try again."
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    header
                    if kind == .video {
                        identity(compact: true)
                        videoPreview(height: max(210, min(460, geometry.size.height * 0.52)))
                    } else {
                        Spacer(minLength: 12)
                        identity(compact: false)
                    }
                    VStack(spacing: 14) {
                        Text(LocalizedStringKey(status)).font(.tati(.title3, weight: .semibold))
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        if microphoneReady {
                            HStack(spacing: 8) {
                                TableCallControlArt(control: .microphone, side: 28)
                                Text("Microphone access ready").font(.tati(.caption))
                            }.foregroundStyle(sage)
                        }
                        recovery
                    }
                    if kind == .voice { Spacer(minLength: 24) }
                    Text("No call is connected. Your camera and microphone are not shared.")
                        .font(.tati(.footnote)).foregroundStyle(sage).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true).padding(14)
                        .frame(maxWidth: 400).background(ink.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
                }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 24)
                    .frame(maxWidth: 680).frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .foregroundStyle(porcelain)
        .background {
            GeometryReader { geometry in
                Image("table-call-backdrop").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }.ignoresSafeArea(.container)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .tatiScreen()
        .task { ownerID = store.account.profile.id; prepare() }
        .onDisappear { stopPreparation() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { stopPreparation(); self.phase = .paused }
        }
        .onChange(of: store.mutualIDs) { _, _ in endIfUnavailable() }
        .onChange(of: store.account.profile.id) { _, _ in endIfUnavailable() }
        .onChange(of: store.account.signedIn) { _, _ in endIfUnavailable() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification, object: camera.session)) { _ in
            stopPreparation(); phase = .paused
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(LocalizedStringKey(kind.title)).font(.tati(.caption, weight: .semibold)).tracking(1.5).textCase(.uppercase)
            Spacer(minLength: 8)
            Text("Not connected").font(.tati(.caption)).foregroundStyle(sage)
        }.accessibilityElement(children: .combine)
    }

    private func identity(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 24) {
            Avatar(asset: person.portraitArtwork, size: compact ? 64 : 164)
            Text(person.name).font(.tati(compact ? .title : .largeTitle, design: .serif, weight: .semibold))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(person.interest)).font(.tati(.subheadline)).foregroundStyle(sage)
        }.frame(maxWidth: .infinity)
    }

    private func videoPreview(height: CGFloat) -> some View {
        ZStack {
            ink
            if camera.ready {
                CameraSurface(session: camera.session, mirrored: camera.frontFacing)
            } else {
                VStack(spacing: 14) {
                    TableCallControlArt(control: .cameraOff, side: 94)
                        .phaseAnimator(phase == .preparing && scenePhase == .active && !reduceMotion ? [false, true] : [false]) { content, lifted in
                            content.scaleEffect(lifted ? 1.05 : 1)
                        } animation: { _ in .easeInOut(duration: 0.9) }
                    Text(LocalizedStringKey(phase == .preparing ? "Preparing your preview…" : "Your preview is off"))
                        .font(.tati(.subheadline)).foregroundStyle(sage).multilineTextAlignment(.center)
                }.padding(24)
            }
        }.frame(height: height).clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(alignment: .bottomLeading) {
                Text("Only you").font(.tati(.caption, weight: .semibold)).foregroundStyle(porcelain)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(ink.opacity(0.85), in: Capsule()).padding(14)
            }
            .accessibilityLabel(camera.ready ? "Your camera preview. Only you can see it." : "Your preview is off")
    }

    @ViewBuilder private var recovery: some View {
        if needsSettings {
            Text("You can close this screen or review access in Settings.")
                .font(.tati(.footnote)).foregroundStyle(sage).multilineTextAlignment(.center)
            Button("Open Settings") {
                guard eligible, let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }.font(.tati(.subheadline, weight: .semibold)).foregroundStyle(porcelain)
                .frame(minHeight: 44).buttonStyle(.plain)
        } else if phase == .paused || phase == .unavailable || phase == .cameraOff {
            Button(kind == .video ? "Resume preview" : "Prepare call") { prepare() }
                .font(.tati(.subheadline, weight: .semibold)).foregroundStyle(porcelain)
                .frame(minHeight: 44).buttonStyle(.plain).disabled(camera.starting)
        }
    }

    private var controls: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) { controlButtons }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) { controlButtons }.fixedSize(horizontal: true, vertical: false)
                    VStack(spacing: 8) { controlButtons }
                }
            }
        }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
            .frame(maxWidth: .infinity).background(ink.opacity(0.97))
    }

    @ViewBuilder private var controlButtons: some View {
        if kind == .video {
            control(camera.ready ? .cameraOff : .camera, title: camera.ready ? "Camera off" : "Preview camera", disabled: busy) {
                if camera.ready { stopPreparation(); phase = .cameraOff }
                else { prepare() }
            }
            control(.flipCamera, title: "Switch camera", disabled: busy || !camera.ready) { flipCamera() }
        }
        control(.leave, title: "Close call") { finish() }
    }

    private func control(_ artwork: TableCallControl, title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                TableCallControlArt(control: artwork)
                Text(LocalizedStringKey(title)).font(.tati(.caption, weight: .semibold))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(minWidth: 72, minHeight: 88).opacity(disabled ? 0.45 : 1)
        }.buttonStyle(.plain).disabled(disabled).accessibilityLabel(LocalizedStringKey(title))
    }

    private func prepare() {
        guard eligible else { finish(); return }
        guard !camera.starting, scenePhase != .background else { return }
        stopPreparation()
        let token = requestID
        phase = .preparing; microphoneReady = false
        playback.stop(); roomSession.audio.stop()
        preparation = Task { @MainActor in
            guard await awaitForeground(token) else { return }
            if kind == .video {
                let outcome = await camera.start()
                guard isCurrent(token) else { return }
                guard outcome == .ready else { handleCamera(outcome); return }
                guard await awaitForeground(token) else { camera.stop(); return }
            }
            let previous = AVAudioApplication.shared.recordPermission
            if previous == .denied { camera.stop(); phase = .microphoneSettings; return }
            let approved: Bool
            if previous == .granted { approved = true }
            else {
                approved = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
                }
            }
            guard isCurrent(token) else { return }
            guard approved else { finish(); return }
            microphoneReady = true; phase = .ready
        }
    }

    private func flipCamera() {
        guard eligible, !busy, camera.ready else { return }
        let front = !camera.frontFacing
        stopPreparation()
        let token = requestID
        phase = .preparing
        preparation = Task { @MainActor in
            let outcome = await camera.start(front: front)
            guard isCurrent(token) else { return }
            if outcome == .ready { phase = .ready }
            else { handleCamera(outcome) }
        }
    }

    private func handleCamera(_ outcome: KitchenCameraController.StartOutcome) {
        camera.stop()
        switch outcome {
        case .ready: phase = .ready
        case .declined: finish()
        case .settingsRequired: phase = .cameraSettings
        case .restricted: phase = .cameraRestricted
        case .unavailable: phase = .unavailable
        case .cancelled: phase = .paused
        }
    }
    private func isCurrent(_ token: UUID) -> Bool { requestID == token && !Task.isCancelled && eligible && scenePhase != .background }
    private func awaitForeground(_ token: UUID) async -> Bool {
        for _ in 0..<20 {
            guard isCurrent(token) else { return false }
            if UIApplication.shared.applicationState == .active { return true }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
        }
        phase = .paused
        return false
    }
    private func stopPreparation() { requestID = UUID(); preparation?.cancel(); preparation = nil; camera.stop() }
    private func finish() { stopPreparation(); dismiss() }
    private func endIfUnavailable() { if !eligible { finish() } }
}
