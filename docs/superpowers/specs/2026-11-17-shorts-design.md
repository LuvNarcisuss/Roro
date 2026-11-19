# Topics and Shorts

The owner explicitly requests Home / Topics / Shorts / Chats / Me in that order. This supersedes the previous three-root navigation. Preserve Roro identity, warm photography theme, StoreKit 1 and local-first architecture.

Topics lists the five existing everyday topics with photo covers and real local content counts. Topic details retain photo creation and link to matching shorts. Shorts is the central navigation destination. The owner corrected the original card-list design by explicitly referencing Vava. Use one full-height inline video at a time, vertical swipe paging, top search/add controls, a right-side action rail, lower-left caption/topic and a seek bar above the navigation dock. Captions, optional topics, likes, saved state, share and deletion remain available. Me includes Shorts and saved videos. The subsequent owner-approved community extension adds fictional local member/engagement records and five licensed Pexels clips. Original source creators are separately credited. Profile totals sum the visible works listed on that profile; topic totals sum the matching visible photos and shorts.

Implementation choice: import one video up to 60 seconds and 200 MB through PHPicker; normalize to MP4 (maximum 80 MB), generate its JPEG poster and persist metadata atomically. The active Shorts feed follows Vava's current local H5 implementation: a single inline WKWebView video plays automatically while active, loops, starts muted and supports pause, sound and seeking. Native services retain import, file validation, local-video export, persistence and sharing. The native modal player remains only for import preview and library previews; the feed pauses while its composer is open. Backgrounding, leaving the tab and opening search/notes pause the feed. This supersedes the initial modal-only feed decision. Only app-owned copies can be removed.

Existing records without shorts or comments fields remain valid. Community comments are separate from existing private notes. IDs, photos, wallet, notes and relationships are preserved. Saved short IDs share the existing like/save arrays. Validate every persisted video record before cleanup and retain corrupt files. Cancelled and failed imports do not create saved shorts. Imported originals stay in native storage; a native allowlisted command exports the selected saved MP4 or resolves an allowlisted bundled community clip into the constrained WebView media directory. It never exposes library or wallet files.

Generate two original transparent raster icons with the existing terracotta/apricot style. Keep originals, runtime images and prompts under Assets.

Compilation, bundling and typechecking remain authorized. No simulator launch, runtime tests or real payment test is authorized. Build for Roro UI Acceptance; document runtime verification still needed for picker cancellation, old libraries, malformed metadata, rotation, background pause, sharing and deletion.

## Reference evidence and icon correction

On the Shorts root tab, the five navigation icons and labels float over playback on a transparent surface. The active underline remains visible, and the gaps between controls pass touches through to playback. Home, Topics, Chats and Me use the paper-textured filmstrip dock.

Read-only comparison: /Users/apple/Desktop/Vava/Vava/ReactNative/Shorts.tsx, Web/native.web.tsx, ReactNative/WebApp.tsx and the historical Shorts acceptance screenshot /tmp/vava-h5-final-images/A37A7106-AE04-419D-8CB6-C060DB565151.png. Follow the current H5 implementation, not the excluded legacy UIKit screen. Vava itself is unchanged. Preserve Roro colors, fonts, navigation labels, local user data and configuration. Remove the special center-tab background and oversized icon; all five navigation buttons use the same sizing. Replace the framed film icon with a transparent standalone play triangle.


## November 18 search and controls

Replace the search panel with top-toolbar expansion. Keep query/open state on each Shorts route and restore it after visiting a profile/topic; submit dismisses the keyboard. A newly imported or independently opened clip must not inherit a conflicting search. Provide < for pushed video routes. Keep action labels accessible while displaying themed glyphs and engagement numbers. Pause while the search keyboard is focused; resume according to the existing pause/lifecycle state after blur. Local blocks filter clips and comments and are enforced by native bundled-playback/share checks.


## Local safety and continuous playback

A downward pull refreshes any clip or the empty feed. The current search and topic remain active. Successful pulls move to a different eligible clip whenever possible and prefer unseen stable IDs for the round. Upward paging wraps from last to first. A single clip loops. Failed refreshes keep the current clip and order.

The owner chose the existing local library as the safety authority. Reporting a community video hides it only on this iPhone. Blocking a member hides that member's content and comments. Settings supports confirmed withdrawal and unblocking by long press or an accessible button. The private action history and active records are written atomically. Reports, blocks, manual hides and saved selections are independent.

Community comments on photos and Shorts can be reported individually. A comment report hides that one comment and updates visible counts. Its parent work and the author's other comments remain available unless another visibility rule applies. Settings lists reported comments by author and text and supports confirmed withdrawal. Both comment and video reports show a dismissible success alert after the local save. Report confirmation and success alerts refer to the current account.
