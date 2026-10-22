# Separate room controls

The current room screen is a participant/viewer surface, not a host console. Native SwiftUI and original raster icons are retained.

| Capability | Video room | Voice room |
| --- | --- | --- |
| Picture fill/fit, original video sound, activity visibility | Viewing options | Not exposed |
| Speech-to-text into the message field | Not exposed in tools | Voice input; explicit permission and review before send |
| Three original full-bleed backgrounds | Not exposed; video cover cannot be replaced by a voice stage | Stored per room ID; personal appearance only |
| Imported audio | Not exposed | Listening music, personal playback only |
| Minimize | Not supported | Supported by room session |
| Report/block and leave | Supported | Supported |

`RoomPanel.supports(voice:)` gates both tool selection and presentation. Inappropriate invitation, host layout and mixed camera controls have been removed from participant menus. Legacy saved layout data is retained but does not create unconnected video tiles. Empty voice seats explain the unavailable live connection and offer actual speech input; they no longer request microphone permission merely to simulate joining a seat.

The menu and exit sheets use cream surfaces, readable white rows, separate safety/exit actions, original raster artwork and content-aware scrolling/detents. Containers cap content width without depending on device dimensions. Speech starts only after its sheet dismisses; scene, visibility and current-room checks prevent delayed starts in another room.

Audio replacement validates first, enforces the 50 MB limit, and preserves the previous file on failure. File import callbacks check the room and audio-session revision. Cancelling Files does not show a failure. Playback failure releases its audio session; an inactive player no longer deactivates unrelated video/speech audio. Audio is reset when entering a different room. No shared-room broadcast, queue invitation or host-control service is claimed.

Validation: source branch and call-site inspection, original resource references, six-language catalog structure, and git diff whitespace checks only. No compile, tests, simulator, device, permission-prompt or live-service checks were run. Runtime transitions, audio interruptions and expanded/folded layouts still require device validation.
