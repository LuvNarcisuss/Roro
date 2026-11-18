"""Validate bundled community records and media without running the application."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "Assets/community/catalog.json").read_text())
manifest = json.loads((root / "Assets/videos/manifest.json").read_text())
authors = {item["id"]: item for item in data["authors"]}
assert len(authors) == len(data["authors"])
works = data["photos"] + data["shorts"]
assert len({work["id"] for work in works}) == len(works)
topics = {"Little joys", "On my walk", "At home", "Today's sky", "Something delicious"}
comment_ids = set()
checks = 0
def local(path):
    assert path.startswith("assets/") and ".." not in Path(path).parts
    result = root / "Assets" / path.removeprefix("assets/")
    assert result.is_file(), path
    return result
for author in authors.values():
    local(author["avatar"])
    assert not {"likes", "saves", "comments", "workCount"}.intersection(author), "Totals must be derived."
    checks += 2
for work in works:
    assert work["authorID"] in authors and work["topic"] in topics
    for key in ("likes", "saves"):
        assert type(work[key]) is int and work[key] > 0
    assert "commentCount" not in work and len(work["comments"]) > 0
    for comment in work["comments"]:
        assert comment["id"] not in comment_ids
        comment_ids.add(comment["id"])
        assert comment["authorID"] in authors and 0 < len(comment["text"]) <= 500
        assert re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", comment["createdAt"])
    for asset in work.get("images", []): local(asset)
    checks += 5 + len(work["comments"]) * 3
assert {item["topic"] for item in data["shorts"]} == topics
assert {item["id"] for item in manifest} == {item["id"] for item in data["shorts"]}
video_hashes = set()
for clip in data["shorts"]:
    record = next(item for item in manifest if item["id"] == clip["id"])
    assert 0 < clip["duration"] <= 60
    assert record["duration"] == clip["duration"]
    assert record["sourceAuthor"] == clip["sourceAuthor"]
    assert record["sourceURL"] == clip["sourceURL"]
    assert record["licenseURL"] == "https://www.pexels.com/license/"
    assert record["sourceURL"].startswith("https://www.pexels.com/video/")
    for asset, key in (("video", "videoSHA256"), ("poster", "posterSHA256")):
        assert clip[asset] == record[asset]
        assert hashlib.sha256(local(clip[asset]).read_bytes()).hexdigest() == record[key]
    assert record["videoSHA256"] not in video_hashes
    video_hashes.add(record["videoSHA256"])
    assert len(record["reviewTimes"]) >= 3
    checks += 11
summary = {}
for author_id, author in authors.items():
    owned = [work for work in works if work["authorID"] == author_id]
    assert owned
    summary[author["name"]] = {"works": len(owned), "likes": sum(w["likes"] for w in owned), "saves": sum(w["saves"] for w in owned), "comments": sum(len(w["comments"]) for w in owned)}
    videos = [work for work in data["shorts"] if work["authorID"] == author_id]
    if videos: assert owned == videos, "Video authors' totals must equal their video works."
    checks += 2
for topic in topics:
    owned = [work for work in works if work["topic"] == topic]
    assert owned
    summary[topic] = {"works": len(owned), "likes": sum(w["likes"] for w in owned), "saves": sum(w["saves"] for w in owned), "comments": sum(len(w["comments"]) for w in owned)}
    checks += 1
shell = (root / "shell/App.tsx").read_text()
for command in ("addComment", "deleteComment", "openSource"):
    assert f'"{command}"' in shell
    checks += 1
assert not re.search(r"[\u3400-\u9fff]", json.dumps(data, ensure_ascii=False))
print(json.dumps({"staticChecks": checks, "authors": len(authors), "shorts": len(data["shorts"]), "photos": len(data["photos"]), "comments": len(comment_ids), "totals": summary}, indent=2))
