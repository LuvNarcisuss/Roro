# Implementation and verification status

## Implemented source

- React Native shell, local React/TypeScript screens and native ZIP extraction.
- Welcome consent with exact owner-supplied agreement URLs.
- Five navigation roots in the exact order Home / Topics / Shorts / Chats / Me.
- Home, Discover/Following, search, independent Topics, photo details and full-image viewing.
- Local Shorts: up to 60-second video import, MP4 normalization, generated poster, full-height inline feed, vertical paging, captions/topics, likes, saves, sharing and deletion. Me includes Shorts and saved videos. Older libraries without shorts remain compatible.
- Native selection of up to three photos, optional caption/topic, local moments and drafts.
- Persistent likes, saves, author/collection follows, community comments, separate private notes, hidden photos/shorts and profile editing.
- Five licensed Pexels shorts, six existing licensed photo works, six fictional member profiles and 43 seeded comments. Source authors are separately credited. Shared selectors derive work reactions, author totals, topic totals and comment counts.
- Me collections, settings, local deletion and native share sheet. Personal collections appear in the order Moments, Shorts, Liked, Saved and Drafts. Liked displays visible photos, topic posts and shorts from the local like records. Liked and Saved share a two-column grid of equal 3:4 covers. The lower-right marker identifies shorts and photo posts using the Shorts and Topics artwork respectively. Covers open their photo detail or video player.
- Chats service-dependent empty state, with no fabricated message transport.
- Nine-tier coin wallet with selection, localized prices, native StoreKit 1 checkout, queue recovery, receipt refresh, receipt-matched atomic crediting and transaction deduplication.
- Owner-requested themed raster icons, licensed photography and Nunito in local root Assets.

## Decisions

The owner confirmed Roro as name and directory, React Native, StoreKit 1, no Supabase, local assets, exact Google Docs links and local functionality first. The owner-confirmed Bundle ID is com.roro.photography (November 18, 2026). The coin wallet uses the nine consumables in Configuration/products.json. Coins can unlock an individual Topics work or its category. The later owner request explicitly authorizes fictional community records and licensed Pexels fallback. Community reactions, follows and new comments are device-local; private notes remain separate. The app uses Save moment to describe device-local storage.

## Verification scope

The owner authorized compilation, required H5 bundling and typechecking on November 17, 2026. Dependency installation and CocoaPods integration completed. The latest Debug simulator build succeeded for Roro UI Acceptance (iPhone 17 Pro, iOS 26.0, UDID 911635AB-2201-41C3-A80A-DA902AED9C3A), using Xcode 26.0.1 and Node 24.22.0. The current community extension passed TypeScript checking, 139 project static checks and 271 community static checks. The compiled app's UIDeviceFamily is [1], its minimum OS is 16.0, and its local ad-hoc signature passed strict verification. The packaged H5 archive matches 72 current source/resource inputs and includes the local icons, photography and font. The React Native bundle is embedded.

No app installation, app launch, preview, UI/runtime test or payment transaction was performed by this task. The final read-only simulator query reported Roro UI Acceptance as Booted; this task did not issue a boot command or alter its running state. Current evidence is in community-verification-2026-11-17.md. shorts-feed-verification-2026-11-17.md, shorts-verification-2026-11-17.md and build-verification-2026-11-17.md are historical snapshots before the community extension. Neither establishes installed-app behavior or real purchase availability.

A fresh independent source review identified three issues, corrected in this revision: deep record validation prevents corrupt moment metadata from triggering media cleanup; a persisted cleanup marker keeps committed deletion state synchronized and retries physical cleanup; both Xcode build phases now load the configured Node environment. These fixes now compile successfully but have not been exercised at runtime.

Eleven themed icons were generated individually with built-in image_gen. Original-size images, runtime previews, transparency and file references were inspected. Topics, the replacement standalone Shorts play triangle and the new Share glyph are 128-pixel RGBA assets with transparent backgrounds; prompts and hashes are recorded in Assets/artwork-manifest.json. The settings image was regenerated to remove its background halo. Six licensed photo files were visually inspected. HTTP HEAD requests to both agreement URLs returned 200, while public document content and in-app viewing remain unverified.

