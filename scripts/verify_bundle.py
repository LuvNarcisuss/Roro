"""Verify a compiled app's identity, signature-independent resources and source freshness."""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('app', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
app = args.app.resolve()
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['UIDeviceFamily'] == [1], 'The app must support iPhone only.'
assert info['CFBundleIdentifier'] == 'com.roro.photography'
assert (app / 'AppResources/products.json').read_bytes() == (root / 'Configuration/products.json').read_bytes(), 'Built wallet catalog must match source.'
archive = app / 'AppResources/RoroWeb.zip'
assert archive.read_bytes() == (root / 'ios/Roro/AppResources/RoroWeb.zip').read_bytes()
assert hashlib.sha256(archive.read_bytes()).hexdigest() == (app / 'AppResources/RoroWeb.sha256').read_text().strip()
with zipfile.ZipFile(archive) as bundle:
    manifest = json.loads(bundle.read('manifest.json'))
    for relative, digest in manifest['inputs'].items():
        assert hashlib.sha256((root / relative).read_bytes()).hexdigest() == digest, relative
    artwork = json.loads((root / 'Assets/artwork-manifest.json').read_text())
    assert bundle.read('assets/artwork-manifest.json') == (root / 'Assets/artwork-manifest.json').read_bytes()
    for item in artwork:
        if item['file'].startswith(('icons/', 'backgrounds/')):
            assert bundle.read('assets/' + item['file']) == (root / 'Assets' / item['file']).read_bytes()
    community = json.loads(bundle.read('assets/community/catalog.json'))
    assert community == json.loads((app / 'AppResources/community.json').read_text())
    assert community == json.loads((root / 'Assets/community/catalog.json').read_text())
    for clip in community['shorts']:
        for key in ['video', 'poster']:
            relative = clip[key]
            assert bundle.read(relative) == (root / 'Assets' / relative.removeprefix('assets/')).read_bytes()
    for author in community['authors']:
        assert author['avatar'] in bundle.namelist()
    assert sum(item.file_size for item in bundle.infolist()) <= 150_000_000
    for relative in ['index.html', 'app.js', 'app.css', 'assets/fonts/Nunito.ttf', 'assets/icons/home.png', 'assets/icons/topics.png', 'assets/icons/shorts.png', 'assets/icons/share.png', 'assets/icons/wallet.png', 'assets/icons/check.png', 'assets/photos/coffee.jpg']:
        assert relative in bundle.namelist(), relative
assert (app / 'main.jsbundle').stat().st_size > 0
assert not (app / 'Resources').exists()
print(json.dumps({
    'bundle': info['CFBundleIdentifier'],
    'deviceFamily': info['UIDeviceFamily'],
    'minimumOS': info['MinimumOSVersion'],
    'webArchiveBytes': archive.stat().st_size,
    'shellBundleBytes': (app / 'main.jsbundle').stat().st_size,
    'sourceManifestVerified': len(manifest['inputs']),
}, indent=2))
