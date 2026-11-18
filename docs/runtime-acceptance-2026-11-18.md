# Roro runtime acceptance

November 18, 2026. Tested source revision `fa63392` on **Roro UI Acceptance**, the designated iPhone 17 Pro simulator with device ID `911635AB-2201-41C3-A80A-DA902AED9C3A`. Simulator lists the device under iOS 26.0. XCTest reports iOS 26.0.1, build 23A8464. Xcode 26.0.1 built Debug and Release from the current workspace.

TypeScript checking passed. The static checks inspected 168 project assertions, 123 controls and 271 community assertions. Both signed simulator builds passed the packaged-resource check with 140 matching inputs, including the nine-product catalog. The compiled app identifies as `com.roro.photography`, targets iPhone and has a minimum OS of 16.0.

## Release behavior

| Area | Runtime evidence |
| --- | --- |
| Welcome and navigation | The agreement checkbox gated first entry. Reopening the app returned to Welcome and required another Log in tap. All five tabs appeared in order and met the 44-point target check. The Terms of Service and Privacy Policy loaded in the native browser. |
| Home and Topics | Verified Discover and Following, collection follow and unfollow, inline search and no-results state, returning to the open query, clearing the query while retaining Following, topic totals, topic video entry, photo detail and the full-photo viewer. |
| Photos and drafts | Imported three system Photos items, removed one and saved a two-photo draft. Verified the saved record and both image files on disk. Reopened the draft after a cold launch, saved the moment, opened its detail and deleted the moment. |
| Community and Chats | Verified the photo and video profile grids, derived work counts, opening a thumbnail, local follow, block filtering, restoring via Settings, and the recipient-specific messaging availability screen. Chats displayed the service-dependent empty state and opened the system share sheet. |
| Reactions and options | Verified both outline-to-filled transitions and pressed states for photos and Shorts, local comment and private-note creation and removal, share-sheet presentation, option labels, hide and restore, and saved-work visibility. |
| Shorts | Verified playback clock advance, pause, resume, seek, mute, vertical swipe, search and return context, profile entry, source browser presentation, and compact saved and personal video covers. The system picker rejected a 61-second video. A five-second video opened in native preview, saved and played inline despite an unrelated prior search, reopened from Me, and deleted successfully. |
| Settings | Verified profile editing across relaunch, attribution, hidden and blocked management, cancelling a library reset, confirming a reset and subsequent clean entry. Reset ran against isolated test data. |
| Wallet | The regular build displayed all nine offers as unavailable, a zero balance and empty history. An isolated StoreKit Test configuration loaded all nine prices. Cancellation and Ask to Buy deferral kept the balance and history unchanged, and the pending queue blocked another checkout. |

The hosted XCTest suite passed six cases. The test bundle was attached to a signed copy of the current Release executable with the same app code and resources. It exercised the actual WKWebView and Swift bridge. One case provided two known image files in place of the picker result to verify native draft writing, caption and topic persistence, reopening, saving to Moments, full-image viewing and deletion. The touch reproduction covered the original picker result and the persisted draft across a cold launch. The first draft touch case stopped at an accessibility label lookup after the actual write. The focused continuation found the same record and passed. The isolated StoreKit fixture was generated from this project's catalog and used only in the test bundle.

Five focused touch cases passed across the runs. They covered profile persistence, wallet availability, reset cancellation and confirmation, Shorts import and deletion, Privacy Policy loading and tab navigation, and reopening, saving and deleting the two-photo draft. Earlier touch attempts also exposed test harness issues with WebKit switch roles, split labels, keyboard coverage and system picker animation. The matching results and scope are retained in the XCTest bundles.

## Findings and remaining coverage

- **Debug welcome overlay.** A React Native warning banner overlapped the lower part of Log in. Tapping the center of the button did not enter the app in that Debug run. The current Release build entered successfully.
- **Browser dismissal touch check.** Both Google Docs loaded. The touch harness did not confirm dismissal using the native browser close button and relaunched for the remaining navigation checks. The hosted test successfully dismissed the presented browser controller.
- **Payment delivery and remote services.** Real Apple sandbox and production transactions, verified credit delivery, duplicate verified receipt delivery and purchase recovery remain open. Messaging coverage applies to the current local availability states. No delivery, remote sign-in or public publishing service is configured.
- **Devices and accessibility.** This run used the designated simulator, its current system settings and XCTest accessibility queries. A physical iPhone, iOS 16, VoiceOver gestures and larger Dynamic Type sizes remain untested.

## Evidence

Local screenshots and machine-readable summaries are under `.build/acceptance/2026-11-18`. Detailed XCTest result bundles are under `/private/tmp/roro-acceptance.AiEtTi`. The original application data was restored and its SHA-256 checksum matched the pre-test value. The verified Release build was installed and relaunched. The two generated test videos remain in the dedicated simulator Photos library for repeat testing. The repository additions are the acceptance report and the status entry.

## Debug startup and agreement follow-up

The Debug baseline reproduced the failed tap at the center of Log in. A temporary diagnostic build captured React Native's Metro status warning for the unavailable localhost packager. Roro now disables packager discovery before initializing React Native in Debug. Both configurations start from the embedded JavaScript bundle. Other LogBox diagnostics retain their default handling.

With Metro absent, the rebuilt Debug app passed the center-tap login and cold relaunch case. Direct clicks in the designated simulator also opened both configured documents from Welcome and from Settings. In all four cases the native browser's close button returned to the originating page. The XCTest runner loaded the documents but failed to verify their dismissal through either accessibility hierarchy. Direct simulator interaction established the return behavior.

The TypeScript check, 169 project checks, 123-control audit and 271 community checks passed. Fresh Debug and Release builds passed signature and resource verification, including the 140 inputs for the web archive.

The Debug follow-up passed one login case and four additional touch cases. The touch cases covered profile persistence, wallet availability, photos and drafts, Shorts import and deletion, and library reset cancellation and confirmation. All six Release hosted cases passed, including the isolated StoreKit Test catalog, cancellation and deferral. The original simulator library was restored and its file hashes matched the pre-test snapshot. The current Debug build was reinstalled and launched on Roro UI Acceptance. Screenshots and summaries are under `.build/acceptance/2026-11-18/entry-fix`.

## Agreement close UI tests

The four cases in `tests/agreements/AgreementCloseTests.swift` open each agreement independently from Welcome and Settings. Each waits for the selected Google document's title, taps the geometric center of Safari's native close control, waits for the browser toolbar to disappear and checks that the original page and agreement link accept touches again. The earlier failed XCTest tap landed at (20.4, 66.4) in a 44-point square starting at (16, 62), outside the visible circular button.

To repeat on Roro UI Acceptance, install the current Debug build on the designated simulator and use a dedicated test library. The Settings cases record local consent if needed. From the repository root, generate the standalone test project and run its suite:

```sh
xcodegen generate --spec tests/agreements/project.yml
xcodebuild test -project tests/agreements/RoroAgreementTests.xcodeproj \
  -scheme RoroAgreementTests -configuration Debug -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,id=911635AB-2201-41C3-A80A-DA902AED9C3A'
```

The dedicated Debug run on Roro UI Acceptance (iPhone 17 Pro, reported iOS 26.0.1, build 23A8464) passed all four tests with zero failures and zero skips. The result bundle is at `.build/acceptance/2026-11-18/agreement-close/AgreementClose.xcresult`. After the run, the original library was restored, its SHA-256 checksums matched, and the verified Debug app was relaunched.
