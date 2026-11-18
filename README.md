# Roro

An everyday photo journal for iPhone. A warm single-column inspiration feed connects local moments, topics, saved photos and private notes. Five navigation roots are Home, Topics, Shorts, Chats and Me, with Shorts in the center.

## Project

- React Native 0.88.1, React 19.3.0 and TypeScript.
- React product pages are packaged into `ios/Roro/AppResources/RoroWeb.zip` during an authorized build. Native ZIPFoundation extraction initializes a local WebView. Both Debug and Release embed the React Native bundle.
- Swift owns atomic library storage, PHPicker photo/video imports, native video previews, sharing, agreement browsing and StoreKit 1.
- iPhone only, portrait, iOS 16+. The RN 0.88.1 package declares an iOS minimum of 15.1 and Xcode minimum of 16.1. Node must satisfy `^22.13.0 || ^24.3.0 || >=26.0.0`.
- All original artwork, photography, fonts and provenance are in root `Assets/`. The build copies assets into the local page archive. Media references use relative paths and require no credentials.

## Source layout

`web/src` contains all product screens and visual styling. `shell/App.tsx` hosts the local WebView and validates bridge commands. `ios/Roro/Native` contains native services. `Configuration` holds agreements and the owner-supplied product catalog. `ios/project.yml` is the XcodeGen source. `docs/STATUS.md` records verification and remaining dependencies.

## Prepare and build when authorized

1. Run `npm ci` from this directory.
2. Install the Gemfile dependencies, then run `bundle exec pod install` from `ios`.
3. Open `ios/Roro.xcworkspace`, choose the shared Roro scheme, and configure the owner's Bundle ID and development team.
4. Build on an iPhone destination. The build phases generate the local web archive and embed the React Native shell. Metro is not required for offline startup.

Change `ios/.xcode.env` if Node is installed elsewhere. After editing project settings, regenerate using `xcodegen generate --spec ios/project.yml`, then run CocoaPods integration again. `npm run check:static` performs only source/configuration/resource checks. The owner authorized compilation, required H5 bundling and typechecking on November 17, 2026. Use the dedicated `Roro UI Acceptance` iPhone 17 Pro simulator (iOS 26.0; `911635AB-2201-41C3-A80A-DA902AED9C3A`) as the build destination. Installation, app launch and runtime tests require further authorization. After building, `python3 scripts/verify_bundle.py .build/DerivedData/Build/Products/Debug-iphonesimulator/Roro.app` checks the compiled device family and bundled resources against current inputs.

## Local behavior

The current owner-approved scope is device-local. Agreement acceptance opens the personal library without remote authentication. Moments, drafts, likes, saves, followed editorial collections and private notes are saved on this iPhone. Sharing uses the system share sheet. Chats shows its service-dependent empty state. The owner explicitly approved fictional local community profiles, reactions and comments. The immutable community catalog contains six personas and eleven works, including five licensed Pexels videos. No real account registration, online presence or remote message delivery is claimed. Original media creators are credited separately from fictional member identities. Deleting the local library preserves original Photos and purchase records.

## Topics and Shorts

Topics groups the five everyday themes, respecting hidden photos. Shorts imports a single video up to 60 seconds and 200 MB, exports an MP4 up to 80 MB and derives a JPEG cover. The Shorts root uses a full-height inline video feed with vertical swipe paging, tap to pause, double-tap to like, sound controls and seeking. Search, comments, private notes and import pause the feed. Leaving the tab or backgrounding also pauses playback. Native player previews remain available inside import. Captions, topics, likes and saves persist locally; Me includes Shorts and saved videos. System sharing exports the app-owned video copy. Deletion never removes the original Photos asset.

Existing photo libraries do not require a reset: the shorts field is optional for older records. Videos stay in native storage; an allowlisted native command exports the selected saved clip into the constrained local WebView media directory. The feed combines the owner's imported clips with five locally bundled, licensed Pexels videos. Native playback and sharing validate bundled paths against the same community catalog used by H5. No remote upload or online engagement is claimed. Local video runtime acceptance has not been performed.

