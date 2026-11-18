# Roro compilation verification — November 17, 2026

## Authorized scope

Compilation, required local H5 bundling and TypeScript checks. No installation, simulator boot, app launch or runtime testing.

## Environment

- Xcode 26.0.1 (17A400), iPhoneSimulator SDK 26.0.
- Node 24.22.0, React Native 0.88.1, CocoaPods 1.16.2.
- Dedicated destination: Roro UI Acceptance, iPhone 17 Pro, iOS 26.0.
- Destination UDID: 911635AB-2201-41C3-A80A-DA902AED9C3A; confirmed Shutdown after compilation.
- Configuration: Debug, x86_64 simulator, local ad-hoc signing.
- Provisional Bundle ID: local.roro.photography. No development team or Apple product catalog configured.

## Commands and results

```sh
npm ci --ignore-scripts --no-audit --no-fund
npm run typecheck
python3 scripts/check_static.py
xcodegen generate --spec ios/project.yml
# From ios:
pod install
# From the project root:
xcodebuild -workspace ios/Roro.xcworkspace -scheme Roro -configuration Debug -destination 'platform=iOS Simulator,id=911635AB-2201-41C3-A80A-DA902AED9C3A' -derivedDataPath .build/DerivedData build
python3 scripts/verify_bundle.py .build/DerivedData/Build/Products/Debug-iphonesimulator/Roro.app
codesign --verify --deep --strict --verbose=2 .build/DerivedData/Build/Products/Debug-iphonesimulator/Roro.app
```

- TypeScript: exit 0.
- Static checks: 91 passed.
- Xcode build: exit 0, BUILD SUCCEEDED. Final local log: /tmp/roro-build-iphone.log.
- Device family: [1]; minimum OS: 16.0. Catalyst, Mac and Vision compatibility disabled in project and target settings.
- H5 archive: 1,582,307 bytes; SHA-256 and 46 current input hashes verified.
- Embedded React Native shell: 3,187,841 bytes.
- Signature: valid on disk; designated requirement satisfied.

## Corrections made during compilation

- Specified the WebView generic props type and declared CSS imports for TypeScript.
- Passed the executable web packaging script directly to React Native's Node environment wrapper.
- Renamed the bundled resource folder to AppResources to resolve code-signing interpretation of the reserved Resources folder; root Assets remains unchanged.
- Applied iPhone-only settings at target level so XcodeGen defaults cannot reintroduce iPad support.
- Added compiled-resource verification and a static check against the iPad target override.

## Limits

This is a simulator Debug compilation, not a distribution archive or device provisioning check. Dependency/Hermes build warnings remain; successful compilation does not establish runtime behavior. No interaction, accessibility, persistence, media import, agreement browsing or StoreKit transaction was tested. StoreKit Test, Apple sandbox and production acceptance remain unperformed. Final Bundle ID, development team, product identifiers and entitlement mapping require owner configuration.
