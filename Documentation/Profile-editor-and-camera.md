# Profile editor and photo capture

2026-10-22. Scope: edit-profile layout and real album/camera avatar replacement.

## Interface

The photo section now pairs a cover image with an overlapping portrait, dark olive surface and separate Photo library / Take photo actions. Cover selection and both reset actions remain available. Text fields share one grouped surface with smaller labels, natural-height native inputs and existing name/bio limits. Favourite food reuses the illustrated FoodTopicTile from discovery. The existing keyboard-aware form retains the save action above the keyboard.

Camera artwork: `Tati/Resources/TatiArtwork.xcassets/profile-photo-camera.imageset/art.png`.
Original transparent artwork was generated with the built-in image tool in Host-Native mode and visually inspected. Supplied artwork is unchanged.

## Media behavior

- The system PhotosPicker handles album selection, including iCloud-backed items. No full-library permission is requested just to select a photo. Avatar and cover imports validate image data and the existing 25 MB limit; a failed or cancelled load preserves the previous preview and other form edits. Selection is cleared after loading so the same image can be selected again.
- Take photo first checks camera availability and requests the genuine video/camera authorization. Denial offers the real iOS Settings destination. Presentation waits until the scene is active. A device without a camera offers the album alternative.
- The genuine UIImagePickerController camera presents full screen, in photo mode, with the front camera when available. Its genuine editing flow provides a crop before returning the selected image. Cancelling leaves the prior avatar untouched. UIKit owns camera capture and dismissal; no parallel custom capture session or microphone request is started.
- An immutable UIImage owner encodes the captured result to JPEG on a serial background queue. The editor previews it before save. Inputs and save are protected while a media request is in progress; cancelled/stale loads and changed account ownership cannot replace another profile's image.
- Saving retains the existing verified account writer and media import/cleanup rules. New files are attached only after successful persistence, then the prior unused media are cleaned up. The app's existing profile consumers read the updated avatar from the same account state. This is local profile storage; no remote upload endpoint is implemented or claimed.
- Camera usage wording is updated in both Info.plist and project.yml so regeneration preserves it. New controls and permission/status copy have six language translations.

## Static evidence and remaining validation

Inspected source, media ownership/cancellation, permission outcomes, local persistence, image asset references and JSON/plist syntax. Checked camera APIs against the installed UIKit SDK headers. Apple web documentation returned JavaScript/unsupported-Markdown responses, so it was not treated as verified page content. git diff --check passed.

No build, tests, app launch, simulator/device session, real permission prompt, camera capture, photo-library selection or rendered-screen verification was performed. Runtime follow-up: grant/deny/revoke camera access, cancel capture and album selection, repeat the same selection, iCloud loading failure, crop/save/reopen, reset photos, storage failure, keyboard, large text and container resizing. Camera capture needs a physical device; a simulator's camera-unavailable result does not validate capture.

## Generation prompt

Use case: stylized-concept. ONE original transparent cutout icon for Tati iOS profile photo editing. A compact glossy hot-pink STILL-PHOTO camera, big round dark olive lens with bright chartreuse lens ring, a small cream shutter button, and a tiny cream chef hat on its top left. Simple front three-quarter view, polished candy-resin 3D render with soft studio highlights. Consistent with a playful food-social app, palette #FE68B9 pink, #D3FE2E lime, warm cream, deep olive details. Bold clean silhouette readable at 30px. Square composition with generous 14% transparent margin, actual alpha transparency, no text, no square background tile, no ground plane, no watermark, no video-camera side wing. Native app artwork asset, not screenshot.