An independent static review of the Shorts extension found that empty topic covers could restore hidden catalog photos. The fallback now uses the Topics icon instead; the final typecheck and build include this correction. No runtime acceptance was performed.

### Wallet catalog update on November 18, 2026

The owner supplied seven consumables and delegated the identifiers and credit quantities of two additional tiers. The ordered catalog adds 17,000 credits at $29.99 and 42,500 credits at $69.99, with both unit credit rates between their adjacent tiers. The wallet uses a three-by-three selection grid, keeps unavailable tiers disabled and reads localized prices from StoreKit. Checkout stays disabled while the payment queue contains unresolved transactions. Purchased transactions with missing receipts can refresh the receipt before retrying delivery. The existing ledger format and atomic crediting remain in use.

TypeScript checking, 158 static checks and the Debug build for Roro UI Acceptance passed. The compiled app's product catalog matches the source byte for byte, the H5 manifest verifies 99 inputs and strict ad-hoc signature verification passed. At that revision the shared scheme used no local StoreKit fixture. App launch, wallet UI acceptance and purchase execution in local StoreKit Test, Apple sandbox and production remain open.

## Remaining inputs and acceptance

- Confirm Apple registration for com.roro.photography and the development team.
- Confirm the matching consumable products, US price points and product availability in App Store Connect for Roro.
- Backend selection and credentials only if the owner later requests real social services.
- Public Google Docs access and agreement content confirmation.
- Explicit authorization for installation, launch and runtime acceptance on the dedicated iPhone simulator.
- Apple sandbox and production validation. Local StoreKit Test delivery is covered in the wallet recovery entry below.

Client-side receipt validation uses Apple's receipt endpoint without a private key. Purchase accounting remains device-local.

## Vava-referenced correction

The owner rejected the framed center icon and video-list landing page. The current Shorts root follows Vava's active H5 interaction pattern: one full-height inline video, vertical swipe paging, top search/add controls, right action rail, lower caption/topic and seek control. The feed starts muted, supports pause/sound/seek and private notes, and pauses on tab exit, app background or modal presentation. Native import previews remain separate and never play concurrently with the suspended feed. The allowlisted videoSource command exports a validated personal short or resolves an allowlisted bundled community clip inside the constrained page directory. Other tabs keep their warm Roro layout; no center-tab-only background remains.

A fresh static review found that a newly saved short could remain excluded by the previous topic filter. Selection now clears a conflicting filter after the new record exists. The final compilation includes that correction. Vava was inspected read-only; its files, media, identity and services were not changed or reused. That correction initially added no video material. It is superseded by the owner-approved local community extension below.


## Local community extension

The owner approved Pexels fallback after YouTube/Instagram access and reuse-license confirmation were unsuccessful. Five HD MP4 files were downloaded from public Pexels CDN URLs, their original pages and license inspected, and three representative frames per clip visually checked. The content covers a camera session, a bridge photo walk, coffee steam, a resting cat and a sunset. Files retain original downloaded HD timing, dimensions and silent tracks; posters are extracted at 35% of duration. Provenance and hashes are in Assets/videos/manifest.json. No YouTube/Instagram media is represented as downloaded.

The six personas are fictional. Licensed theme images act as avatars; footage subjects and source creators are not represented as members. Credits explain this distinction and open original source pages in the native browser. Existing photo IDs and personal records remain stable. New comments use a separate optional field, preserving all prior private notes. Old libraries without comments/shorts remain valid. All mutations persist before a new revision is returned.

TypeScript checking, 139 project static checks, 271 community static checks, the final current Debug simulator compilation, packaged catalog/media equality and strict signature verification passed. A fresh independent source review identified lost Shorts navigation context and a hidden/saved count mismatch; both were corrected and included in the final build. The archive is 17,950,332 bytes and matches 72 current source/resource inputs. Runtime UI, playback, persistence and interaction acceptance has not been performed.


## November 18 search and control correction — current verification

