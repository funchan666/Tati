# Person profile portfolio — 2026-10-22

The screenshot's white information slab has been replaced with two distinct surfaces: a warm apricot identity section and an olive video portfolio. The existing full-width portrait, photo viewer, safe-area navigation and push-based profile route remain.

The identity section uses a serif name, readable biography, original food artwork chosen from the person's interest, native localized interest/language labels, and new follow/chat controls. It has no second avatar, gift affordance, fabricated activity statistics or verification claims. `FollowControl.Style.profile` still uses the shared `VisitorStore.isFollowing` and durable `setFollowing` path, so the control remains synchronized with other screens.

The portfolio uses the actual visible clip count. A single clip gets a wide cover; multiple clips use one, two or three columns according to the container width and accessibility text size. Tiles omit the repeated author/avatar while retaining original cached posters, full-screen playback, shared live like/comment counts and actions, comment-to-profile dismissal handoff, and video report/block options. Empty portfolios use the original food-camera illustration. No player is created by a tile.

`FoodTopicArtwork` extracts the existing six-cell original raster atlas display into a shared display-only view. Discovery food selectors retain the same crop, size, selected outline and interaction; profiles reuse the display without introducing an inert button. No original files were overwritten or new artwork drawn in code.

New labels “Food moments” and “Say hello” have English, Simplified Chinese, Spanish, French, German and Japanese translations. Names, biography, counts and location remain existing content.

Static verification: source and diff inspection, localization JSON/six-language checks, artwork references, and shared follow/comment/safety route inspection. No build, tests, simulator, native rendered-screen review, device or Duo-posture verification was performed. The layout uses the current navigation container and local geometry, retains state across width changes and collapses action rows/removes decorative artwork for accessibility sizes; actual long-text, keyboard and device behavior still requires runtime verification.
