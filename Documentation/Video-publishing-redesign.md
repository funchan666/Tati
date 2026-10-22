# Video publishing — 2026-10-22

Scope: `PublishVideoView` and its media-selection label in `FoodVideos.swift`.

## Layout

- An olive selection surface pairs a large serif headline with Tati's original `discovery-live-camera` illustration. The lime library action and file limit belong to the selection surface.
- After selection, a larger cached poster replaces the illustration. The editor displays the selected asset's actual duration and byte size, with actions to replace or remove it.
- A separate story composer has a readable placeholder, focus outline and live 50-character count. Removing/replacing a video preserves the caption.
- Footer feedback explains missing requirements, import state and the existing private-until-approved behavior. All 23 affected publisher labels, statuses and errors have English, Simplified Chinese, Spanish, French, German and Japanese translations.

## Interaction and ownership

The library remains the genuine Photos picker. Import validates a nonempty file, the 250 MB size limit and finite positive duration. Large file copying runs in a detached worker with only immutable URL captures; the UI shows an importing state without fake upload percentages. The existing selection is replaced only after a successful copy. Cancelled/obsolete imports clean their destination, and account changes cannot attach the imported video to a different account. Picker selection resets after each attempt, allowing the same item to be selected again. No additional AVPlayer or audio session is created.

Submission retains `VisitorStore.submitPost` and `pendingReview`; it is local persistence, not a new remote upload or review service. A storage failure retains the editing state. Navigation away cleans uncommitted media, while a successful submission retains the referenced file.

## Adaptive layout and verification

Content stays in the existing safe-area-aware scrolling editing container. No screen dimensions, global windows or new capture sessions are introduced. The action/file-limit group can stack at narrow widths; accessibility text sizes omit decorative artwork. Input and selection remain view state across container resizing. Actual Duo posture, keyboard, picker-presentation and VoiceOver behavior still require device verification.

Performed: source/diff inspection, localization JSON and six-locale completeness checks, original asset-reference checks. Not performed: compilation, tests, simulator/device launch or rendered-screen review.
