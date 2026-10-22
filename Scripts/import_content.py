"""Generate hosted media mappings; retain original sources outside the app target.

Unassigned or changed inputs stop the import instead of being silently replaced.
This prepares metadata only, not an application build or a media download.
"""
from pathlib import Path
import hashlib
import json
import shutil
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ProjectMaterials/content-slots.json"
RESOURCES = ROOT / "Tati/Resources"
CATALOG = RESOURCES / "KitchenMedia.xcassets"
MOVIES = RESOURCES / "FoodFilms"
ARCHIVE = ROOT / "ProjectMaterials/PackagedMediaArchive"
HOST = "https://pub-d00704a92e07453dbab85506699e0218.r2.dev"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def remote_url(entry, folder):
    return HOST + "/" + folder + "/" + quote(Path(entry["source"]).name)


def main():
    mapping = json.loads(MANIFEST.read_text())
    people = {entry["personID"] for entry in mapping["portraits"]}
    if any(entry.get("authorID") not in people for entry in mapping["videos"]):
        raise ValueError("Every video must reference an assigned profile.")
    assigned = mapping["portraits"] + mapping["videos"]
    expected = {item["source"] for item in assigned}
    actual = {
        str(p.relative_to(ROOT))
        for folder in ["ContentImages", "ContentVideos"]
        for p in (ROOT / "ProjectMaterials" / folder).rglob("*")
        if p.is_file() and not p.name.startswith(".")
    }
    if expected != actual or len(expected) != len(assigned):
        raise ValueError(f"Media mapping mismatch: unassigned={actual - expected}, missing={expected - actual}")
    for entry in assigned:
        if digest(ROOT / entry["source"]) != entry["sha256"]:
            raise ValueError(f"Source changed; review its mapping first: {entry['source']}")

    # Preserve the old app copies for recovery without packaging them in the app.
    for folder in [CATALOG, MOVIES]:
        if folder.exists() and (ARCHIVE / folder.name).exists():
            raise ValueError("Archive already exists; refusing to overwrite: " + str(folder))
    for folder in [CATALOG, MOVIES]:
        if folder.exists():
            ARCHIVE.mkdir(parents=True, exist_ok=True)
            shutil.move(str(folder), str(ARCHIVE / folder.name))
    for entry in mapping["portraits"]:
        entry["remoteURL"] = remote_url(entry, "photo")
    for entry in mapping["videos"]:
        entry["remoteURL"] = remote_url(entry, "videos")
    mapping["status"] = "assigned-hosted-media"
    mapping["delivery"] = {"photoBaseURL": HOST + "/photo/", "movieBaseURL": HOST + "/videos/"}
    clips = []
    room_clips = {}
    for entry in mapping["videos"]:
        # Review holds stay assigned for provenance but must not re-enter app resources.
        if entry.get("excludedFromApp"):
            continue
        clip = {
            "id": entry["id"], "authorID": entry["authorID"],
            "caption": entry["caption"], "createdAt": 0, "isSample": True,
            "bundledFile": entry["resource"], "posterArtwork": entry["posterAsset"],
        }
        if room_id := entry.get("roomID"):
            if room_id in room_clips:
                raise ValueError(f"More than one video assigned to room: {room_id}")
            room_clips[room_id] = clip
        else:
            clips.append(clip)
    write_json(RESOURCES / "table-editorial-content.json", {
        "portraits": {p["personID"]: p["asset"] for p in mapping["portraits"]},
        "additionalPeople": [p["person"] for p in mapping["portraits"] if "person" in p],
        "roomCovers": mapping["roomCovers"],
        "clips": clips,
        "roomClips": room_clips,
        "imageSources": {p["asset"]: p["remoteURL"] for p in mapping["portraits"]},
        "movieSources": {v["resource"]: v["remoteURL"] for v in mapping["videos"] if not v.get("excludedFromApp")},
        "posterSources": {
            v["posterAsset"]: {"movieURL": v["remoteURL"], "seconds": v["posterSeconds"]}
            for v in mapping["videos"] if not v.get("excludedFromApp")
        },
        "curatedRoomActivity": mapping.get("curatedRoomActivity", {}),
        # Keep explicitly authored display interactions across media re-imports.
        "curatedEngagement": {
            entry["id"]: entry["curatedEngagement"]
            for entry in mapping["videos"]
            if not entry.get("excludedFromApp") and not entry.get("roomID") and "curatedEngagement" in entry
        },
    })
    write_json(MANIFEST, mapping)
    print(f"Mapped {len(mapping['portraits'])} hosted portraits, {len(mapping['videos'])} video URLs ({len(clips)} feed / {len(room_clips)} room active); originals retained.")


if __name__ == "__main__":
    main()
