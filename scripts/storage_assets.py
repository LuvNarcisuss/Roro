"""Index Roro project assets and stage or verify an immutable Storage release."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
INDEX = ROOT / "Configuration" / "storage-assets.json"


def bucket_for(path, welcome, paid):
    if path in paid:
        return "roro-sources"
    if path.startswith(("icons/", "backgrounds/", "community/")) or path in (welcome, "photos/manifest.json"):
        return "roro-interface"
    if path.startswith(("photos/", "videos/")) and not path.endswith(".json"):
        return "roro-media"
    return "roro-sources"


def inventory():
    catalog = json.loads((ASSETS / "community/catalog.json").read_text())
    welcome = catalog["editorialCovers"]["welcome"].removeprefix("assets/")
    paid = {image.removeprefix("assets/") for work in catalog["photos"] if work.get("coinPrice", 0) > 0
            for image in work["images"]}
    files = {}
    for source in sorted(ASSETS.rglob("*")):
        if source.is_symlink():
            raise ValueError(f"Asset symlink: {source}")
        if source.is_file() and not any(part.startswith(".") for part in source.relative_to(ASSETS).parts):
            path = source.relative_to(ASSETS).as_posix()
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            bucket = bucket_for(path, welcome, paid)
            key = digest + "--" + path.replace("/", "__")
            if bucket == "roro-media":
                key = "releases/" + key
            files[path] = dict(bucket=bucket, key=key, size=source.stat().st_size, sha256=digest)
    fingerprint = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()[:20]
    return dict(release=fingerprint, files=files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-index", action="store_true")
    parser.add_argument("--stage", type=Path)
    parser.add_argument("--verify", type=Path, help="Compare a downloaded release tree with Assets.")
    args = parser.parse_args()
    index = inventory()
    if args.write_index:
        INDEX.write_text(json.dumps(index, indent=2) + "\n")
    elif json.loads(INDEX.read_text()) != index:
        raise SystemExit("Packaged asset index differs from Assets.")
    for path, item in index["files"].items():
        key = Path(item["bucket"]) / item["key"]
        if args.stage:
            target = args.stage / key
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ASSETS / path, target)
        if args.verify:
            file = args.verify / key
            if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != item["sha256"]:
                raise SystemExit(f"Storage mismatch: {key}")
    print(index["release"], len(index["files"]), "files,", sum(f["size"] for f in index["files"].values()), "bytes")


if __name__ == "__main__":
    main()
