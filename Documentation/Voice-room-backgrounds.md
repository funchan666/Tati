# Voice room backgrounds

- The supported originals are `stage-blue`, `stage-gifts`, and `stage-purple`. The original image files are unchanged.
- `VoiceRoomBackground` is the shared catalog used by room rendering, room settings, and the voice room creation form.
- On account load, missing or obsolete voice room background assignments are randomly selected among the least-used originals and saved in `LocalAccount.roomBackgrounds`. Existing valid choices are preserved. Reopening a room or restarting does not reroll it. Account deletion starts a new assignment set at sign-in.
- `VoiceRoomBackgroundArtwork` uses the actual container dimensions with `scaledToFill` and clipping. Room backgrounds extend under system safe areas; controls keep their safe-area layout. The same fill behavior is used in the picker and full-screen artwork view.
- The voice discovery create button navigates to `CreateVoiceRoomView`. Title, topic, and selected background are persisted in the existing drafts dictionary. Leaving the form or restarting retains these choices.
- The project does not have a voice-room publication endpoint or RTC hosting implementation. The Create room action saves setup and explicitly reports that creation is unavailable. It does not fabricate a published room, audience, or audio session. A future creation request must include the selected background identifier.

Verification for this change is limited to source, artwork references, and diff inspection. No compilation, tests, simulator, device, or service checks were run.
