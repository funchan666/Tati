# Profile summary and messages

2026-10-22. Scope: the marked biography/interest/relationship summary and message entry on the current user's profile.

- Biography, interest and relationship navigation are integrated into one dark olive profile card. Native cream text, a lime food-interest label and original friendly sharing-plate artwork establish a food-community identity. The supplied cover, account editing row, check-in and wallet entries retain their existing roles.
- Relationship counts use large rounded numerals with cream, pink and lime accents. Values still come from followingIDs, followerIDs and mutualIDs; no seed followers or fabricated counts were added. All three entries retain their original RelationshipView destinations.
- Accessibility text sizes switch the counts from columns to rows and omit decorative illustrations, allowing labels to wrap. Regular sizes also allow long biographies and translated interest labels to grow naturally.
- Messages is a warm apricot banner with larger native text, the original 3D chat-bubble artwork and a localized Open messages action. The whole banner opens the existing ConversationsView; it does not display invented unread badges.
- Existing native scroll/navigation containers and source-owned account state remain in place. New artwork is separate from the supplied originals.

Artwork: `Tati/Resources/TatiArtwork.xcassets/profile-table-friends.imageset/art.png`.
Generated with the built-in image tool in Host-Native mode and visually inspected before integration.

## Generation prompt

Use case: stylized-concept. ONE original transparent cutout illustration for Tati's own profile social-connections card. A small glossy hot-pink ceramic serving plate with THREE friendly round golden dumplings gathered closely on it, one tiny chartreuse leaf accent, and a warm cream miniature chef hat perched on the central dumpling. Very small simple smiling faces, subtle and cute, no limbs. Celebrates sharing a meal and friendship. Three-quarter front top view, polished soft resin-toy 3D rendering, soft studio cream highlights, rich warm golden food, pink #FE68B9 and lime #D3FE2E; designed to be legible on deep olive background at 75px. Compact single centered group fills 82% of square canvas with generous transparent margin. Genuine alpha transparency, no background or tile, no ground, no floating hearts, no lettering, no watermark. This is an app-specific original illustration, not an icon library graphic or screenshot.

## Verification

Source, destinations, real relationship-count bindings, artwork metadata, six-language action text and diff whitespace inspected. No compilation, tests, app launch, simulator/device checks or actual screen rendering were performed. Runtime follow-up: large text, long bio/interest, all relationship links, messages navigation and scrolling above the bottom tab bar.
