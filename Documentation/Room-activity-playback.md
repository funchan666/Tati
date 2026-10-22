# Room activity playback

The ten bundled rooms each have an explicitly authored presentation script: eight unique comments and four gift entries, with room-specific participants, gift quantities and timing. These are not realtime user events or verified purchases. The source of truth is `ProjectMaterials/content-slots.json` → `curatedRoomActivity`; `Scripts/import_content.py` carries it into the bundled `content-library.json` without changing media.

`RoomActivityFeed` is shared by video and voice rooms. It seeds four eligible events on entry (including a gift), then advances the room's script at its configured cadence. Events reuse stable IDs and the in-memory display is bounded to 30 rows. New account room messages and gift records join the same chronological presentation as they arrive, without being copied into the authored script. Existing local records are never rewritten by the feed.

Playback cancels when the view disappears, a room panel opens, or the app becomes inactive. It resumes at the next event on return. Manually dragging the feed pauses scripted progression and auto-scrolling; Latest activity resumes both. Reduce Motion disables insertion and scrolling animation. The feed size follows the existing MediaViewport container; the microphone stage remains scrollable.

Both displayed and newly replayed events respect blocked authors and `roomMessage:<stable-event-id>` hidden subjects. Profiles use the existing full-page navigation. Script playback does not write private messages, follow relationships, gift receipts, coin balances, presence or microphone occupants. Realtime room events still require a service integration; replace presentation scripts with authoritative events when that integration is supplied.

Static inspection confirmed all ten configured room IDs are covered, all 120 event IDs are unique, all 80 comments differ, and all referenced profiles and gift artwork exist. Manifest and bundled scripts match. No build, tests, simulator, device or realtime-service validation was performed.
