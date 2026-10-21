# Bundled video interactions

The ten supplied feed videos have individually authored display engagement in `ProjectMaterials/content-slots.json`. `Scripts/import_content.py` carries it into `Tati/Resources/content-library.json`. These counts and comments are curated presentation content, not measured server activity. No accounts, friendships, follow-backs, private messages, or network deliveries are created.

- Each video has a distinct base like count and 3–12 topic-specific comments. Comment counts are derived from visible comment records, never an unrelated display number.
- Comment IDs are stable across launches and resource re-imports. Reporting a comment hides it through the existing persisted moderation record. Blocking its author removes their comments from every video and updates counts.
- A viewer's persisted like adds one to that video's base and removing it subtracts only that one. User-authored comments are persisted separately and combined with the bundled records for presentation.
- List cards, full-screen playback, and comment sheets use the same store. Cards move actions below the author if their combined intrinsic width does not fit.
- Imported/user-authored videos have no curated engagement. Their counts start with actual viewer actions. Curated comments do not display fabricated relative posting times.

Only source, JSON/resource references, and diffs were inspected. No builds, tests, simulator/device sessions, or live services were run.
