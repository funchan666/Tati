# Screenshot diagnostics — 2026-10-22

Source-only repair against the current Xcode SDK headers and the app's iOS 17 deployment target. No build, tests, simulator or device run was performed.

- `PolicyWebView.Coordinator` now has one navigation-response policy callback, with the SDK's `@MainActor @Sendable` completion handler. HTTP errors still cancel the main-frame load and expose the retry state.
- Photo/video picker labels receive snapshots of account file names and the selected movie URL. They no longer access those main-actor store values inside the picker label.
- Profile handoff uses `navigationDestination(item:)`. Feed destinations are registered on their enclosing screens outside lazy rows; room/video detail destinations remain on their own screen. Comment sheets dismiss before requesting a push.
- `CameraCaptureWorker` creates camera inputs, configures the capture session and starts/stops it on one serial queue. Its `@unchecked Sendable` assertion is limited to this queue-confined owner; the immutable session reference is also handed to the preview layer. `@preconcurrency import AVFoundation` bridges the framework's remaining imported concurrency annotations, rather than making arbitrary capture objects Sendable.
- `MediaAudioSession` serializes category changes, activation and deactivation on a non-main queue, retaining iOS 17 compatibility. Its mutable owner token and recording flag are queue-confined. Release is conditional on the requesting token; stale completions cannot release the next owner.
- Music, speech and video await activation before starting their I/O. They pause/stop I/O before queuing release. Cancellation, leaving a room, changing a video and backgrounding invalidate the corresponding request before a late activation can start playback/capture. Video activation is ordered after previous music/speech cleanup.

Static checks: inspected the installed WebKit/AVFAudio headers, affected call sites, navigation registration locations, original resource references and `git diff --check`.

Still requires an explicitly authorized build and runtime check: compiler diagnostics, first permission grant, repeated start/stop, leaving during activation, music-to-dictation-to-video transitions, interruptions, background/foreground, and comment-to-profile/back navigation from every feed entry. No claim is made that the screenshot's runtime warnings have been re-tested or cleared in Xcode.

## Authorized build follow-up — 2026-10-22

The user subsequently requested compilation and fixes until success. Xcode 27.1 (27A9275), iPhoneSimulator 27.1 SDK, Debug configuration, generic iOS Simulator destination, arm64 and x86_64, signing disabled:

- First build failed because string catalog keys differing only by punctuation/case generated duplicate Swift symbols (`Check in`/`Check-in`, `Go Live`/`Go live`, etc.).
- Disabled unused string symbol generation with `STRING_CATALOG_GENERATE_SYMBOLS = NO` in both project configurations and `project.yml`. Existing translations and string-key lookups are preserved.
- Second build exited 0 with `BUILD SUCCEEDED`. No Swift source warnings/errors. One App Intents metadata warning remains because this app does not depend on AppIntents.framework.
- Build log: `/tmp/tati-build.6zbClO/build-2.log`.
- Product: `/tmp/tati-build.6zbClO/DerivedData/Build/Products/Debug-iphonesimulator/Tati.app` (both simulator architectures confirmed).

This supersedes the earlier unperformed-build statement only. No tests, app launch, device execution, distribution archive or runtime hang verification were performed.
