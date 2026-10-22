"""Generate hosted media mappings without local content image/video files.

Invalid or duplicate hosted records stop the import instead of being silently replaced.
This prepares metadata only, not an application build or a media download.
"""
from pathlib import Path
import json
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ProjectMaterials/content-slots.json"
RESOURCES = ROOT / "Tati/Resources"
HOST = "https://pub-d00704a92e07453dbab85506699e0218.r2.dev"


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def remote_url(entry, folder):
    name = entry["originalFilename"]
    if not name or Path(name).name != name or "\\" in name:
        raise ValueError("Expected a filename, not a local path: " + name)
    return HOST + "/" + folder + "/" + quote(name)


def main():
    mapping = json.loads(MANIFEST.read_text())
    people = {entry["personID"] for entry in mapping["portraits"]}
    if any(entry.get("authorID") not in people for entry in mapping["videos"]):
        raise ValueError("Every video must reference an assigned profile.")
    assigned = mapping["portraits"] + mapping["videos"]
    if len({item["originalFilename"] for item in assigned}) != len(assigned):
        raise ValueError("Duplicate hosted source filename")
    for entry in mapping["portraits"]:
        if entry["remoteURL"] != remote_url(entry, "photo"):
            raise ValueError("Photo URL does not match its original filename")
    for entry in mapping["videos"]:
        if entry["remoteURL"] != remote_url(entry, "videos"):
            raise ValueError("Movie URL does not match its original filename")
    mapping["status"] = "hosted-media-only"
    mapping["delivery"] = {"photoBaseURL": HOST + "/photo/", "movieBaseURL": HOST + "/videos/", "localSourceFilesRemoved": True}
    clips = []
    room_clips = {}
    for entry in mapping["videos"]:
        # Only current explicit exclusions are skipped; historical review notes do not hide content.
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
    print(f"Mapped {len(mapping['portraits'])} hosted portraits, {len(mapping['videos'])} video URLs ({len(clips)} feed / {len(room_clips)} room active); no local media required.")


if __name__ == "__main__":
    main()
