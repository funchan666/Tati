import SwiftUI
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

struct ImportedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in SentTransferredFile(movie.url) } importing: { received in
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}
@MainActor final class ClipPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var activeID: String?
    @Published private(set) var ownerID: String?
    @Published private(set) var playing = false
    @Published private(set) var wantsToPlay = false
    @Published private(set) var loading = false
    @Published private(set) var failure: String?
    private var statusObserver: NSKeyValueObservation?
    private var playbackObserver: NSKeyValueObservation?
    private var failedObserver: NSObjectProtocol?
    private var endedObserver: NSObjectProtocol?
    private var generation = UUID()
    func load(id: String, url: URL, owner: String, loops: Bool = false) throws {
        stop()
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        let request = generation
        let item = AVPlayerItem(url: url)
        let nextPlayer = AVPlayer(playerItem: item)
        player = nextPlayer; activeID = id; ownerID = owner
        wantsToPlay = true; loading = true
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor in
                guard self?.generation == request, self?.activeID == id, self?.ownerID == owner else { return }
                if status == .failed {
                    self?.player?.pause(); self?.playing = false
                    self?.wantsToPlay = false; self?.loading = false
                    self?.failure = "This video cannot be played. Tap Retry to open it again."
                }
            }
        }
        playbackObserver = nextPlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                guard self?.generation == request else { return }
                self?.playing = status == .playing
                self?.loading = status == .waitingToPlayAtSpecifiedRate
            }
        }
        failedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard self?.generation == request, self?.activeID == id, self?.ownerID == owner else { return }; self?.playing = false; self?.wantsToPlay = false; self?.loading = false; self?.failure = "Playback stopped because the file could not be read." }
        }
        endedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == request, self.activeID == id, self.ownerID == owner else { return }
                self.playing = false
                if loops && self.wantsToPlay {
                    self.player?.seek(to: .zero) { [weak self] finished in
                        Task { @MainActor in
                            guard finished, let self, self.generation == request, self.wantsToPlay, self.failure == nil else { return }
                            self.player?.play()
                        }
                    }
                } else {
                    self.wantsToPlay = false; self.loading = false
                    self.player?.seek(to: .zero)
                }
            }
        }
        // Start both list and detail playback; AVPlayer waits until the item is ready.
        nextPlayer.play()
    }
    func toggle() {
        guard let player, failure == nil else { return }
        wantsToPlay.toggle()
        if wantsToPlay { player.play() } else { player.pause(); playing = false; loading = false }
    }
    func stop() {
        generation = UUID()
        statusObserver = nil; playbackObserver = nil
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil; activeID = nil; ownerID = nil; playing = false
        wantsToPlay = false; loading = false
        if let endedObserver { NotificationCenter.default.removeObserver(endedObserver) }
        endedObserver = nil
        if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }
        failedObserver = nil; failure = nil
    }
}
final class ClipLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
struct ClipSurface: UIViewRepresentable {
    var player: AVPlayer?
    var fillsContainer = false
    func makeUIView(context: Context) -> ClipLayerView { ClipLayerView() }
    func updateUIView(_ view: ClipLayerView, context: Context) {
        view.videoLayer.player = player
        view.videoLayer.videoGravity = fillsContainer ? .resizeAspectFill : .resizeAspect
    }
    static func dismantleUIView(_ view: ClipLayerView, coordinator: ()) { view.videoLayer.player = nil }
}
@MainActor final class CameraPreviewController: ObservableObject {
    let session = AVCaptureSession()
    @Published var status = "Camera is off"
    @Published var ready = false
    @Published private(set) var starting = false
    private let queue = DispatchQueue(label: "tati.camera.preview")
    private var generation = UUID()
    func start(requiresMicrophone: Bool = false) async {
        guard !starting else { return }
        starting = true; defer { starting = false }
        let requestID = UUID(); generation = requestID
        let authorized = await AVCaptureDevice.requestAccess(for: .video)
        guard generation == requestID, !Task.isCancelled else { return }
        guard authorized else { status = "Camera access was denied. You can allow it in iOS Settings."; return }
        if requiresMicrophone {
            let microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
            guard generation == requestID, !Task.isCancelled else { return }
            guard microphoneAllowed else { status = "Microphone access was denied. Allow it in iOS Settings before continuing."; return }
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front), let input = try? AVCaptureDeviceInput(device: device) else { status = "No camera is available."; return }
        let capture = session
        let configured = await withCheckedContinuation { continuation in
            queue.async {
                capture.beginConfiguration()
                capture.inputs.forEach { capture.removeInput($0) }
                guard capture.canAddInput(input) else { capture.commitConfiguration(); continuation.resume(returning: false); return }
                capture.addInput(input); capture.commitConfiguration(); capture.startRunning()
                continuation.resume(returning: true)
            }
        }
        guard generation == requestID, !Task.isCancelled else { stop(); return }
        ready = configured; status = configured ? "Camera is on · not broadcasting" : "The camera couldn't be started. Try again."
    }
    func stop() { generation = UUID(); ready = false; status = "Camera is off"; let capture = session; queue.async { capture.stopRunning() } }
}
final class CameraLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var cameraLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
struct CameraSurface: UIViewRepresentable {
    var session: AVCaptureSession
    func makeUIView(context: Context) -> CameraLayerView { let view = CameraLayerView(); view.cameraLayer.videoGravity = .resizeAspectFill; view.cameraLayer.session = session; return view }
    func updateUIView(_ view: CameraLayerView, context: Context) {}
    static func dismantleUIView(_ view: CameraLayerView, coordinator: ()) { view.cameraLayer.session = nil }
}

struct LocalVideoPoster: View {
    let url: URL
    var height: CGFloat = 210
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill().frame(height: height).clipped() }
            else { MediaPlaceholder(title: "Video", height: height) }
        }.task(id: url) {
            image = nil
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 800, height: 800)
            do {
                let (frame, _) = try await generator.image(at: .zero)
                guard !Task.isCancelled else { return }
                image = UIImage(cgImage: frame)
            } catch { /* Keep the explicit local-media fallback; do not invent a cover. */ }
        }
    }
}
