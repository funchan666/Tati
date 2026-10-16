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
    @Published private(set) var playing = false
    private var endedObserver: NSObjectProtocol?
    func load(id: String, url: URL) throws {
        stop()
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item); activeID = id
        endedObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.playing = false; self?.player?.seek(to: .zero) }
        }
    }
    func toggle() {
        guard let player else { return }
        if playing { player.pause(); playing = false } else { player.play(); playing = true }
    }
    func stop() {
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil; activeID = nil; playing = false
        if let endedObserver { NotificationCenter.default.removeObserver(endedObserver) }
        endedObserver = nil
    }
}
final class ClipLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
struct ClipSurface: UIViewRepresentable {
    var player: AVPlayer?
    func makeUIView(context: Context) -> ClipLayerView { let view = ClipLayerView(); view.videoLayer.videoGravity = .resizeAspect; return view }
    func updateUIView(_ view: ClipLayerView, context: Context) { view.videoLayer.player = player }
    static func dismantleUIView(_ view: ClipLayerView, coordinator: ()) { view.videoLayer.player = nil }
}
@MainActor final class CameraPreviewController: ObservableObject {
    let session = AVCaptureSession()
    @Published var status = "Camera is off"
    @Published var ready = false
    private let queue = DispatchQueue(label: "tati.camera.preview")
    private var generation = UUID()
    func start() async {
        let requestID = UUID(); generation = requestID
        let authorized = await AVCaptureDevice.requestAccess(for: .video)
        guard generation == requestID, !Task.isCancelled else { return }
        guard authorized else { status = "Camera access was denied. You can allow it in iOS Settings."; return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front), let input = try? AVCaptureDeviceInput(device: device) else { status = "No camera is available on this device."; return }
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
        ready = configured; status = configured ? "Local camera preview · not broadcasting" : "The camera couldn't be started. Try again."
    }
    func stop() { generation = UUID(); ready = false; let capture = session; queue.async { capture.stopRunning() } }
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
