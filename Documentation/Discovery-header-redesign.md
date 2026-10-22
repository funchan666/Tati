# Discovery header redesign

2026-10-22. Scope: the marked messages entry, live-room creation entry and browse controls.

- Original pink/lime raster message artwork replaces the flat icon tile in the shared toolbar entry. Its destination remains ConversationsView.
- A dark olive live-creation banner pairs the original chef-camera artwork with native localized text and a lime Go Live action. The entire banner opens the existing GoLiveView; it does not change broadcast capabilities.
- Pink section selection and an illustrated horizontal food menu replace the text-only strips. Each food image comes from an original six-cell raster atlas. Labels remain native, wrap and scale with Dynamic Type. The selected food uses a pink border and bold label.
- Filters stay outside the horizontal scroller, with existing active-count, sheet handoff and persisted home/voice selections. Shared voice browsing uses the same controls without gaining a live-creation entry.
- Section animation is local to the navigation row, respects Reduce Motion and does not animate the room grid. Layout follows the existing safe-area-aware, width-constrained screen container.

Source, asset metadata, localization references and git diff whitespace inspected. Generated artwork was visually inspected. No build, test, simulator or actual screen rendering was performed. Device follow-up remains: narrow widths, accessibility text, long translated labels, filter-sheet return and all navigation destinations.

Artwork prompts and paths: [Discovery-artwork-prompts.md](Discovery-artwork-prompts.md).
