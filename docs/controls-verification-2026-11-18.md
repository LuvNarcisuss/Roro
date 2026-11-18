# Search and controls verification — November 18, 2026

## Behavior implemented

Home and Shorts now use the shared expanding top-toolbar search control beside an independent create action. Opening focuses synchronously inside the tap event, close blurs and clears the query, and submit blurs without clearing results. Home retains its category and query when visiting content. Shorts search belongs to its route, preserving query/category/video through member, own-profile and topic navigation; new video entries do not inherit unrelated filters. Imported videos clear a conflicting search before selection. Pushed Shorts and personal profiles retain a < return action.

App-owned actions now use themed raster glyphs with accessible names. Category/navigation labels, content titles, counts and agreement hyperlinks remain readable. Follow/Message use icon plus text; Block uses the owner's prohibition-emoji exception. Block/unblock persists atomically on this iPhone, removes following when blocked, filters works/comments/collections and has a Settings management route. Existing old records without blocked remain readable; likes/saves/hidden records are preserved. The recipient-specific Message destination honestly states that messaging is unavailable; no remote send, reply or delivery is fabricated.

Twelve icons were generated individually through built-in image_gen and saved under Assets/icons, with full originals, prompts and hashes in Assets/artwork-manifest.json. Each was inspected at original and UI scale. The first delete glyph had faint background residue and was regenerated; its previous original and prompt are preserved. The final delete glyph was also inspected on light and dark surfaces.

## Independent review

A fresh read-only review identified three navigation/state issues and a 42-point avatar target. The final correction adds return controls to pushed Shorts, preserves the parent route when opening the current user's profile, changes collection Follow from plus to check with aria-pressed, and enlarges the avatar target to 44 points. The last item was treated as required because the target minimum is explicit. No runtime reproduction is claimed.

## Executed checks

- npm run typecheck: passed after final source corrections.
- node scripts/check_controls.cjs: 118 JSX controls inspected; no bare text action labels or detached search destinations, and referenced glyphs exist. This is static AST lint, not a rendered UI test.
- python3 scripts/check_community.py: 271 static data/media checks passed.
- python3 scripts/check_static.py: final run passed 157 source/configuration/resource checks.
- xcodebuild -workspace ios/Roro.xcworkspace -scheme Roro -configuration Debug -destination 'platform=iOS Simulator,id=911635AB-2201-41C3-A80A-DA902AED9C3A' -derivedDataPath .build/DerivedData build: exit 0, BUILD SUCCEEDED. Final log: /tmp/roro-controls-final-build.log.
- Build destination: Roro UI Acceptance, iPhone 17 Pro, iOS 26.0. The read-only query found it already Booted; this task did not boot, install, launch or stop it.
- python3 scripts/verify_bundle.py .build/DerivedData/Build/Products/Debug-iphonesimulator/Roro.app: passed twice after final build. All source hashes, native/H5 catalog equality, video/poster bytes and every runtime icon byte match current inputs.
- codesign --verify --deep --strict: exit 0.

## Final artifact

```json
{
  "bundle": "local.roro.photography",
  "deviceFamily": [
    1
  ],
  "minimumOS": "16.0",
  "webArchiveBytes": 18058507,
  "shellBundleBytes": 3188985,
  "sourceManifestVerified": 99
}
```

## Concurrent workspace changes

The first post-build manifest comparison detected scripts/check_static.py changing outside this controls task to require nine consumable tiers, while products.json was briefly empty. The task preserved those changes. Configuration/products.json was subsequently populated outside this task; the final rebuild includes those current inputs and the 157-check static run passes. No wallet identifiers, tiers or payment validation logic were authored by this task, and no Apple catalog/purchase availability is established.

## Remaining acceptance

No app installation, launch, preview or runtime test was performed. Keyboard appearance on iPhone, VoiceOver, dynamic type, rendered layout, search/back interactions, block/relaunch persistence, playback/share/Safari and payment transactions remain unverified at runtime. Existing authorization covers typechecking, packaging and compilation only. Current source and build checks must not be presented as UI or payment acceptance.
