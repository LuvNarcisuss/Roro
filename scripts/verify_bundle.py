"""Verify the native iPhone bundle and compare its immutable media with source."""
from pathlib import Path
import argparse
import filecmp
import plistlib
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("app", type=Path)
app = parser.parse_args().app.resolve()
root = Path(__file__).resolve().parents[1]
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["UIDeviceFamily"] == [1] and info["CFBundleIdentifier"] == "com.roro.photography"
assert info["UISupportedInterfaceOrientations"] == ["UIInterfaceOrientationPortrait"]
assert info["MinimumOSVersion"] == "16.0"
assert info["UILaunchStoryboardName"] == "JournalLaunchScreen"
assert any(b"roro-logo.png" in path.read_bytes() for path in (app / "JournalLaunchScreen.storyboardc").glob("*.nib"))
# Xcode may re-encode the standalone launch PNG. Reproduce its copy phase and
# compare the result. The main icons folder is still checked byte for byte.
logo = root / "Assets/icons/roro-logo.png"
built_logo = app / "roro-logo.png"
if not filecmp.cmp(logo, built_logo, shallow=False):
    with tempfile.TemporaryDirectory() as temporary:
        converted = Path(temporary) / "launch.png"
        subprocess.run(["xcrun", "copypng", "-strip-PNG-text", logo, converted], check=True)
        assert filecmp.cmp(converted, built_logo, shallow=False), "Launch logo differs from its source"
assert filecmp.cmp(root / "Assets/artwork-manifest.json", app / "artwork-manifest.json", shallow=False)
for font in info["UIAppFonts"]:
    assert (app / font).is_file(), font
folders = [root / "Configuration"] + [root / "Assets" / name for name in
    ("backgrounds", "icons", "community", "photos", "videos", "fonts")]
count = 0
for folder in folders:
    for path in folder.rglob("*"):
        if path.is_file() and not path.name.startswith("."):
            destination = app / folder.name / path.relative_to(folder)
            assert filecmp.cmp(path, destination, shallow=False), str(destination)
            count += 1
for path in app.rglob("*"):
    assert path.suffix.lower() not in {".html", ".js", ".jsbundle", ".zip", ".tsx"}, path
    assert not any(name in path.name.lower() for name in ("hermes", "react-native", "rctbridge")), path
print(f"Native iPhone bundle verified. {count} resource files match their sources.")
