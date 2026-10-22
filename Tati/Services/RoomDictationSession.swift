import SwiftUI
import Speech
import AVFoundation
import UIKit

@MainActor final class RoomDictationSession: ObservableObject {
    enum Phase { case idle, authorizing, listening, finishing }
    @Published private(set) var phase: Phase = .idle
    var isBusy: Bool { phase != .idle }
    var status: String {
        switch phase {
        case .idle: return ""
        case .authorizing: return "Preparing voice input…"
        case .listening: return "Listening… Tap to stop"
        case .finishing: return "Finishing your words…"
        }
    }

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var permissionTask: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var tapInstalled = false
    private var audioOwner: UUID?
    private var generation = UUID()
    private var updateText: ((String) -> Void)?
    private var reportError: ((String, Bool) -> Void)?
    private var receivedWords = false

    func start(update: @escaping (String) -> Void, failure: @escaping (String, Bool) -> Void) {
        guard !isBusy else { return }
        cancel()
        let token = generation
        updateText = update; reportError = failure
        phase = .authorizing
        permissionTask = Task { [weak self] in
            guard let self else { return }
            let microphoneBefore = AVAudioApplication.shared.recordPermission
            if microphoneBefore == .denied {
                self.fail("Voice input is unavailable while microphone access is off. You can type instead.", settings: true)
                return
            }
            let microphone = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard self.generation == token, !Task.isCancelled else { return }
            guard microphone else {
                self.cancel()
                return
            }
            let speechBefore = SFSpeechRecognizer.authorizationStatus()
            if speechBefore == .denied {
                self.fail("Voice input is unavailable while speech recognition is off. You can type instead.", settings: true)
                return
            }
            if speechBefore == .restricted {
                self.fail("Speech recognition is restricted on this device. You can still type your message.")
                return
            }
            let authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard self.generation == token, !Task.isCancelled else { return }
            guard authorization == .authorized else {
                self.cancel()
                return
            }

            for _ in 0..<15 {
                guard self.generation == token, !Task.isCancelled else { return }
                if UIApplication.shared.applicationState == .active { break }
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
            guard self.generation == token, !Task.isCancelled else { return }
            guard UIApplication.shared.applicationState == .active else { self.cancel(); return }
            await self.beginRecognition(token: token)
        }
    }

    private func beginRecognition(token: UUID) async {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            fail("Speech recognition is unavailable for your device language right now. Please try again or type your message.")
            return
        }
        self.recognizer = recognizer
        do {
            audioOwner = token
            try await MediaAudioSession.shared.activate(owner: token, recording: true)
            guard generation == token, !Task.isCancelled,
                  UIApplication.shared.applicationState == .active else {
                MediaAudioSession.shared.release(owner: token)
                if generation == token { cancel() }
                return
            }
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                fail("No microphone is available. Connect a microphone and try again.")
                return
            }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            self.request = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            tapInstalled = true
            recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let failed = error != nil
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let text, !text.isEmpty {
                        self.receivedWords = true
                        self.updateText?(text)
                    }
                    guard self.generation == token else { return }
                    if final {
                        if self.receivedWords { self.cancel() }
                        else { self.fail("No words were detected. Tap the microphone and try speaking again.") }
                    }
                    else if failed {
                        if self.phase == .finishing, self.receivedWords { self.cancel() }
                        else { self.fail("Speech input stopped. Your words have been kept; check your connection and try again.") }
                    }
                }
            }
            engine.prepare()
            try engine.start()
            phase = .listening
            observeInterruptions()
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(55)) } catch { return }
                guard let self, self.generation == token else { return }
                self.finish()
            }
        } catch {
            guard generation == token else { return }
            fail("The microphone couldn't start. Close other recording apps and try again.")
        }
    }

    func finish() {
        guard phase == .listening else { cancel(); return }
        phase = .finishing
        stopCapture()
        request?.endAudio()
        recognition?.finish()
        timeout?.cancel()
        let token = generation
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, self.generation == token else { return }
            if self.receivedWords { self.cancel() }
            else { self.fail("No words were detected. Tap the microphone and try speaking again.") }
        }
    }

    func cancel() {
        generation = UUID()
        permissionTask?.cancel(); permissionTask = nil
        timeout?.cancel(); timeout = nil
        stopCapture()
        request?.endAudio(); recognition?.cancel()
        recognition = nil; request = nil; recognizer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }; observers.removeAll()
        updateText = nil; reportError = nil; receivedWords = false
        phase = .idle
    }

    private func stopCapture() {
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if let owner = audioOwner {
            audioOwner = nil
            MediaAudioSession.shared.release(owner: owner)
        }
    }

    private func fail(_ message: String, settings: Bool = false) {
        let callback = reportError
        cancel()
        callback?(message, settings)
    }

    private func observeInterruptions() {
        let token = generation
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if notification.name == AVAudioSession.routeChangeNotification {
                    let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
                    let reason = AVAudioSession.RouteChangeReason(rawValue: raw)

                    guard reason == .oldDeviceUnavailable || reason == .newDeviceAvailable || reason == .noSuitableRouteForCategory else { return }
                }
                if notification.name == AVAudioSession.interruptionNotification {
                    let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
                    guard AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                }
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token, self.phase == .listening else { return }
                    self.fail("Speech input was interrupted. Your words have been kept. Tap the microphone to continue.")
                }
            }
            observers.append(observer)
        }
    }
}
