import SwiftUI
@preconcurrency import AVFoundation
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

@MainActor struct ProfileStillCamera: UIViewControllerRepresentable {
    var complete: @MainActor (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(complete: complete) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.cameraCaptureMode = .photo
        if UIImagePickerController.isCameraDeviceAvailable(.front) { picker.cameraDevice = .front }
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.complete = complete
    }
    static func dismantleUIViewController(_ picker: UIImagePickerController, coordinator: Coordinator) {
        picker.delegate = nil
    }

    @MainActor final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var complete: @MainActor (UIImage?) -> Void
        private var finished = false
        init(complete: @escaping @MainActor (UIImage?) -> Void) { self.complete = complete }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard !finished else { return }; finished = true
            complete((info[.editedImage] ?? info[.originalImage]) as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !finished else { return }; finished = true
            complete(nil)
        }
    }
}

final class CameraPhotoJPEG: @unchecked Sendable {
    private let image: UIImage
    private let queue = DispatchQueue(label: "tati.profile.photo.encoding", qos: .userInitiated)
    init(_ image: UIImage) { self.image = image }
    func data() async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: image.jpegData(compressionQuality: 0.85))
            }
        }
    }
}

@MainActor final class FoodFilmPlayback: ObservableObject {
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
    private var audioActivation: Task<Void, Never>?
    private var audioOwner: UUID?
    private var audioReady = false
    func load(id: String, url: URL, owner: String, loops: Bool = false) throws {
        stop()
        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        } else {
            guard url.scheme == "https", url.host != nil else { throw URLError(.unsupportedURL) }
        }
        let request = generation
        let item = AVPlayerItem(url: url)
        if !url.isFileURL { item.preferredForwardBufferDuration = 8 }
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
                    || (self?.audioReady == false && self?.wantsToPlay == true)
            }
        }
        failedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard self?.generation == request, self?.activeID == id, self?.ownerID == owner else { return }; self?.playing = false; self?.wantsToPlay = false; self?.loading = false; self?.failure = "This video cannot be played. Tap Retry to open it again." }
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

        audioOwner = request
        audioActivation = Task { [weak self] in
            do {
                try await MediaAudioSession.shared.activate(owner: request, recording: false)
                guard let self, self.generation == request, !Task.isCancelled else {
                    MediaAudioSession.shared.release(owner: request)
                    return
                }
                self.audioReady = true
                self.loading = self.wantsToPlay
                if self.wantsToPlay { self.player?.play() }
            } catch {
                guard let self, self.generation == request else { return }
                MediaAudioSession.shared.release(owner: request)
                self.audioOwner = nil
                self.audioReady = false
                self.playing = false; self.wantsToPlay = false; self.loading = false
                self.failure = "This video cannot be played. Tap Retry to open it again."
            }
        }
    }
    func toggle() {
        guard let player, failure == nil else { return }
        wantsToPlay.toggle()
        if wantsToPlay {
            loading = !audioReady
            if audioReady { player.play() }
        } else { player.pause(); playing = false; loading = false }
    }
    func stop() {
        guard player != nil || activeID != nil || failure != nil || wantsToPlay || loading || audioOwner != nil else { return }
        generation = UUID()
        audioActivation?.cancel(); audioActivation = nil
        audioReady = false
        statusObserver = nil; playbackObserver = nil
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil; activeID = nil; ownerID = nil; playing = false
        wantsToPlay = false; loading = false
        if let owner = audioOwner {
            audioOwner = nil
            MediaAudioSession.shared.release(owner: owner)
        }
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
        if view.videoLayer.player !== player { view.videoLayer.player = player }
        let gravity: AVLayerVideoGravity = fillsContainer ? .resizeAspectFill : .resizeAspect
        if view.videoLayer.videoGravity != gravity { view.videoLayer.videoGravity = gravity }
    }
    static func dismantleUIView(_ view: ClipLayerView, coordinator: ()) { view.videoLayer.player = nil }
}

private final class CameraCaptureWorker: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "tati.camera.preview", qos: .userInitiated)

    func start(position: AVCaptureDevice.Position) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    continuation.resume(returning: false)
                    return
                }
                session.beginConfiguration()
                let previousInputs = session.inputs
                session.inputs.forEach { session.removeInput($0) }
                guard session.canAddInput(input) else {
                    previousInputs.filter { session.canAddInput($0) }.forEach { session.addInput($0) }
                    session.commitConfiguration()
                    continuation.resume(returning: false)
                    return
                }
                session.addInput(input)
                session.commitConfiguration()
                session.startRunning()
                continuation.resume(returning: session.isRunning)
            }
        }
    }

    func stop() { queue.async { [self] in session.stopRunning() } }
}