The current toolbar search, icon actions, profile controls and local block management are documented in docs/controls-verification-2026-11-18.md. This supersedes the November 17 community artifact as the latest verification record. Home and Shorts share inline search; return navigation preserves search/category/video context, including pushed Shorts and the current user's profile. Follow/Message use icons plus text, Back uses <, and Block uses the owner's prohibition glyph. New comments and existing private data retain their storage semantics.

Twelve themed action icons were generated separately and inspected at original/UI sizes; the delete glyph was regenerated after a background-residue finding. Project rules and the new static control audit record the owner's persistent interaction requirements. Final results: TypeScript passed; 118 JSX controls audited; 271 community static checks and 157 project static checks passed. The designated Debug simulator build succeeded, strict signature verification passed, and the 18,058,507-byte web archive matches 99 current source/resource inputs including the current concurrently updated wallet catalog. Wallet configuration changes were outside this controls task; no purchase availability is claimed.

No application installation, launch, preview, runtime interaction or payment verification was performed. Independent review findings about pushed-video return, own-profile return, visible collection-follow state and avatar target size were corrected before the final build. The dedicated simulator was already Booted and was not booted or altered by this task.

## November 18 film artwork refresh

The app now uses 23 individually generated transparent interface glyphs. The five navigation images share a 38 CSS pixel canvas, a visible selected underline and the existing English labels. Home, Topics, Chats and Me use four local film-paper backgrounds. Related secondary pages reuse these backgrounds, and Shorts retains its full-height video surface with a dark dock. Both the dock and video controls use the same safe-area clearance calculation. Assets/artwork-manifest.json records the prompts, original files and hashes.

The minimum calculated contrast of the primary, muted and accent text colors over the four composited backgrounds ranged from 4.83:1 to 5.27:1. TypeScript checking, the 120-control audit, 162 project static checks and 271 community static checks passed. The Debug build for Roro UI Acceptance succeeded. The signed app passed strict signature verification. Its local web archive matched 130 source inputs, including all interface glyphs and four background images. On-device rendering and interaction await runtime acceptance.


## November 18 Bundle ID update

The owner changed the Bundle ID to `com.roro.photography`. The XcodeGen source, generated Debug and Release configurations, static identity assertions and compiled-artifact verifier now use this value. Current rules and product documentation match. Historical verification reports retain the identifiers observed in their original artifacts.

This change passed 163 project static checks, the 120-control source audit and plist/project syntax validation. No compilation, installation or launch was performed for this identity-only change. Earlier build results do not verify the new Bundle ID; existing build artifacts must be rebuilt before delivery. Apple registration, signing and payment availability remain unverified.

## November 18 back control

The main toolbar and the pushed Shorts toolbar share a sharp 90-degree left chevron and a 44-point button labeled Back. The designated Debug simulator build and bundle verification passed with com.roro.photography. TypeScript, the 120-control source audit and 163 project static checks passed. The app was not launched.

The owner requested original artwork for the chevron. Both toolbars now display the same individually generated transparent copper-and-plum back icon at 34 CSS pixels within a 44-point target. The original and export hashes are recorded in Assets/artwork-manifest.json. Light and dark artwork samples were inspected. TypeScript, the 122-control source audit, 164 static checks, the designated Debug simulator build and the compiled bundle check passed. In-app visual and interaction checks remain pending.

## Welcome entry

The welcome page groups a visible Welcome to Roro title, an initially unchecked agreement control and a full-width Log in text button above the bottom safe area. The cover yields space to the controls on short screens. Both legal links use the same configured destinations as Settings. The button records consent through the existing local entry flow. TypeScript, the 122-control audit, 164 project static checks, the designated Debug build and compiled resource verification passed. In-app layout and interaction remain pending.

## Photo and video options

The photo and Shorts option menus show a visible English caption below each action icon. The photo menu distinguishes hiding a community photo from deleting a personal moment. Captions share the button hit area and wrap within responsive grid columns. TypeScript, the 122-control audit, 164 project static checks, the designated Debug simulator build and the compiled bundle check passed. On-device layout remains pending.

## Like and save artwork

