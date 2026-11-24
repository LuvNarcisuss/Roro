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
project_file = root / 'ios/Roro.xcodeproj'
scheme = ET.parse(root / 'ios/Roro.xcodeproj/xcshareddata/xcschemes/Roro.xcscheme')
reference = scheme.find('./LaunchAction/StoreKitConfigurationFileReference')
check(reference is not None, 'Debug Run selects a StoreKit configuration')
fixture = (project_file / 'project.xcworkspace' / reference.attrib['identifier']).resolve()
check(fixture == root / 'ios/Configuration/RoroCredits.storekit' and fixture.is_file(),
      'Project Run resolves the Roro fixture')
generator = (root / 'ios/project.yml').read_text()
check('schemePathPrefix: "../../"' in generator and 'storeKitConfiguration: Configuration/RoroCredits.storekit' in generator,
      'Generator preserves the project-relative Run configuration')
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
for photo in json.loads((root/'Assets/photos/manifest.json').read_text()):
    file = root/'Assets'/photo['file']
    check(file.is_file(), 'Photo exists: ' + photo['id'])
    check(hashlib.sha256(file.read_bytes()).hexdigest() == photo['sha256'], 'Photo hash: ' + photo['id'])
for icon in ['home','chat','profile','search','plus','heart','bookmark','settings','topics','shorts','share']:
    check((root/f'Assets/icons/{icon}.png').is_file(), 'Icon exists: ' + icon)
for relative in ['Assets/fonts/Nunito.ttf','Assets/fonts/OFL.txt','Assets/AppIcon.png','Assets/fonts/Courgette-Regular.ttf','Assets/fonts/Kalam-Regular.ttf']:
    check((root/relative).is_file(), relative)
for directory in ['ios/Roro/UI','ios/Roro/Native']:
    for file in (root/directory).rglob('*'):
        if file.is_file():
            source=file.read_text()
            check(not re.search(r'[\u3400-\u9fff]',source), 'English source: ' + str(file.relative_to(root)))
            check('sb_secret_' not in source and 'service_role' not in source, 'No privileged Supabase credential: ' + str(file.relative_to(root)))
auth = json.loads((root / 'Configuration/authentication.json').read_text())
check(auth['projectURL'] == 'https://awpvqvtvqjkdddoidntx.supabase.co'
      and set(auth) == {'projectURL', 'publishableKey'}
      and auth['publishableKey'].startswith('sb_publishable_'), 'Roro public authentication configuration')
check('SKPaymentQueue' in (root/'ios/Roro/Native/PurchaseService.swift').read_text(), 'StoreKit 1 queue')
check('Transaction.updates' not in (root/'ios/Roro/Native/PurchaseService.swift').read_text(), 'No StoreKit 2 transaction API')
store = (root/'ios/Roro/Native/JournalStore.swift').read_text()
library = (root/'ios/Roro/Native/PhotoLibrary.swift').read_text()
scene = (root/'ios/Roro/SceneDelegate.swift').read_text()
native = root / 'ios/Roro'
check('UIHostingController(rootView: JournalRoot()' in scene, 'SwiftUI scene entry')
check('case home = "Home", topics = "Topics", shorts = "Shorts", chats = "Chats", me = "Me"' in store, 'Five ordered destinations')
for file in native.rglob('*.swift'):
    check(file.name + ' in Sources' in project, 'Target compiles ' + file.name)
for folder in ['icons', 'backgrounds', 'community', 'photos', 'videos', 'fonts', 'Configuration']:
    check(folder + ' in Resources' in project, 'Native resource folder ' + folder)
check('try validate(value)' in library and 'try library.finishPendingCleanup()' in store, 'Validate before media cleanup')
check('appendingPathComponent("Roro", isDirectory: true)' in library and 'appendingPathComponent("Media", isDirectory: true)' in library, 'Private library locations')
check('value["shorts"] as? [[String: Any]] ?? []' in library, 'Legacy libraries support absent video records')
check('let used = referencedMedia(state)' in library, 'Cleanup respects saved media')
check('case "videoSource"' in store and 'try CommunityCatalog.video(id)' in store, 'Allowlisted local playback')
for obsolete in ['PBXShellScriptBuildPhase', 'react-native', 'USE_HERMES', 'Pods-Roro', 'RoroWeb.zip']:
    check(obsolete not in project, 'Native project excludes ' + obsolete)
for file in native.rglob('*'):
    check(file.suffix.lower() not in {'.js','.html','.tsx','.zip','.jsbundle'}, 'Native app inputs: ' + file.name)
for icon in json.loads((root/'Assets/artwork-manifest.json').read_text()):
    check(hashlib.sha256((root/'Assets'/icon['file']).read_bytes()).hexdigest() == icon['sha256'], 'Artwork hash: ' + icon['name'])
print(f'{len(checks)} static checks passed. This command does not compile or run the application.')
