# Application responsiveness: source-level optimization

Scope: existing SwiftUI app, original artwork, current navigation and business contracts. No build, tests, simulator, Instruments, device run or before/after timing was performed. These are identified source costs and their changes, not measured frame-rate results.

## Images and scrolling

- `ContentPhoto`, `Avatar`, profile covers, saved attachments and profile-edit photo previews use background preparation instead of full-size image/file decoding in view bodies.
- Bundled artwork is preserved. Imported files are immutable UUID-named originals; display thumbnails are memory-only. File thumbnails use ImageIO orientation transforms. Fallback artwork, fill/fit and crop alignment stay explicit.
- Photo requests use container size and display scale, bucketed to 64 pixels. A resize keeps the previous image of the same source while its new size loads. A different source cannot display the previous person's image.
- The shared decoded-photo cache has count and cost limits (96 entries / 48 MiB). Extremely elongated images have a maximum prepared edge of 2560 pixels. Selected in-memory photos retain a prepared preview per selection; editing text does not decode them repeatedly.
- Video poster frames are cached separately (24 entries / 24 MiB). Leaving a row or backgrounding cancels unfinished AVAssetImageGenerator work. Player-layer updates avoid rebinding an unchanged AVPlayer.
- Relationship, blacklist and personal-video pages opt into lazy content. Forms keep their existing eager layout so focus and validation behavior are preserved.

## Input and data

- Room and conversation text remains view-local while typing. Draft writes are coalesced after 400 ms of inactivity, rather than encoding/writing/reading/decoding the entire account for each character.
- Leaving a room/conversation, leaving the active app state, and logout flush pending drafts. Tasks are cancelled when replaced, explicitly saved, successfully sent, or deleted with the old profile. Pending text carries its owning profile ID.
- Explicit send still uses the existing synchronous durable-write path. Successful sends cancel pending draft writes so text cannot reappear after sending. Identical draft contents skip redundant writes.
- As with other debounce schemes, an abrupt process kill before the pending write or lifecycle flush can lose the last partial draft. This is not a durable queue or remote message transport.
- Conversation messages are grouped and sorted once per account revision. Message previews/search reuse that index; block and hidden-message filtering remains current. Catalogue person/gift lookup uses stable ID dictionaries, preserving first-match semantics.
- Comment counters filter/count without building and sorting a full comment timeline.

## Animation and lifecycle

- Live badges keep scale/opacity breathing and existing visibility, scene and Reduce Motion gates. Their blur shadow is no longer animated per frame.
- Room activity playback suspends its task while a user reads history, instead of waking every second to check. Returning to latest activity resumes the existing script position.
- Tapping the already-selected tab does not stop playback or reselect the screen. Existing stop/leave/background rules remain.

## Retained contracts and remaining runtime checks

Account write verification, transaction evidence, balance mutations, import validation, and explicit sends were not made fire-and-forget. Original media, account JSON schema and purchase-recovery contracts are unchanged. Important saves and imports still have synchronous persistence costs; profile before changing those contracts.

Static review covered resource/source inclusion, request cancellation, bounded caches, crop/resize handling, draft ownership and send cancellation, account-index invalidation and `git diff --check`.

When runtime verification is authorized, measure cold/warm navigation, fast feed scrolling, typing with a large account history, cover replacement, background/foreground transitions, immediate send/back/logout after typing, low-memory behavior, and resizing/inner-outer display transitions. Collect main-thread stalls and memory before claiming a frame-rate or latency improvement.