Photo cards, photo detail, Shorts playback and video lists use one reaction button that derives its icon and accessibility pressed state from the same saved selection. Unselected hearts and bookmarks have transparent centers. Selected hearts are filled red and selected bookmarks are filled gold. Both outline assets have individual originals and provenance in the artwork manifest. Static verification covered all eight reaction bindings and all four packaged icons. TypeScript, control and community audits, 166 project checks, the designated Debug simulator build and compiled bundle verification passed. Runtime interaction and relaunch checks remain pending.

The bookmark pair was subsequently redrawn with a broader ribbon. At a 32 CSS pixel display size the visible width is approximately 19 pixels in both states. The outline has a transparent opening and the saved variant has a solid gold center. The new assets passed source and compiled-bundle checks on the designated Debug build. Runtime visual acceptance remains pending.

## Explicit entry on cold launch

A fresh app launch now requires a Log in tap even when the library already contains recorded agreement consent. Returning users reuse that consent without rewriting its timestamp. First-time entry still waits for a successful native write, and clearing the library resets entry. TypeScript, the static gate inspection, the control and project audits, the designated Debug build and compiled bundle verification passed. Cold relaunch has not been exercised on the simulator.


## Compact profile works

The owner requested profile covers at approximately one quarter of their former area. Member profiles now display photos and videos in two equal columns with a 10-pixel gap. Cover aspect ratios remain 4:4.6 for photos and 3:4 for videos, making each dimension approximately half the previous full-width cover. Odd final entries keep their half-width slot. Thumbnail buttons open the original photo detail or selected Shorts route and retain accessible names. Repeated author rows and action bars are omitted from profile thumbnails; the detail views retain those interactions. Statistics still derive from the unchanged work records.

Personal Shorts and saved-video collections reuse the compact grid. Existing smaller three-column personal photo grids stay unchanged. No data, reaction, block or payment logic changed.

Verification: TypeScript passed; 123 JSX controls audited; 168 project static checks and 271 community checks passed. The Debug build for Roro UI Acceptance (iPhone 17 Pro, iOS 26.0, 911635AB-2201-41C3-A80A-DA902AED9C3A) succeeded. The compiled artifact verifier confirmed com.roro.photography, iPhone-only support and 140 matching source/resource inputs. No installation, launch or runtime visual/interaction verification was performed.

## November 18 runtime acceptance

The owner authorized the full runtime regression on November 18, 2026. Debug and Release were freshly built for Roro UI Acceptance. Six hosted XCTest cases and five focused touch cases passed across the recorded runs. Simulator coverage includes first entry, all five tabs, local photos and Shorts, search, local community and settings flows, and the isolated StoreKit catalog, cancellation and deferral. The [runtime acceptance report](runtime-acceptance-2026-11-18.md) records the Debug welcome overlay, native browser dismissal coverage and the Apple payment scenarios still open.

### Debug startup and browser dismissal follow-up

