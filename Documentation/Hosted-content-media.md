# Hosted content media — 2026-10-22

## Scope and mapping

The 49 source photographs and 16 source movies under `ProjectMaterials/ContentImages` and `ContentVideos` resolve by their original filenames against:

- Photos: `https://pub-d00704a92e07453dbab85506699e0218.r2.dev/photo/`
- Movies: `https://pub-d00704a92e07453dbab85506699e0218.r2.dev/videos/`

Every original entry has an explicit `remoteURL` in `ProjectMaterials/content-slots.json`. Existing member IDs, authored copy, film IDs, engagement, room assignments and review holds are unchanged. The runtime manifest adds `imageSources`, `movieSources` and `posterSources` while preserving its existing content fields byte-for-value. It includes all 49 photographs and the existing 13 active movies (7 feed, 6 room). The 3 previously held movies retain URL mappings in the source manifest and remain excluded from display.

Historical `bundledFile` coding keys and aliases remain for persisted-record compatibility. They now resolve through the hosted movie dictionary; the player does not fall back to a packaged editorial movie. User-imported photos and movies still resolve to their own local files. Original UI artwork, fonts and voice-room stage backgrounds remain packaged, since they are outside the two requested folders.

## Loading and caching

`PhotoPixelCache` resolves existing artwork identifiers to HTTPS photograph URLs or remote film posters. It shares concurrent requests for the same photograph, uses an 8 MiB memory / 64 MiB disk HTTP cache, and keeps the existing 48 MiB bounded decoded-image cache. Network image responses require HTTP 200, an image MIME type, a nonempty body no larger than 25 MiB and a valid ImageIO decode. Decoding remains away from the main actor and targets the displayed size.

Failed image loads keep a stable placeholder and retry when the view is shown again or the app returns to the foreground. Existing source-identity and cancellation guards prevent late responses from displaying a different member's image. They do not substitute an unrelated photograph.

Video posters are extracted with AVAssetImageGenerator from the matching HTTPS movie at the original assigned timestamp. The existing bounded poster cache now keys by URL and timestamp. No poster files from the archived content catalog are read at runtime. The direct image paths in the full-portrait viewer and room backdrop also use the shared loader.

`FoodFilmPlayback` now accepts HTTPS resources in addition to genuine local imports. Remote movies are streamed by the existing single AVPlayer with an 8-second preferred forward buffer; no full-movie preload or competing list players were added. Ownership, stopping on departure/background, audio-session handling, failure state and the Retry action remain in place. Remote playback and poster extraction require connectivity when their data is not cached.

## App packaging and recovery

The former `Tati/Resources/KitchenMedia.xcassets` and `FoodFilms` directories were moved to `ProjectMaterials/PackagedMediaArchive/`. Originals remain in their original source directories with all 65 SHA-256 hashes unchanged. The archived app copies occupy 131,286,343 bytes (125.20 MiB) and are outside the app target. They are retained for recovery, with no runtime fallback to them.

`Scripts/import_content.py` now emits metadata and URL mappings only. It cannot silently restore bundled content or overwrite an existing recovery archive. The generated Xcode project has been refreshed to remove obsolete resource references. Current app resource sources are about 26.02 MiB; this is not an IPA or App Store download measurement.

## Verification and boundaries

- `Scripts/inspect_hosted_media.py`: all original hashes, per-file URL mappings, active/held separation, covers, poster mappings and removal from the generated app target checked.
- `Scripts/inspect_hosted_media.py --check-links`: HTTPS HEAD only, with certificate verification enabled. All 65 endpoints returned HTTP 200 after one transient connection failure was retried. All 16 videos advertise byte-range support. Full results are in `Remote-media-availability.json`; no media bodies were downloaded for this check.
- Prior content values compared to Git HEAD: unchanged. Plist/project syntax, referenced resources and touched-source whitespace checked.
- The older whole-delivery inspector was updated for hosted mappings but stopped at an existing missing Chinese translation for `About %@ min · Serves %@`. That unrelated catalog issue was not changed or presented as a passed whole-app audit.
- No Swift compilation, tests, app launch, native UI rendering, simulator/device/Duo posture, offline playback or actual streaming/seek playback was performed. HTTP reachability and range headers do not establish device playback success.

The initial Python HTTPS probe hit the workstation Python certificate-store configuration. The recorded successful probe uses the system curl trust store, with TLS checks kept on. No ATS exception or certificate-validation bypass was introduced in the application.
