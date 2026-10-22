"""Inspect hosted-content mappings; --check-links performs HTTPS HEAD requests only.

No media is downloaded, and no app builds, tests or simulator runs are performed.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import quote
from datetime import datetime
from zoneinfo import ZoneInfo
import argparse
import re
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HOST = "https://pub-d00704a92e07453dbab85506699e0218.r2.dev"


def inspect():
    manifest = json.loads((ROOT / "ProjectMaterials/content-slots.json").read_text())
    library = json.loads((ROOT / "Tati/Resources/table-editorial-content.json").read_text())
    all_entries = manifest["portraits"] + manifest["videos"]
    for entry in all_entries:
        name = entry["originalFilename"]
        assert name and Path(name).name == name and "\\" not in name
        assert re.fullmatch(r"[0-9a-f]{64}", entry["originalSHA256"])
        assert entry["originalByteCount"] > 0
        folder = "photo" if entry in manifest["portraits"] else "videos"
        assert entry["remoteURL"] == HOST + "/" + folder + "/" + quote(name)
    active = [v for v in manifest["videos"] if not v.get("excludedFromApp")]
    assert library["imageSources"] == {p["asset"]: p["remoteURL"] for p in manifest["portraits"]}
    assert library["movieSources"] == {v["resource"]: v["remoteURL"] for v in active}
    assert library["posterSources"] == {
        v["posterAsset"]: {"movieURL": v["remoteURL"], "seconds": v["posterSeconds"]} for v in active
    }
    assert set(library["portraits"].values()) <= set(library["imageSources"])
    assert set(library["roomCovers"].values()) <= set(library["posterSources"]) | set(library["imageSources"])
    films = library["clips"] + list(library["roomClips"].values())
    assert {v["id"] for v in films} == {v["id"] for v in active}
    for film in films:
        assert film["bundledFile"] in library["movieSources"]
        assert film["posterArtwork"] in library["posterSources"]
    for directory in ["KitchenMedia.xcassets", "FoodFilms"]:
        assert not (ROOT / "Tati/Resources" / directory).exists()
        assert directory not in (ROOT / "Tati.xcodeproj/project.pbxproj").read_text()
    assert manifest["delivery"]["localSourceFilesRemoved"]
    for directory in ["ContentImages", "ContentVideos", "PackagedMediaArchive", "ContentReviewHold"]:
        assert not (ROOT / "ProjectMaterials" / directory).exists()
    return manifest, all_entries


def head(entry):
    result = subprocess.run([
        "/usr/bin/curl", "--head", "--silent", "--show-error", "--max-time", "15",
        "--retry", "1", "--retry-all-errors", "--retry-delay", "1",
        "--write-out", "\n%{http_code}", entry["remoteURL"]
    ], capture_output=True, text=True, timeout=40)
    headers, _, code = result.stdout.rpartition("\n")
    fields = {}
    for line in headers.splitlines():
        if ":" in line:
            name, value = line.split(":", 1)
            fields[name.lower()] = value.strip()
    row = {"originalFilename": entry["originalFilename"], "url": entry["remoteURL"], "status": int(code or 0),
           "contentType": fields.get("content-type"), "contentLength": fields.get("content-length"),
           "acceptRanges": fields.get("accept-ranges")}
    if result.returncode:
        row["error"] = result.stderr.strip()
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-links", action="store_true")
    args = parser.parse_args()
    manifest, entries = inspect()
    print(f"Hosted records and URL mappings checked: {len(manifest['portraits'])} photos / {len(manifest['videos'])} movies; no local files required.")
    if args.check_links:
        with ThreadPoolExecutor(max_workers=6) as pool:
            rows = list(pool.map(head, entries))
        report = {"checkedAt": datetime.now(ZoneInfo("Asia/Shanghai")).isoformat(), "method": "HTTPS HEAD with system curl; TLS verification enabled; no media bodies downloaded",
                  "resources": rows, "buildTestsOrAppRunPerformed": False}
        (ROOT / "Documentation/Remote-media-availability.json").write_text(json.dumps(report, indent=2) + "\n")
        failures = [r for r in rows if r["status"] != 200 or "error" in r]
        print(f"HTTP 200: {len(rows) - len(failures)}/{len(rows)}. Failures: {len(failures)}.")
        for row in failures:
            print(row["status"], row["originalFilename"], row.get("error", ""))
        if failures:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