Debug now skips Metro discovery when starting the embedded bundle. On Roro UI Acceptance, a center tap on Log in worked without Metro, including after cold relaunch. Both agreements returned to Welcome and Settings when their native close control was clicked directly in the simulator. Four additional Debug touch cases and six Release hosted cases passed. The original library matched its pre-test hashes after restoration, and the latest Debug build was left running. See the [follow-up details](runtime-acceptance-2026-11-18.md#debug-startup-and-agreement-follow-up).

The subsequent [agreement close UI test run](runtime-acceptance-2026-11-18.md#agreement-close-ui-tests) passed all four independent Welcome and Settings round trips on the designated simulator. XCTest confirmed dismissal and return for both documents.

## Independent Home and Topics photography

Home retains its original collection. Topics uses five Pexels photographs and three separately sourced portraits for fictional contributors. Each photograph and portrait is credited in the local photo manifest. Topic cards and details count the same visible topic photos and linked shorts. Related shorts open by caption without repeating Home artwork. New personal moments retain the surface where they were composed, including after draft editing. Older personal moments default to Home. The community check compares media hashes across both surfaces.

## Shared page header and background

All five roots use the Roro camera logo and a centered page title. The existing trailing actions remain on their original pages. Inline search expands inside the same header. Non-playback pages use the Home dawn paper, including Welcome and the video composer. Shorts playback keeps its transparent video overlay. TypeScript, control and project audits and the designated Debug build passed. The compiled archive contains the logo and the stylesheet references one paper artwork. The new layout awaits runtime visual acceptance.

## Roro camera wordmark

The launcher, launch storyboard, React Native loading view, welcome page and page headers share the new Roro wordmark with a deep teal camera and sunset landscape lens. The launcher uses an opaque 1024-pixel RGB export. In-app views use its 128-pixel derivative. The original artwork, prompt and digests are recorded in the artwork manifest. Visual inspection covered 36- and 60-pixel samples. TypeScript, static checks, the designated Debug simulator build and packaged resource verification passed. The app was not launched for this change.

## In-app logo placement

The logo appears during launch and loading, at the upper left of the welcome/login page, and at the upper left of Home, Topics, Shorts, Chats and Me when opened as root tabs. Pushed routes, including Shorts and Me opened through another page, use the back control. Child pages and the composer omit the logo. TypeScript, the root-route source inspection, the control and project audits, the designated Debug build and compiled resource verification passed. Runtime visual acceptance was not performed for this change.

## Settings account actions

Log out returns to the local welcome screen and discards the current navigation history. A subsequent Log in opens Home with the existing library and wallet. Delete local account is a separate action that requests confirmation before clearing the local library.

## November 18 wallet catalog repair

The regular Run scheme previously had no local StoreKit configuration. The separate acceptance session loaded nine products using its own fixture. The Roro workspace now selects Configuration/RoroCredits.storekit during Debug Run. Its nine product IDs, US prices, consumable types and localized names match the wallet catalog and the previously exercised isolated fixture. The shared scheme resolves the file relative to Roro.xcworkspace and is reproducible from ios/project.yml.

The designated Debug build, signature, 151 bundled source inputs, TypeScript check, 129-control audit and 192 static checks passed. The StoreKit configuration is external to the app bundle. The owner subsequently authorized a selection-only check. Xcode built and ran the workspace on Roro UI Acceptance. A UI test tapped all nine packs and verified each displayed USD price and the matching checkout selection. One test passed with zero failures. No order was placed. Screenshot: .build/acceptance/2026-11-18/wallet-selection/wallet-nine-prices.png. Apple catalog availability and local receipt delivery remain unverified. The current verifier uses Apple's endpoint and cannot credit an Xcode fixture purchase.

## Wallet coin artwork

All nine wallet packs display a gold coin with a camera aperture above the credit amount. The localized price and selection indicator retain their existing positions. TypeScript, the control and static audits, the designated iPhone simulator build and bundle verification passed. The packaged icon matches the source PNG. Runtime visual acceptance was not performed for this change.

The wallet now labels its currency Coin or Coins across the balance, packs, checkout, and purchase history. The balance displays the same aperture coin beside the amount. All nine local StoreKit product names and descriptions use the new terminology.

## Local StoreKit 1 wallet recovery

The Debug simulator Run scheme uses the Xcode StoreKit catalog. Its receipts now pass through an isolated verifier that checks Xcode's pinned test certificate, the signed payload, the bundle and the queued purchase fields. Verified local orders share the atomic delivery and deduplication logic with Apple orders and use a separate ledger. The queue finishes the transaction after the ledger write succeeds.

On Roro UI Acceptance (iPhone 17 Pro, iOS 26.0), the updated app recovered the existing unfinished 400-coin transaction (ID 0). The wallet showed 400 coins and one history entry. A second purchase of the same $0.99 pack from the wallet produced transaction ID 1. After dismissing the Xcode success alert, the final UI check passed: 800 coins, two history entries and checkout enabled. A separate ledger inspection found exactly 400 coins on each ID and no Apple ledger file. The initial UI harness needed adjustments for WebKit's split history labels and the native success dialog. No third purchase was made. Evidence is under .build/acceptance/2026-11-18/wallet-recovery. This run covered the local Xcode environment only.

## Feed pull-to-refresh

Home, Topics and Chats refresh when a downward pull starts at the top of the page and is released past the threshold. The original Shorts implementation refreshed only on the first clip or in the empty feed. The local safety and feed update below supersedes that gesture behavior. Refresh rereads the validated on-device library through the native snapshot command and preserves the active search and topic filters. On successful refresh, Discover cycles the first recommended photo and photography prompt, Topics features the next topic, and Shorts presents the next matching clip first. Following retains its relationship-based order. Chats retains its content and displays the current local messaging availability and the last successful status check time.

The four feed refresh indicators show a rotating ring during the pull and the refresh. After release, the ring remains visible for at least 550 milliseconds while new data is applied immediately. The reduced-motion setting uses a stationary ring with the same status text.

Photo cards group Like, Comments and Save from left to right, with each count directly below its icon.

## Full interaction regression

The [November 18 full regression](full-regression-2026-11-18.md) recorded 22 distinct XCTest cases passing on their final runs on Roro UI Acceptance. At the time of that regression the app lacked report submission, voice and video call entry, microphone and camera permission requests, and live self-preview. Local blocking, file-based video preview and Xcode StoreKit checkout were exercised. The original library and purchase ledger were restored.

## On-device video reports, member blocks and refresh

The owner selected device-local storage for this change. Reporting a community video hides that video. Blocking a member from a profile or comment hides that member's work and comments and removes the follow relationship. Settings identifies each active record and offers a confirmed undo by long press or accessible button. The library commits the action and its private history together before updating the interface. Withdrawing a report and unblocking a member clear only their respective restrictions. Report dialogs describe the action for the current account. Settings explains that reports stay on this iPhone. The local library has no remote moderation queue or cross-account service.

Shorts supports a downward pull on any clip and in the empty state. Successful pulls preserve the filter and select unseen eligible clips until the round is exhausted. Upward paging wraps from the final eligible clip to the first. A failed library read preserves the current clip and order. Scrollable app pages use pull-to-refresh, including price retrieval in the wallet.

On Roro UI Acceptance (iPhone 17 Pro, iOS 26.0.1), the two touch tests and five hosted XCTest cases passed. The touch tests exercised physical swipes and a long press in Settings. The hosted cases exercised both undo orders, local write failure and retry, delayed refresh, saved and search visibility, single and empty results, and wallet price recovery using the nine local StoreKit products. The unfiltered feed showed all five distinct IDs before a repeat. Two laps after a report and an author block included only the three eligible IDs. Result bundles and clip-ID attachments are under `.build/acceptance/safety-refresh`.

The final touch run terminated and relaunched Roro with an active report. The clip was still excluded, and the record could be withdrawn by long press and confirmation. Debug and Release simulator builds passed resource-manifest verification for all 155 inputs. After testing, the original library and wallet were restored and their file hashes matched the pre-run values. The normal Debug app was reinstalled and launched.

## Comment reports and success alerts

Photo and Shorts comment threads offer Report on each community comment. Reporting a comment updates that thread and its visible comment count. Settings lists the author and comment text under Reported comments, with the same confirmed withdrawal controls as Reported videos. Existing video reports remain compatible. Both kinds of report display a native success alert after the local library has saved the change and the page has updated. Cancelling the confirmation or failing to save skips the success alert.

On November 19, three touch XCTest cases passed on Roro UI Acceptance (iPhone 17 Pro, iOS 26.0.1). They opened and dismissed the success alert for a photo comment, a Shorts comment and a video. The final screenshots show the photo comment count changing from three to two, the Shorts comment count from four to three, and the video feed advancing before the alert appears. The tests also checked cancellation, withdrawal in Settings and persistence across relaunch. Six isolated report-flow checks covered cancellation, failed saves and successful saves for both target types. Results and screenshots are under `.build/acceptance/comment-reports`. The original library and wallet were restored with matching hashes.

## Topic post and comment safety menus

A community topic post has a three-dot button in the upper-right corner of its detail page. Its untitled menu can report that post or block its publisher. The topic card also offers these actions alongside its existing share and hide controls. On a topic post, each community comment has a three-dot button in the former report position. Its menu targets the comment or its author. Personal comments retain their delete control. Topic categories have no publisher and remain available after a post report.

Reported posts are tracked by their catalog IDs, separately from blocked members, manual hides, video reports and comment reports. The library persists the report and its history before the app hides the post and displays the local success alert. Settings lists the post by caption under Reported posts and supports confirmed withdrawal.

Two end-to-end XCTest cases passed on Roro UI Acceptance (iPhone 17 Pro, iOS 26.0.1). They exercised the header and comment menus, both report success alerts, member blocking from each menu, Settings reversal and restarting with a reported post. The original simulator library and wallet were restored with matching hashes. Screenshots and the final result bundle are under `.build/acceptance/topic-safety`.

### Community photo detail correction

The upper-right post menu and the per-comment three-dot menus on “A little moment” now apply to community photo details reached from Home as well as Topics. The native library accepts reports for any bundled community photo ID. A post report hides that post, a comment report hides that comment, and Block acts on the member named in the menu.

Three targeted UI tests passed on Roro UI Acceptance (iPhone 17 Pro, iOS 26.0.1) on Ava Reed’s “Coffee tastes better together.” They verified the post and Milo Brooks comment menus, the two independent block targets, both report alerts and Settings reversal. Screenshots of the closed page and both open menus are in `.build/acceptance/home-safety`.

## Topic creation and paid access

The Topics toolbar combines category and access filters with inline search. The add button to the right of Search opens the local topic composer. Authors choose free access or a whole-coin price below the category pass and retain access to their own work. Readers confirm either a single-work purchase or a category pass covering current and future paid works. Each spend and its permanent entitlement are written atomically to the active device wallet. Single-work purchases do not discount a later category purchase. Authored topics and unlocks are device-local. Creator payouts and cross-device entitlements require a backend.

The Topics filter dialog presents category and access as two inline radio groups. Apply commits both choices together. Closing discards pending choices, and reopening starts from the applied filters.

## Photography journal visual update

The shared interface uses illustrated raster controls, a dark teal filmstrip tab bar, warm paper, photographic prints, and locally bundled Courgette and Kalam lettering. Shorts retains its full-screen video surface. Artwork sources and hashes are recorded in `Assets/artwork-manifest.json`.

On November 19, one five-tab UI test passed on Roro UI Acceptance (iPhone 17 Pro, iOS 26.0.1). The final visual review checked the filmstrip contrast, active tab indicators and centered titles across Home, Topics, Shorts, Chats and Me. Screenshots are under `.build/acceptance/2026-11-19/journal`. The Debug app bundle passed verification against all 200 source manifest inputs.

## Chats inbox and local conversations

Recent conversations show the latest user-entered text and time. Friends and Archived have distinct lists and empty states. Find friends shows incoming and pending requests. Directory results appear only after a search. Profile and inbox entry points open the same conversation. Blocking removes a contact and excludes their history from the lists. Clearing the local library clears contacts and messages. The app creates no automatic replies or delivery indicators. The add-friend artwork is an original instant-photo portrait and plus sign.


Friend approval and mutual following independently enable messages and call previews. The native library enforces the same rule as the composer. Blocking removes both relationships. Existing messages stay in place, and previous one-sided contacts become pending requests. The fictional catalog supplies a follower (Milo) and an incoming request (June). Only the recipient can accept an incoming request. New outgoing requests stay pending locally.

Voice calls show the member portrait and a local microphone level. Video calls use a mirrored full-screen front camera preview. Both screens have three bottom controls: speaker, end call and microphone. Speakerphone and microphone are initially requested on. Off preferences use slashed artwork. The audio session switches between speakerphone and the default output route, and muting stops microphone capture independently of the camera. A video without a camera feed keeps a neutral dark surface. Both screens stay open until hang-up, release hardware in the background and resume on return. The app records no media and has no remote call transport.

A left swipe on a conversation reveals text buttons for pinning, marking it read or unread, and deletion. More actions opens the same controls for keyboard and assistive access. The most recently pinned conversation comes first. Pinned rows display a journal pushpin in the upper-right corner. Remaining rows keep their activity order in Recent and Archived, or name order in Friends. Unread rows show a message glyph with a red 1 badge below the timestamp. Opening a thread clears its local unread marker. Confirming deletion removes that member's message history and inbox flags on this iPhone while preserving the friendship. New messages start a fresh conversation.

## Independent community photography

Nine bundled members have individual avatars. The eleven photo works, five short posters, five category covers and two editorial covers each have their own source image. A returning member or work keeps the same image across routes. Credits and source links for the thirteen new Pexels photographs are recorded in Assets/photos/manifest.json. The community audit checks file digests and source URLs across these assignments.

Edit profile supports a single photo from the iOS photo picker. The editor previews the selection. Saving commits the app-owned portrait reference with the name and biography, and Me, personal posts and comments read it from the same profile. Existing profiles without a photo keep their fallback artwork or initial.

Photo, topic and short comments render circular profile portraits. Personal comments resolve the current local profile on display, including its initial when no photo has been chosen.

Shorts comments open in a 41% viewport-height sheet with a scrolling comment list. Both the sheet and photo or topic detail pages overlay a bottom composer using the chat input and send-button dimensions. The per-comment More button opens a modal report and block menu above the composer.

Comments support device-local replies. Reply appears before More in the comment action row. Replies retain a stable parent ID, use the current author portrait, and start on separate rows at one shared indentation level. Deleting a local comment keeps its replies.

A confirmed block publishes the saved library and returns to the originating tab root, including from member profiles and comment menus. Shorts opens a fresh player with eligible clips. Home, Topics and Chats rebuild their lists from the same snapshot. The refreshed root shows a dismissible “User blocked.” alert once for the committed block. Cancellation, failed writes and unblocking keep the current route.

## Journal launch artwork

Build 2 uses JournalLaunchScreen and the transparent JournalLaunchLogo asset for the native launch screen. The launch image source matches the Roro mark used by the embedded React Native shell and web pages. The compiled storyboard reference and shell artwork are checked by the bundle verifier.

Build 3 bundles the original transparent camera PNG as a standalone resource for the system launch storyboard. On Roro UI Acceptance (iPhone 17 Pro), the recorded cold launch after an in-place upgrade showed the green camera on the native launch screen, the same artwork in the shell loader, and the welcome page. The transition to the shell briefly showed a plain background. All three pre-upgrade library, media and purchase file hashes matched afterward. The recording and native launch frame are in `.build/acceptance/journal-cold-launch/`.

## Photo detail author and actions

The photo detail page shows a circular portrait beside the author's name. Both share the same profile button. Like, Save and Share use a common icon row with separate counts below Like and Save. The artwork sizes account for the transparent margins in each original PNG. TypeScript, control and project audits, the simulator build and its resource manifest passed. Tap-through and on-device visual acceptance were not run for this change.

The topic category card groups the Add a photo and Explore shorts icons in one left-aligned row with an eight-point gap. Categories without visible shorts show only Add a photo.

Photo details end with the comment list and floating composer. The local-storage hint, private notebook entry and inline photography credit have been removed from this page. Existing notes stay in the library and source records remain in Artwork & credits.

The Wallet entry moved from Settings to a centered card on Me between the compact personal statistics and collection tabs. The entire card opens the existing wallet and displays its local coin balance.

## European and US street portraits

Four Home photos, three Topics photos and three twelve-second Shorts show people in Paris, London, Padova and New York. Each source page and photography location is recorded in the corresponding media manifest. All ten works are free to view, with per-work reactions and individual comment records.

Home discovery and followed works, the Topics directory, and the works inside each category use two-column grids. Photo cards retain member profiles and independent reaction, comment and safety controls. The photo comment control opens the discussion directly. Topic summaries derive the number of photographers from the visible works. Seven new social photographs invite conversations about group portraiture, shared meals, dance and surfing. Two additional photographs are dedicated category covers. Credits and locations are recorded in the photo manifest.

Four credited fashion portrait Shorts feature swimwear in sea light, embroidered runway detail, a red studio dress and a summer portrait in Paris. Each local video has its own poster and two photography discussion comments.
