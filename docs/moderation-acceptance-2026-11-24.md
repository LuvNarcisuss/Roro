# Roro moderation acceptance, November 24, 2026

## Environment and scope

Roro QA ran on an iPhone 17 Pro simulator with iOS 26.3, device ID `32F50BDE-596D-4540-9A8C-C3621294D0D2`. The native Debug app used the project's Supabase sign-in endpoint. UI tests used one owner-provided account and a separate simulator data container. The test copy used the built app executable with a distinct bundle identifier. The original app and its journal stayed available under `com.roro.photography`.

The baseline exposed five storage failures. Author reports were unavailable, an unknown kind could fall through to a video report, and the writer accepted oversized details, unrelated block context and new reports on a blocked author's video. A Shorts UI run also observed a report acknowledgement disappear before the user could press OK.

## Behavior under test

- Photo, topic, short and comment options distinguish reporting the content, reporting its actual publisher or commenter, and blocking that member. A member report records the member independently from a content report or block. Settings identifies each target and supports confirmed withdrawal.
- The local writer checks the target type, current visibility, parent work and actual author before adding a safety record. Optional reason and details fields are limited to 80 and 500 characters. A retained audit event includes available work and comment IDs.
- Blocked conversations are excluded from the user-facing snapshot. The underlying entries are retained. New interactions with an inaccessible target fail. Downloads completing after a visibility change cannot start playback or open sharing for the hidden work.
- A committed block clears the detail stack for the originating tab. A repeated block keeps the current route and suppresses a second acknowledgement. The success alert has its own lifetime so removing the original menu or work cannot dismiss it.

## Native runtime checks

The simulator ran **37 storage checks and 23 store and navigation checks**. All 60 passed. The storage probe compiled the app's `PhotoLibrary.swift` and used the project catalog with fresh journal directories. The store probe used the app's store implementation with a fixture-only account initializer and a controllable media loader. No authentication override was included in the shipped app.

| Area | Observed result |
| --- | --- |
| Independent undo | Unblock first and withdraw first both preserved the remaining reason. Interaction and the original favorite returned after the last reason was removed. |
| Comments and authors | Reporting a comment left its parent usable. Reporting the commenter preserved the actual commenter, parent, comment, reason and details without blocking that person. |
| Direct requests | Self-blocks, unknown targets and kinds, incorrect ownership or context, excessive input and new reports against hidden targets were rejected. Hidden parents returned no direct comments. |
| Chat access | A blocked conversation disappeared from the visible snapshot. Its history remained on disk, the blocked peer could not receive a new entry, and an unrelated conversation remained writable. |
| Recovery and history | A forced file-write failure preserved the current detail, in-memory state and lack of success. Retry committed once. A second process reopened the report and block. Withdrawal retained the ordered audit events outside the visible snapshot. |
| Navigation and delayed media | Shorts, Topics and Chats returned to the filtered tab root on a committed block. Duplicate block and unblock kept the current route. Media and share requests deliberately resumed after a report rejected their stale results. |
| Local account isolation | Two test libraries had independent state, and distinct user IDs resolved to distinct journal directories. |

## Interface and refresh checks

Tests signed in through the welcome screen. The installed app under its original bundle ID showed all three Shorts safety actions. Cancelling each kept the current video and produced no success message. The same run opened the Home photo card menu and verified its post report, actual-author report and block actions.

The first two-lap refresh test exposed a swipe starting over the caption that left the first video in place. The vertical recognizer now covers the player and its overlays. Repeating the unchanged gesture test passed. It verified a complete refresh round over the 12 eligible clips and two consecutive upward laps in the same order.

Across four XCTest result bundles, **14 distinct UI cases passed on their latest runs**. The first 13-case batch had nine passes and four failures. Subsequent runs used the original installed app for one additional smoke case, reran paging and the combined visibility case, and reran the three remaining cases. Two topic-comment tests needed to scroll the detail page before asking XCTest for a lazily rendered row. One video-withdrawal test was interrupted after repeated XCTest animation timeouts and passed on a fresh launch.

| UI surface | Observed result |
| --- | --- |
| Home and Topics | Post and comment menus opened for the intended item. A comment-only report kept the parent. The topic commenter report identified Kit Lane while the post belonged to Nora Vale. |
| Shorts | Reporting the video or a comment showed a success alert that remained available for dismissal. Reporting its publisher left the video available. Blocking from the menu or profile returned to the filtered feed. |
| Chats | A conversation with an actual test message disappeared after blocking the peer from its profile. The app returned to Chats and the retained conversation reappeared after unblock. |
| Settings, search and saved works | Long-press withdrawal and the accessible button path both worked. A saved video stayed out of search and the collection while either its report or its author's block was active. The saved detail reopened after both were undone. |

The Debug build passed the bundle comparison against 129 resources. The project source checks passed 314 assertions, the community data checks passed 737, and the native controls audit covered 15 SwiftUI files.

## Service boundaries

The production login was exercised with one real account. A second authenticated account, a private-profile UI fixture and a physical-device VoiceOver session were not exercised. Roro's approved design stores moderation in the account's journal on the device. Cross-device moderation sync, server moderation authorization, an operator inbox and staff alert delivery are outside this implementation.
