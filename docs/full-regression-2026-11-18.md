# Roro full functional regression

On November 18, 2026, the current workspace at `cea0958` was built in Debug and Release with Xcode 26.0.1. All simulator runs targeted **Roro UI Acceptance**, iPhone 17 Pro, device `911635AB-2201-41C3-A80A-DA902AED9C3A`. XCTest reported iOS 26.0.1 (23A8464).

**22 distinct XCTest cases passed on their final runs, with zero final failures and zero skips.** The cases include a route inventory that identified the missing features below.

## Missing user-facing capabilities

| Requested behavior | Observation |
| --- | --- |
| Voice call and microphone permission | Chats exposes sharing and navigation. The member's Message page exposes Back and the recipient profile. Neither offers a voice call. There was no app-triggered microphone prompt. |
| Video call, camera permission and live self-preview | The same two routes have no video call or camera preview. Neither built app declares camera or microphone usage descriptions. The app has no capture or permission request path for either device. A call service is unnecessary to exercise local capture once implemented. |
| Report a work, comment or member | Photo options offer sharing, hiding and cancellation. Short options offer private notes, source and hiding. The member profile offers Follow, Message and Block. Comments offer author navigation and deletion of the user's own entries. There is no reporting action or submission flow. |

## Exercised behavior

| Area | Checks and outcomes |
| --- | --- |
| Welcome and legal | Checked first-entry consent, center-tap login and cold relaunch. Four independent UI tests opened the expected document, tapped Safari's native close button and found the original Welcome or Settings controls interactive again. |
| Social reactions | Real touches selected and cleared Like and Save on photos and Shorts. Photo selections survived cold launch. In Release, both actions incremented each counter once and cancellation restored the starting count and outline artwork. Selected saved items appeared in Me. |
| Comments and notes | Typed, posted and deleted a local comment on both a photo and a short through the iOS keyboard and visible controls. The short returned to its original comment count. Empty comment submission was disabled. Added and removed private notes separately. Opening comments paused video playback. |
| Blocking and following | Followed a member, opened their conversation, cancelled a block and then confirmed it. Blocking hid the member's works and disabled following. Unblocking from Settings restored the member's works in search. Also followed and unfollowed the editorial collection. |
| Discovery and topics | Exercised Discover, Following, empty results, inline search, submit, close and return with the query retained. Opened all five topics, verified the selected topic carried into composition and checked the discard and keep-editing paths. Tested topic video entry, member thumbnail grids and navigation back to the correct result. |
| Photos and drafts | Cancelled and reopened the system picker, selected three photos, removed one, saved a two-photo draft, reopened it after a cold launch, saved it to Moments, opened detail and deleted it. Separate hosted tests checked both stored files, the topic and the full-size viewer, then exercised cancelling and confirming draft deletion and verified its absence after relaunch. |
| Shorts | Checked advancing playback time, pause, resume, seek, mute, comments, notes, native sharing, original source, hide and restore. The system picker rejected a 61-second video and accepted a five-second clip. Opened its AVPlayer preview, saved it, played it inline, reopened it from Me and deleted it. This preview reads an existing media file. |
| Pull to refresh and logout | Swiped down on Home and Topics and verified the recommendation changed. Pulling down on the first Short advanced the recommendation. Subsequent swipes moved to the next and previous clips. Chats refresh displayed a status check time. Log out returned to Welcome, and signing back in opened Home. |
| Me and Settings | Tested profile editing across relaunch, Moments, Shorts, Saved, Drafts, hidden and blocked management, attribution and the five original video source browser links. Cancelled and confirmed local account deletion using an isolated library and checked the fresh state after relaunch. |
| Wallet | Checked the regular wallet and disabled unavailable offers. In a separate Xcode StoreKit session, selected each of the nine offers and checked its price and checkout selection. Cancellation left the wallet empty. An 800-coin Ask to Buy transaction remained pending without a credit and blocked repeat checkout. Approval credited 800 coins, populated history and re-enabled checkout. |

## Test conditions and evidence

Debug UI tests used XCTest touch synthesis on the installed app. Release hosted tests exercised DOM controls in the actual WKWebView and used the Swift bridge. One hosted draft test supplied two known picker results. The independent UI test used the real system photo picker. Native share sheets were presented and dismissed without sending anything externally. The wallet used Xcode StoreKit Test. Apple sandbox and production payments, physical-device capture and live calls were outside this run.

TypeScript checking passed. The source checks covered 129 JSX controls, 197 project assertions and 323 community assertions. Both compiled app bundles matched all 154 inputs in their packaged web manifest.


Earlier attempts used outdated selectors for the system video picker, composite WebKit labels and the keyboard toolbar, or an expected topic total that included a Home-only photo. The focused reruns selected the five-second video by its system duration label, verified content changes by their actual titles, dismissed the keyboard before posting, and checked the topic-specific records. Each previously failing case passed on rerun. The original simulator library and Xcode purchase ledger were restored with matching SHA-256 hashes. The verified Debug build was relaunched.

The per-run counts, individual case results, initial failures, screenshots and original XCTest bundles are in `.build/acceptance/2026-11-18/full-regression/`. The machine-readable index is `results.json`.
