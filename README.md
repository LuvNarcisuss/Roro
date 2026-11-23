# Roro

Roro is a portrait iPhone photography journal for iOS 16 and later. The five tabs are Home, Topics, Shorts, Chats and Me. All product screens are native SwiftUI. UIKit presents system photo and video pickers, sharing, local call previews and agreement links. AVFoundation plays the Shorts feed.

## Open and build

Open `ios/Roro.xcodeproj` and select the shared Roro scheme. The project resolves Apple SwiftASN1 1.5.1 with Swift Package Manager for Debug simulator StoreKit receipt validation. The app builds with Xcode directly. `ios/project.yml` is the XcodeGen configuration for regenerating the project.

The bundle identifier is `com.roro.photography`. A development team is required for signed device installation. The shared scheme selects `ios/Configuration/RoroCredits.storekit` for local StoreKit testing. The simulator acceptance destination is recorded in AGENTS.md.

## Source and data

- `ios/Roro/UI` contains navigation, artwork controls, discovery, topics, playback, social and account screens.
- `ios/Roro/Native` owns local actions, media import and playback, community records, private persistence and StoreKit 1.
- The app reads `Assets/community/catalog.json` and uses the same stable IDs for fictional community members and works. Photos and videos have separate source credits. Runtime artwork, fonts, photography and video are copied directly from the corresponding Assets folders at build time.
- Existing installations continue using Application Support/Roro, including the original library, imported Media directory and purchase ledgers. Login requires local consent. Messages, reports, blocks and call previews operate on the device.
- `Configuration/agreements.json` holds the legal URLs. `Configuration/products.json` is the source for the nine consumable products. The wallet displays StoreKit prices and credits verified transactions once. Apple catalog and real-payment verification require the owner's App Store Connect configuration.

## Verification

Run `python3 scripts/check_static.py`, `python3 scripts/check_community.py` and `node scripts/check_controls.cjs` for source and resource audits. Run `python3 scripts/verify_bundle.py /path/to/Roro.app` to compare the built resources with the repository. See `docs/STATUS.md` for the verification scope. Earlier dated records describe the build available at the time.