## Purchases

`Configuration/products.json` is the source for the nine consumable credit packs, ordered by their US setup prices. It contains seven owner-supplied packs and two additional packs at $29.99 for 17,000 credits and $69.99 for 42,500 credits. The `priceUSD` field is a reference for App Store Connect setup. The Settings wallet shows a three-column grid, uses StoreKit's localized price for each available offer and requires a selection before initiating Apple's checkout. Pull down to reload prices. Packs without a StoreKit offer remain visible and disabled. Credit spending awaits the owner's entitlement mapping.

The native implementation uses SKProductsRequest, SKPaymentQueue, SKPaymentTransactionObserver and SKReceiptRefreshRequest. Consumable receipts are checked against Apple's receipt endpoint with production-to-sandbox routing, Bundle ID, product, quantity and transaction matching. Ledger updates are atomic and transaction IDs are retained before finishing. Production and Sandbox ledgers are separate. This client-side receipt path is not server-authoritative fraud protection. No private API key or shared secret is required by this consumable flow. Local StoreKit Test receipts are not accepted by Apple's endpoint; local-payment acceptance needs a separate explicitly isolated verifier when requested.

The owner-confirmed Bundle ID is `com.roro.photography`. Apple registration, the signing team, App Store Connect product status and real-payment acceptance still need confirmation. The shared scheme has no local StoreKit fixture.

## Agreements

Each cold launch shows the welcome page and requires an explicit Log in tap. Returning users see their saved agreement selection. First-time entry requires a successful consent write. Opening an agreement in the native browser preserves the selection on return.

- Terms of Service: https://docs.google.com/document/d/1fLJgRFc-3igiTcxQRbysHBFuhDZcJhgjlqf15RNmNMU
- Privacy Policy: https://docs.google.com/document/d/1rkDsi_sAaqhdz2e0nFInLcF12Nmg3L9JebRgwrT68LY

Public accessibility and legal content have not been verified. The owner-selected hyperlink delivery requires connectivity.


## Community consistency and media provenance

`Assets/community/catalog.json` is the single immutable source for authors, works, baseline reactions and seeded comments. It is bundled both inside the page ZIP and as `AppResources/community.json` for native ID validation. `web/src/community.ts` adds persisted per-device likes/saves and comments, then derives displayed author/topic totals. Video personas own video works only; their profile likes/saves exactly sum those videos. Topic totals include visible matching photos and shorts. Hiding content changes both the matching list and its summary. Private notes retain their original separate storage and semantics.

Five distinct Pexels HD MP4 files and their extracted JPEG posters are under `Assets/videos`. `manifest.json` records original creator, page/download URLs, license URL, hashes, sizes, duration, dimensions, processing and inspected frame timestamps. No API key, credentials or remote media endpoint is required for app playback. Profile avatars reuse locally licensed theme photography, with original image provenance in `Assets/photos/manifest.json`.

Run `python3 scripts/check_community.py` for static record/media consistency checks. This does not execute app selectors or replace runtime acceptance. `scripts/verify_bundle.py` additionally checks native/H5 catalog equality and exact packaged media bytes.


## Search and action controls

Home and Shorts share an expanding top-toolbar search field. Opening focuses within the tap event; closing clears the query and preserves category, and submitting dismisses the keyboard. Search/selection survive child-page navigation. New video routes have independent search state. App actions use themed raster glyphs, with category/content titles and legal links retained; member Follow/Message use icons plus text. The owner's < and prohibition-emoji exceptions apply to Back and Block. Local blocks are reversible from Settings; messaging remains explicitly unavailable.

`node scripts/check_controls.cjs` audits source controls without launching the app. It checks action icon references, text-action regressions and detached search destinations. The generated glyphs and exact prompts are recorded in Assets/artwork-manifest.json. See docs/controls-verification-2026-11-18.md for current checks and their limits.