@MainActor final class KitchenCameraController: ObservableObject {
    enum StartOutcome: Equatable { case ready, declined, settingsRequired, restricted, unavailable, cancelled }
    private let capture = CameraCaptureWorker()
    var session: AVCaptureSession { capture.session }
    @Published var status = "Camera is off"
    @Published var ready = false
    @Published private(set) var starting = false
    @Published private(set) var frontFacing = true
    private var generation = UUID()
    @discardableResult func start(front: Bool? = nil) async -> StartOutcome {
        guard !starting else { return .cancelled }
        starting = true; defer { starting = false }
        ready = false
        let requestID = UUID(); generation = requestID
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .denied { return .settingsRequired }
        if authorization == .restricted { return .restricted }
        let authorized = await AVCaptureDevice.requestAccess(for: .video)
        guard generation == requestID, !Task.isCancelled else { return .cancelled }
        guard authorized else { status = "Camera is off"; return .declined }
        let nextFront = front ?? frontFacing
        let configured = await capture.start(position: nextFront ? .front : .back)
        guard generation == requestID, !Task.isCancelled else { stop(); return .cancelled }
        ready = configured
        if configured { frontFacing = nextFront }
        status = configured ? "Camera is on · not broadcasting" : "The camera couldn't be started. Try again."
        return configured ? .ready : .unavailable
    }
    func stop() { generation = UUID(); ready = false; status = "Camera is off"; capture.stop() }
}
final class CameraLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var cameraLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var mirrored: Bool?
    override func layoutSubviews() {
        super.layoutSubviews()
        if let mirrored, let connection = cameraLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
struct CameraSurface: UIViewRepresentable {
    var session: AVCaptureSession
    var mirrored: Bool? = nil
    func makeUIView(context: Context) -> CameraLayerView { let view = CameraLayerView(); view.cameraLayer.videoGravity = .resizeAspectFill; view.cameraLayer.session = session; return view }
    func updateUIView(_ view: CameraLayerView, context: Context) {
        if view.cameraLayer.session !== session { view.cameraLayer.session = session }
        view.mirrored = mirrored; view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: CameraLayerView, coordinator: ()) { view.cameraLayer.session = nil }
}

actor VideoPosterCache {
    static let shared = VideoPosterCache()
    private let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()
    func image(at url: URL, seconds: Double = 0) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let key = (url.absoluteString + "|" + String(seconds)) as NSString
        if let image = images.object(forKey: key) { return image }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        do {
            let (frame, _) = try await withTaskCancellationHandler {
                try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            } onCancel: {
                generator.cancelAllCGImageGeneration()
            }
            guard !Task.isCancelled else { return nil }
            let image = UIImage(cgImage: frame)
            images.setObject(image, forKey: key, cost: frame.bytesPerRow * frame.height)
            return image
        } catch { return nil }
    }
}

struct LocalVideoPoster: View {
    let url: URL
    var height: CGFloat = 210
    @Environment(\.scenePhase) private var scenePhase
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    private struct LoadKey: Hashable { let url: URL; let active: Bool }
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image, loadedURL == url {
                    Image(uiImage: image).resizable().scaledToFill()
                } else { MediaPlaceholder(title: "Video", height: height) }
            }
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .frame(height: height)
        .task(id: LoadKey(url: url, active: scenePhase == .active)) {
            guard scenePhase == .active, loadedURL != url else { return }
            let prepared = await VideoPosterCache.shared.image(at: url)
            guard !Task.isCancelled else { return }
            image = prepared
            if prepared != nil { loadedURL = url }
        }
    }
}

final class MediaAudioSession: @unchecked Sendable {
    static let shared = MediaAudioSession()
    private let queue = DispatchQueue(label: "tati.audio.session", qos: .userInitiated)
    private var owner: UUID?
    private var recording = false
    private init() {}

    @MainActor
    func activate(owner token: UUID, recording: Bool) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                let session = AVAudioSession.sharedInstance()
                do {
                    try session.setCategory(recording ? .record : .playback,
                                            mode: recording ? .measurement : .default, options: [])
                    try session.setActive(true)
                    owner = token
                    self.recording = recording
                    continuation.resume()
                } catch {

                    try? session.setActive(false, options: .notifyOthersOnDeactivation)
                    try? session.setCategory(.playback, mode: .default)
                    owner = nil
                    self.recording = false
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    func awaitNativeRelease() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
    }
    func release(owner token: UUID) {
        queue.async { [self] in
            guard owner == token else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            if recording { try? session.setCategory(.playback, mode: .default) }
            owner = nil
            recording = false
        }
    }
}

@MainActor extension MemberKitchenStore {

    func explainCameraAvailability(_ outcome: KitchenCameraController.StartOutcome) {
        switch outcome {
        case .settingsRequired:
            confirm("Camera unavailable", "Camera access is off. You can continue without a camera, or review access in Settings.", button: "Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        case .restricted:
            tell("Camera unavailable", "Camera access is restricted. You can continue without a camera.")
        case .ready, .declined, .unavailable, .cancelled: break
        }
    }
}
