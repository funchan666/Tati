"""Import the explicitly assigned media; never modify source images or videos.

Run from any directory with Python 3 and ffmpeg installed. This prepares resources,
not an application build. Unassigned inputs stop the import instead of being lost.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ProjectMaterials/content-slots.json"
RESOURCES = ROOT / "Tati/Resources"
CATALOG = RESOURCES / "TatiContent.xcassets"
MOVIES = RESOURCES / "ContentVideos"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def image_set(name, source):
    target = CATALOG / (name + ".imageset")
    target.mkdir(parents=True, exist_ok=True)
    destination = target / ("content" + source.suffix.lower())
    shutil.copyfile(source, destination)
    write_json(target / "Contents.json", {
        "images": [{"filename": destination.name, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    })


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

    CATALOG.mkdir(parents=True, exist_ok=True)
    MOVIES.mkdir(parents=True, exist_ok=True)
    write_json(CATALOG / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    for entry in mapping["portraits"]:
        image_set(entry["asset"], ROOT / entry["source"])
    clips = []
    room_clips = {}
    for entry in mapping["videos"]:
        source = ROOT / entry["source"]
        shutil.copyfile(source, MOVIES / entry["resource"])
        target = CATALOG / (entry["posterAsset"] + ".imageset")
        target.mkdir(parents=True, exist_ok=True)
        poster = target / "poster.jpg"
        subprocess.run([
            "ffmpeg", "-v", "error", "-ss", str(entry["posterSeconds"]),
            "-i", str(source), "-frames:v", "1", "-q:v", "2", "-y", str(poster)
        ], check=True)
        write_json(target / "Contents.json", {
            "images": [{"filename": poster.name, "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        })
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
    write_json(RESOURCES / "content-library.json", {
        "portraits": {p["personID"]: p["asset"] for p in mapping["portraits"]},
        "additionalPeople": [p["person"] for p in mapping["portraits"] if "person" in p],
        "roomCovers": mapping["roomCovers"],
        "clips": clips,
        "roomClips": room_clips,
        # Keep explicitly authored display interactions across media re-imports.
        "curatedEngagement": {
            entry["id"]: entry["curatedEngagement"]
            for entry in mapping["videos"]
            if not entry.get("roomID") and "curatedEngagement" in entry
        },
    })
    total = sum(p.stat().st_size for folder in [CATALOG, MOVIES] for p in folder.rglob("*") if p.is_file())
    print(f"Imported {len(mapping['portraits'])} portraits, {len(clips)} feed videos and {len(room_clips)} room videos, with original-frame posters.")
    print(f"Content resource source size: {total / 2**20:.2f} MiB; not an IPA measurement.")


if __name__ == "__main__":
    main()
