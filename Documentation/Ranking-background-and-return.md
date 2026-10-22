# Ranking background and return

2026-10-22. Screenshot follow-up.

- The supplied rank-background now extends behind the entire viewport, including the status and bottom safe areas. The scroll content uses the same original artwork behind the controls, podium and list instead of limiting it to a cropped stage panel. The original asset is unchanged.
- Portraits and their heart frames share the same aspect-fill scale, horizontal offset and safe-area offset. Header height is measured independently; larger translated controls move artwork and portraits together without moving the controls themselves.
- Return and category/period controls remain at the top while scrolling. Empty content reserves their measured height.
- Background layers explicitly disable hit testing. The old clipped oversized stage image was a possible interception source: clipping visible drawing alone does not limit hit-test bounds. This diagnosis is source-based, not a recorded runtime trace.
- The discovery entry owns showRankings and presents the destination through navigationDestination. The 48-point return button clears that same binding; a dismiss fallback remains for other callers. Profile links inside the ranking still push normally.

Source and diff inspection completed; git diff --check passed. No build, tests, simulator launch, screenshots or device interaction were performed. Runtime follow-up: open/return/reopen, scroll before returning, change category/period, push a ranked profile and return, check large text and resizing.
