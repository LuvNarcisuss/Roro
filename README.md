# Roro

Roro is a portrait iPhone photography journal for iOS 16 and later. The five tabs are Home, Topics, Shorts, Chats and Me. All product screens are native SwiftUI. UIKit presents system photo and video pickers, sharing, local call previews and agreement links. AVFoundation plays the Shorts feed.

## Open and build

Open `ios/Roro.xcodeproj` and select the shared Roro scheme. The project resolves Apple SwiftASN1 1.5.1 with Swift Package Manager for Debug simulator StoreKit receipt validation. The app builds with Xcode directly. `ios/project.yml` is the XcodeGen configuration for regenerating the project.

The bundle identifier is `com.roro.photography`. A development team is required for signed device installation. For local QA prices and checkout, start Roro with Product > Run from the project. The Run action resolves its StoreKit file relative to the internal `Roro.xcodeproj/project.xcworkspace`. Launching an installed simulator app directly does not activate this file. The shared scheme selects `ios/Configuration/RoroCredits.storekit` for local StoreKit testing. The simulator acceptance destination is recorded in AGENTS.md.

For App Store Connect uploads, select `Roro iOS App Store` in Codemagic. The workflow uses Xcode 26.5, the team integration named `Roro` and App Store signing files for `com.roro.photography`. It queries Apple app ID `6838600659` for the build number and uploads the signed IPA. Review submission is manual. The separate `Roro signing validation` workflow builds the IPA without uploading it.

## Source and data

- `ios/Roro/UI` contains navigation, artwork controls, discovery, topics, playback, social and account screens.
- `ios/Roro/Native` owns local actions, media import and playback, community records, private persistence and StoreKit 1.
- The app reads `Assets/community/catalog.json` and uses the same stable IDs for fictional community members and works. Photos and videos have separate source credits. The asset resolver maps stable paths to content-addressed Supabase objects using `Configuration/storage-assets.json`. The launch logo, app icon and system-registered fonts remain in the bundle. Device-owned media stays in its existing private directory.
- Roro requires an email/password account and agreement acceptance. Add confirmed accounts under Authentication > Users in the Roro Supabase project (Thingtill Org, Singapore). The app bundles only the project URL and publishable key in `Configuration/authentication.json`. Supabase Auth owns `auth.users.email` and the bcrypt hash in `auth.users.encrypted_password`. The client keeps its renewable session in memory and asks for credentials on a cold launch.
- Each authenticated user has a separate device library, media directory and wallet. Accounts with a previously linked journal continue to use it. Messages, reports, blocks and call previews operate on the device.
- `Configuration/agreements.json` holds the legal URLs. `Configuration/products.json` is the source for the nine consumable products. The wallet displays StoreKit prices and credits verified transactions once. Apple catalog and real-payment verification require the owner's App Store Connect configuration.

## Verification

Run `python3 scripts/check_static.py`, `python3 scripts/check_community.py` and `node scripts/check_controls.cjs` for source and resource audits. Run `python3 scripts/verify_bundle.py /path/to/Roro.app` to compare the built resources with the repository. See `docs/STATUS.md` for the verification scope. Earlier dated records describe the build available at the time.

## Publish project assets

Run `python3 scripts/storage_assets.py --write-index --stage <empty-directory>` to stage every file under Assets by bucket and object key. Upload the contents of each bucket directory to the same bucket in the company Roro project. Preserve the `releases/` prefix inside `roro-media`. The interface bucket supports the pre-login UI. Signed-in members can read released editorial media. The private source bucket holds the design originals, licenses and the two paid full-resolution photos. Their previews are available to members. Full-resolution paid images continue using the device wallet's existing access checks and bundled copies.

Download the release with an authorized Storage account and run `python3 scripts/storage_assets.py --verify <download-directory>` to compare every object against the source SHA-256. After remote verification, set `publishedRelease` in `Configuration/storage-release.json` to the index's release identifier and rebuild. An empty configuration keeps the packaged assets active. App clients have no Storage write policy.
