"""Inspect project artifacts without compiling, bundling or running the app."""
import xml.etree.ElementTree as ET
from decimal import Decimal
from pathlib import Path
import hashlib, json, plistlib, re
root = Path(__file__).resolve().parents[1]
checks = []
def check(condition, message):
    if not condition:
        raise SystemExit('FAILED: ' + message)
    checks.append(message)
for path in root.rglob('*.json'):
    if not any(part in path.parts for part in ['node_modules', '.build', 'Pods', 'build']):
        json.loads(path.read_text())
        checks.append('JSON: ' + str(path.relative_to(root)))
info = plistlib.loads((root/'ios/Roro/Info.plist').read_bytes())
check(info['CFBundleDisplayName'] == 'Roro', 'Display name')
check(info['UISupportedInterfaceOrientations'] == ['UIInterfaceOrientationPortrait'], 'Portrait orientation')
project = (root/'ios/Roro.xcodeproj/project.pbxproj').read_text()
for value in ['TARGETED_DEVICE_FAMILY = 1;', 'SUPPORTS_MACCATALYST = NO;', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;', 'SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;']:
    check(value in project, value)
check('TARGETED_DEVICE_FAMILY = \"1,2\";' not in project, 'No target-level iPad override')
check(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', project) == ['com.roro.photography', 'com.roro.photography'], 'Owner-approved identity in Debug and Release')
check('PRODUCT_BUNDLE_IDENTIFIER: com.roro.photography' in (root/'ios/project.yml').read_text(), 'Generator preserves owner-approved identity')
check('DEVELOPMENT_TEAM =' not in project, 'No borrowed signing team')
check(len(list((root/'ios/Roro.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'))) == 1, 'One shared scheme')
products = json.loads((root/'Configuration/products.json').read_text())
check(len(products) == 9, 'Wallet has nine consumable tiers')
check(len({product['id'] for product in products}) == 9 and
      all(re.fullmatch(r'[a-z]{16}', product['id']) for product in products),
      'Wallet product IDs are unique 16-letter identifiers')
check([product['priceUSD'] for product in products] ==
      ['0.99', '1.99', '4.99', '9.99', '19.99', '29.99', '49.99', '69.99', '99.99'],
      'Wallet tiers are in configured US price order')
check(all(type(product['credits']) is int and 0 < product['credits'] <= 1_000_000
          for product in products), 'Wallet quantities are accepted by the native catalog')
workspace = root / 'ios/Roro.xcworkspace'
scheme = ET.parse(root / 'ios/Roro.xcodeproj/xcshareddata/xcschemes/Roro.xcscheme')
reference = scheme.find('./LaunchAction/StoreKitConfigurationFileReference')
check(reference is not None, 'Debug Run selects a StoreKit configuration')
fixture = (workspace / reference.attrib['identifier']).resolve()
check(fixture == root / 'ios/Configuration/RoroCredits.storekit' and fixture.is_file(),
      'Workspace Run resolves the Roro fixture')
generator = (root / 'ios/project.yml').read_text()
check('schemePathPrefix: "../"' in generator and 'storeKitConfiguration: Configuration/RoroCredits.storekit' in generator,
      'Generator preserves the workspace-relative Run configuration')
offers = json.loads(fixture.read_text())['products']
check([(p['productID'], p['displayPrice'], p['type'], p['localizations'][0]['displayName']) for p in offers] ==
      [(p['id'], p['priceUSD'], 'Consumable', f"{p['credits']:,} Coins") for p in products],
      'Local StoreKit offers match the nine Roro wallet packs')
for index in (5, 7):
    rates = [Decimal(product['credits']) / Decimal(product['priceUSD'])
             for product in products[index - 1:index + 2]]
    check(rates[0] < rates[1] < rates[2], 'New tier credit rate falls between adjacent tiers')
agreements = json.loads((root/'Configuration/agreements.json').read_text())
check(agreements['terms'].endswith('/1fLJgRFc-3igiTcxQRbysHBFuhDZcJhgjlqf15RNmNMU'), 'Exact Terms destination')
check(agreements['privacy'].endswith('/1rkDsi_sAaqhdz2e0nFInLcF12Nmg3L9JebRgwrT68LY'), 'Exact Privacy destination')
for name in ['products', 'agreements']:
    check((root/f'Configuration/{name}.json').read_bytes() == (root/f'ios/Roro/AppResources/{name}.json').read_bytes(), name + ' resource consistency')
for photo in json.loads((root/'Assets/photos/manifest.json').read_text()):
    file = root/'Assets'/photo['file']
    check(file.is_file(), 'Photo exists: ' + photo['id'])
    check(hashlib.sha256(file.read_bytes()).hexdigest() == photo['sha256'], 'Photo hash: ' + photo['id'])
for icon in ['home','chat','profile','search','plus','heart','bookmark','settings','topics','shorts','share']:
    check((root/f'Assets/icons/{icon}.png').is_file(), 'Icon exists: ' + icon)
for relative in ['Assets/fonts/Nunito.ttf','Assets/fonts/OFL.txt','Assets/AppIcon.png','package-lock.json']:
    check((root/relative).is_file(), relative)
for directory in ['web/src','shell','ios/Roro/Native']:
    for file in (root/directory).rglob('*'):
        if file.is_file():
            source=file.read_text()
            check(not re.search(r'[\u3400-\u9fff]',source), 'English source: ' + str(file.relative_to(root)))
            check('supabase' not in source.lower(), 'No Supabase dependency: ' + str(file.relative_to(root)))
check('SKPaymentQueue' in (root/'ios/Roro/Native/PurchaseService.swift').read_text(), 'StoreKit 1 queue')
check('Transaction.updates' not in (root/'ios/Roro/Native/PurchaseService.swift').read_text(), 'No StoreKit 2 transaction API')
check('localStorage' not in (root/'web/src/bridge.ts').read_text(), 'Native persistence authority')
library = (root/'ios/Roro/Native/PhotoLibrary.swift').read_text()
check('try validate(value)' in library, 'Deep validation before caching persisted library')
check('value["cleanupPending"] = true' in library, 'Persisted cleanup recovery marker')
check('try library.finishPendingCleanup(pages: root)' in (root/'ios/Roro/Native/RoroNative.swift').read_text(), 'Startup cleanup recovery')
check('with-environment.sh' in (root/'ios/project.yml').read_text(), 'Build phases use configured Node environment')
check((root/'ios/.xcode.env').is_file(), 'Node environment file is correctly named')
check('FORCE_BUNDLING=1' in project, 'Offline shell bundling is configured')
scene = (root/'ios/Roro/SceneDelegate.swift').read_text()
check(re.search(r'override func bundleURL\(\) -> URL\?\s*{\s*'
                r'Bundle\.main\.url\(forResource: "main", withExtension: "jsbundle"\)\s*}', scene),
      'Startup loads bundled shell')
before_factory = scene.split('reactNativeFactory = RCTReactNativeFactory', 1)[0]
debug_startup_blocks = re.findall(r'#if DEBUG\b(.*?)#endif', before_factory, re.DOTALL)
check(any('RCTBundleURLProviderAllowPackagerServerAccess(false)' in block for block in debug_startup_blocks),
      'Debug disables Metro probing before React Native startup')
app = (root/'web/src/App.tsx').read_text()
nav = app[app.index('<nav className="tabbar"'):]
check(re.findall(r'name: "(home|topics|shorts|chats|me)"', nav)[:5] == ['home', 'topics', 'shorts', 'chats', 'me'], 'Exact five-tab navigation order')
check('value["shorts"] as? [[String: Any]] ?? []' in library, 'Old libraries allow missing shorts')
check('let used = referencedMedia(state)' in library, 'Cleanup preserves video and poster references')
check('shorts.compactMap' in library, 'Saved IDs include short records')
for command in ['pickVideo', 'playVideo', 'videoSource', 'discardVideo', 'saveShort', 'deleteShort']:
    check('"' + command + '"' in (root/'shell/App.tsx').read_text(), 'Video bridge allowlist: ' + command)
check('catalog.find' not in (root/'web/src/Topics.tsx').read_text(), 'Topic covers never restore hidden catalog photos')
feed = (root/'web/src/ShortFeed.tsx').read_text()
shell = (root/'shell/App.tsx').read_text()
check('center-tab' not in app and 'center-tab' not in (root/'web/src/style.css').read_text(), 'No dedicated center-tab box or oversizing')
check('<ShortFeed' in (root/'web/src/Shorts.tsx').read_text(), 'Shorts root opens the immersive feed')
check('<video' in feed and 'playsInline' in feed, 'Inline video feed')
check('onTouchMove' in feed and 'onTouchEnd' in feed, 'Vertical swipe handlers')
check('roro-playback' in feed and 'roroActive' in shell, 'Shell and feed share playback lifecycle')
check('media-src \'self\'' in (root/'web/index.html').read_text(), 'Only local media allowed by CSP')
check('allowsInlineMediaPlayback' in shell, 'Inline WKWebView playback enabled')
for icon in json.loads((root/'Assets/artwork-manifest.json').read_text()):
    check(hashlib.sha256((root/'Assets'/icon['file']).read_bytes()).hexdigest() == icon['sha256'], 'Artwork hash: ' + icon['name'])
print(f'{len(checks)} static checks passed. This command does not compile or run the application.')
