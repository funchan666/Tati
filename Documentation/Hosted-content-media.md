# Hosted content media — 2026-10-22

## Scope and mapping

The 49 photographs and 16 movies resolve by their recorded original filenames against:

- Photos: `https://pub-d00704a92e07453dbab85506699e0218.r2.dev/photo/`
- Movies: `https://pub-d00704a92e07453dbab85506699e0218.r2.dev/videos/`

Every original entry has an explicit `remoteURL` in `ProjectMaterials/content-slots.json`. The server catalog at `Docs/BackendAPI/responses/table-catalog.json` carries `imageSources`, `movieSources` and `posterSources`, preserving existing member IDs, film IDs and room assignments. Following the user's subsequent request to use every video, all 16 movies are now active: 10 feed movies and 6 room movies. All 49 photographs remain assigned. The former exclusions for `sample-clip-6`, `sample-clip-13` and `sample-clip-15` are explicitly false; prior notes are retained as historical `previousReviewNote` metadata and do not control visibility. The everyday-moment video's caption and comments were made consistent with the visible personal update.

The restored feed entries retain their existing authors and distinct editorial engagement: 458 likes / 4 comments, 652 likes / 6 comments and 1,189 likes / 11 comments. They use the same remote-poster, playback, profile navigation and comment report/block paths as the other feed entries. Individual user hide/block choices still apply.

Historical `bundledFile` coding keys and aliases remain for persisted-record compatibility. They now resolve through the hosted movie dictionary; the player does not fall back to a packaged editorial movie. User-imported photos and movies still resolve to their own local files. Original UI artwork, fonts and voice-room stage backgrounds remain packaged, since they are outside the two requested folders.

## Loading and caching

`PhotoPixelCache` resolves existing artwork identifiers to HTTPS photograph URLs or remote film posters. It shares concurrent requests for the same photograph, uses an 8 MiB memory / 64 MiB disk HTTP cache, and keeps the existing 48 MiB bounded decoded-image cache. Network image responses require HTTP 200, an image MIME type, a nonempty body no larger than 25 MiB and a valid ImageIO decode. Decoding remains away from the main actor and targets the displayed size.

Failed image loads keep a stable placeholder and retry when the view is shown again or the app returns to the foreground. Existing source-identity and cancellation guards prevent late responses from displaying a different member's image. They do not substitute an unrelated photograph.

Video posters are extracted with AVAssetImageGenerator from the matching HTTPS movie at the original assigned timestamp. The existing bounded poster cache now keys by URL and timestamp. No poster files from the archived content catalog are read at runtime. The direct image paths in the full-portrait viewer and room backdrop also use the shared loader.

`FoodFilmPlayback` now accepts HTTPS resources in addition to genuine local imports. Remote movies are streamed by the existing single AVPlayer with an 8-second preferred forward buffer; no full-movie preload or competing list players were added. Ownership, stopping on departure/background, audio-session handling, failure state and the Retry action remain in place. Remote playback and poster extraction require connectivity when their data is not cached.

## App packaging and recovery

Following the user's explicit request to remove local copies, `ContentImages`, `ContentVideos`, `PackagedMediaArchive` and `ContentReviewHold` were deleted. Derived content-audit images were also deleted. This removed 268 files totalling 295,006,288 bytes (281.34 MiB of working-tree file contents). UI artwork, fonts, text/JSON audit records, and user-imported application data were not deleted. The removal inventory is in `Local-content-cleanup.json`.

`content-slots.json` retains each `remoteURL`, `originalFilename`, `originalSHA256` and `originalByteCount`. Hashes are historical provenance, not a claim that deleted files were rehashed. `Scripts/import_content.py` updates only the deployment catalog in Docs, with metadata and URL mappings without opening local source files, downloading replacements or recreating archives. The generated Xcode project already excludes content media. After lossless UI resource compression and removal of an unused runtime copy, app resource sources occupy 23,652,947 bytes; this is not an IPA or App Store download measurement. Current details are in `Resource-delivery-sizes.json`.

## Verification and boundaries

- Before cleanup, all 65 originals matched their recorded hashes. After cleanup, `Scripts/inspect_hosted_media.py` checks hosted records, per-file URL mappings, inclusion of all 16 movies, covers, poster mappings, removal from the generated app target and absence of local source/backup folders. It validates historical hash format without reading deleted files.
- `Scripts/inspect_hosted_media.py --check-links`: HTTPS HEAD only, with certificate verification enabled. All 65 endpoints returned HTTP 200 after one transient connection failure was retried. All 16 videos advertise byte-range support. Full results are in `Remote-media-availability.json`; no media bodies were downloaded for this check.
- The initial hosting migration preserved prior content values against Git HEAD. Subsequent changes enabled the three former exclusions and revised the personal-update copy described above. Local cleanup changes only the source manifest/provenance and tooling; runtime content, remote URLs and the 10-feed/6-room allocation remain intact. The generator and hosted-record checker run successfully without the deleted source files.
- The older inspector initially stopped at missing recipe/proper-name translations. These entries and the migrated catalog assertions were corrected during Prada integration; the current offline whole-delivery inspection passes. Its report is static evidence only.
- No Swift compilation, tests, app launch, native UI rendering, simulator/device/Duo posture, offline playback or actual streaming/seek playback was performed. HTTP reachability and range headers do not establish device playback success.

The initial Python HTTPS probe hit the workstation Python certificate-store configuration. The recorded successful probe uses the system curl trust store, with TLS checks kept on. No ATS exception or certificate-validation bypass was introduced in the application.
