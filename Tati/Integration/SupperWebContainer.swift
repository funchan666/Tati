import SwiftUI
import WebKit
import AVFoundation

@MainActor
final class SupperWebOwner: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var webView: MountedSupperWebView?
    var didFinish: (() -> Void)?
    var didFail: (() -> Void)?
    private var generation = UUID()
    private var currentNavigation: WKNavigation?
    private var navigationIDs: [ObjectIdentifier: UUID] = [:]
    private var responseAccepted = false
    private var documentFinished = false
    private var deadline: Task<Void, Never>?
    private var trustedOrigin: WebOrigin?
    private var pending: [UUID: (WKPermissionDecision) -> Void] = [:]
    private var cameraRequest: Task<Bool, Never>?
    private var microphoneRequest: Task<Bool, Never>?
    private(set) var destination: URL?
    private var valid = false
    private var remaining: TimeInterval = 30
    private var activeSince: Date?
    struct WebOrigin: Equatable {
        let scheme: String; let host: String; let port: Int
        init?(_ url: URL?) {
            guard let url, let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty, ["http", "https"].contains(scheme) else { return nil }
            self.scheme = scheme; self.host = host; port = url.port ?? (scheme == "https" ? 443 : 80)
        }
        init?(_ security: WKSecurityOrigin) {
            guard let url = URL(string: "\(security.protocol)://\(security.host)\(security.port > 0 ? ":\(security.port)" : "")") else { return nil }
            self.init(url)
        }
    }
    func prepare(_ url: URL) {
        destination = url; trustedOrigin = WebOrigin(url); valid = true
        if webView == nil {
            let configuration = WKWebViewConfiguration()
            configuration.allowsAirPlayForMediaPlayback = true
            configuration.allowsInlineMediaPlayback = true
            configuration.mediaTypesRequiringUserActionForPlayback = []
            configuration.websiteDataStore = .default()
            let view = MountedSupperWebView(frame: .zero, configuration: configuration)
            view.scrollView.contentInsetAdjustmentBehavior = .never
            view.allowsBackForwardNavigationGestures = true
            view.navigationDelegate = self; view.uiDelegate = self
            view.mounted = { [weak self] in self?.commitIfReady() }
            webView = view
        }
        beginLoad(url)
    }
    private func beginLoad(_ url: URL) {
        guard let webView else { return }
        invalidateNavigation(); valid = true
        let captured = generation
        webView.stopLoading(); armDeadline()
        Task {
            await MediaAudioSession.shared.awaitNativeRelease()
            guard valid, captured == generation else { return }
            webView.setCameraCaptureState(.none) { [weak self] in
                Task { @MainActor in
                    guard let self, self.valid, captured == self.generation else { return }
                    webView.setMicrophoneCaptureState(.none) { [weak self] in
                        Task { @MainActor in
                            guard let self, self.valid, captured == self.generation else { return }
                            self.currentNavigation = webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
                            if let navigation = self.currentNavigation { self.navigationIDs[ObjectIdentifier(navigation)] = captured }
                            self.remaining = 30; self.armDeadline()
                        }
                    }
                }
            }
        }
    }
    private func invalidateNavigation() {
        generation = UUID(); deadline?.cancel(); deadline = nil
        currentNavigation = nil; navigationIDs.removeAll(); responseAccepted = false; documentFinished = false
        remaining = 30; activeSince = nil
        let callbacks = pending.values; pending.removeAll(); callbacks.forEach { $0(.deny) }
    }
    private func armDeadline() {
        deadline?.cancel()
        guard valid, !documentFinished, UIApplication.shared.applicationState == .active else { return }
        activeSince = Date(); let captured = generation
        deadline = Task {
            do { try await Task.sleep(for: .seconds(max(0.01, remaining))) } catch { return }
            guard valid, captured == generation else { return }; failure()
        }
    }
    func setActive(_ active: Bool) {
        if let since = activeSince { remaining = max(0, remaining - Date().timeIntervalSince(since)); activeSince = nil }
        deadline?.cancel(); deadline = nil
        if active { armDeadline(); commitIfReady() }
    }
    private func matches(_ navigation: WKNavigation?) -> Bool {
        guard valid, let navigation else { return false }
        return navigationIDs[ObjectIdentifier(navigation)] == generation
    }
    private func commitIfReady() {
        guard valid, documentFinished, responseAccepted, let webView, webView.window != nil, webView.bounds.width > 0, webView.bounds.height > 0, UIApplication.shared.applicationState == .active else { return }
        deadline?.cancel(); deadline = nil; didFinish?()
    }
    private func failure() {
        guard valid else { return }
        valid = false; invalidateNavigation(); webView?.stopLoading()
        webView?.pauseAllMediaPlayback(completionHandler: {})
        webView?.setCameraCaptureState(.none, completionHandler: {})
        webView?.setMicrophoneCaptureState(.none, completionHandler: {})
        didFail?()
    }
    func stop() {
        valid = false; invalidateNavigation()
        webView?.stopLoading(); webView?.pauseAllMediaPlayback(completionHandler: {})
        webView?.setCameraCaptureState(.none, completionHandler: {})
        webView?.setMicrophoneCaptureState(.none, completionHandler: {})
        webView?.navigationDelegate = nil; webView?.uiDelegate = nil; webView?.mounted = nil
        webView = nil; trustedOrigin = nil; destination = nil
    }
    func retry() { if let destination { prepare(destination) } }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard valid, let navigation else { return }
        if currentNavigation == nil {
            currentNavigation = navigation; navigationIDs[ObjectIdentifier(navigation)] = generation
        } else if currentNavigation !== navigation {
            invalidateNavigation(); currentNavigation = navigation; navigationIDs[ObjectIdentifier(navigation)] = generation; armDeadline()
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard valid, let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        guard ConfiguredCoreEvent.webURL(url.absoluteString) != nil else {
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated { UIApplication.shared.open(url) }
            return
        }
        if navigationAction.targetFrame == nil { decisionHandler(.cancel); webView.load(navigationAction.request); return }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard valid else { decisionHandler(.cancel); return }
        if navigationResponse.isForMainFrame {
            let mime = navigationResponse.response.mimeType?.lowercased()
            responseAccepted = (navigationResponse.response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } == true && navigationResponse.canShowMIMEType && ["text/html", "application/xhtml+xml"].contains(mime ?? "")
            if !responseAccepted { decisionHandler(.cancel); failure(); return }
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard matches(navigation), responseAccepted else { return }
        documentFinished = true; deadline?.cancel(); deadline = nil; commitIfReady()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if matches(navigation) { failure() } }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if matches(navigation) { failure() } }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure() }
    private func originIsTrusted(_ origin: WKSecurityOrigin, _ frame: WKFrameInfo) -> Bool {
        guard valid, let trustedOrigin, WebOrigin(origin) == trustedOrigin, WebOrigin(frame.securityOrigin) == trustedOrigin,
              WebOrigin(webView?.url) == trustedOrigin else { return false }
        return true
    }
    private func systemPermission(_ kind: AVMediaType) async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: kind)
        if status == .authorized { return true }
        guard status == .notDetermined else { return false }
        if kind == .video {
            if let cameraRequest { return await cameraRequest.value }
            let task = Task { await AVCaptureDevice.requestAccess(for: .video) }; cameraRequest = task
            let granted = await task.value; cameraRequest = nil; return granted
        }
        if let microphoneRequest { return await microphoneRequest.value }
        let task = Task { await AVCaptureDevice.requestAccess(for: .audio) }; microphoneRequest = task
        let granted = await task.value; microphoneRequest = nil; return granted
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard originIsTrusted(origin, frame) else { decisionHandler(.deny); return }
        let id = UUID(), captured = generation; pending[id] = decisionHandler
        Task {
            var granted = true
            switch type {
            case .camera: granted = await systemPermission(.video)
            case .microphone: granted = await systemPermission(.audio)
            case .cameraAndMicrophone:
                let camera = await systemPermission(.video)
                if camera { granted = await systemPermission(.audio) } else { granted = false }
            @unknown default: granted = false
            }
            guard let callback = pending.removeValue(forKey: id) else { return }
            callback(captured == generation && originIsTrusted(origin, frame) && granted ? .grant : .deny)
        }
    }
}

final class MountedSupperWebView: WKWebView {
    var mounted: (() -> Void)?
    override func didMoveToWindow() { super.didMoveToWindow(); mounted?() }
    override func layoutSubviews() { super.layoutSubviews(); mounted?() }
}
struct SupperWebSurface: UIViewRepresentable {
    let view: MountedSupperWebView
    func makeUIView(context: Context) -> MountedSupperWebView { view }
    func updateUIView(_ uiView: MountedSupperWebView, context: Context) { }
}
