# Roro project rules

- Roro is a lightweight everyday photography app. Use exactly Home, Topics, Shorts, Chats and Me, with Shorts in the center.
- Use React Native, TypeScript and a bundled local H5 ZIP. Native Swift modules own storage, photo/video import, video previews and StoreKit 1. The Shorts feed follows the owner-requested Vava-style inline WKWebView player; native code exports validated saved media and allowlisted bundled community clips.
- Support portrait iPhone only, iOS 16+. Disable iPad, Catalyst, Mac compatibility and Vision compatibility.
- All project artifacts and app-owned copy are English. Converse with the owner in Chinese.
- Keep all authored images, fonts and provenance under root Assets. Runtime assets are bundled locally with relative paths.
- Use the exact Google Docs hyperlinks in Configuration/agreements.json. Do not provision Supabase or introduce asset credentials, payment API keys or shared secrets.
- The owner authorized local functionality first. No backend, remote authentication, delivery, public publishing or moderation is configured. Preserve truthful local states.
- The owner confirmed com.roro.photography as the Bundle ID on November 18, 2026. Preserve it in the generator, Debug/Release settings and artifact checks. The signing team remains unconfigured. Use the owner-approved nine-tier consumable catalog in Configuration/products.json. US price points are for App Store Connect setup, while the wallet displays StoreKit's localized prices. Never import another app's configuration.
- StoreKit 1 uses native products and queue callbacks. Credit only a matching verified receipt, persist transaction deduplication and balance together, then finish. No starting credit.
- Preserve private data, stable IDs and atomic persistence. Do not overwrite corrupt state or delete Photos originals.
- On November 17, 2026 the owner authorized compilation, including required H5 bundling and typechecking. App/Simulator launch and runtime tests still require explicit authorization.
- Use the dedicated iPhone 17 Pro simulator named Roro UI Acceptance on iOS 26.0 (UDID 911635AB-2201-41C3-A80A-DA902AED9C3A) for simulator builds and later authorized acceptance. Do not substitute another project's simulator.
- Read docs/superpowers/specs/2026-11-17-roro.md and docs/STATUS.md and docs/superpowers/specs/2026-11-17-shorts-design.md before changes.

- On November 17, 2026 the owner authorized fictional local community records and licensed Pexels video as a fallback to YouTube/Instagram. Keep source creators separate from fictional member identities. Derive profile/topic totals and comment counts from the same work/comment records. Persist local reactions and comments atomically; keep existing private notes separate.

## Search and control contract

Before editing search, page controls or profiles, read docs/superpowers/plans/2026-11-18-controls.md and ios-app-bulid references/social-product-defaults.md plus references/tilo-ui-refinement-case.md. Inspect all affected routes, not just the landing screen.

- Search expands and focuses in the current top toolbar beside the independent create icon. Close clears the query and keyboard without changing category. Submit dismisses the keyboard and keeps results. Child-page return restores the open query/category/video; a new video entry must not inherit an unrelated search filter. Do not reintroduce a separate search page or modal.
- App-owned action controls use individually generated themed raster icons, transparent 44-point minimum targets, accessible English names and visible selected states. Category/navigation labels, content titles and legal hyperlinks remain readable. In photo and video option sheets, show a visible English action label below each icon. Follow and Message on member profiles use labels beside their icons. The welcome page has a visible heading and a filled text-only Log in button gated by a separate agreement checkbox. Back uses an individually generated transparent raster of a left-facing chevron with a sharp 90-degree corner, and Block uses only the owner-approved prohibition emoji. Native system dialogs retain their system controls.
- Like and Save toggles use hollow raster artwork until selected and filled artwork when selected. The glyph and accessibility state read the same persisted selection.
- Block/unblock is atomically persisted local state, removes following on block, filters affected content/comments/collections and has a Settings management route. Keep old records without blocked compatible and preserve hidden/liked/saved records. Messaging has no backend: show the recipient and honest availability, never fabricate sends or replies.
- Before delivery, audit remaining literal button labels, search close/submit/return paths, new-entry filters, asset provenance and current built resources. Compile only within the existing authorization; leave runtime acceptance explicitly open.

Run `node scripts/check_controls.cjs` for the static control audit before delivery. It checks icon references, rejects bare text action labels and detached search destinations, and checks label placement in option sheets and member profiles. This is source lint, not runtime acceptance.

- Member profile works use a two-column thumbnail grid, approximately one quarter of the former full-width cover area. Keep odd final items half-width, retain photo/video detail entry and derive statistics from the unchanged records. Personal Shorts and saved-video collections use the same compact covers; existing smaller photo grids remain compact.
