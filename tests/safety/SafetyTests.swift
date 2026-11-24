import XCTest

final class SafetyTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.roro.photography")
    private struct Fixtures: Decodable {
        struct Work: Decodable {
            let id: String
            let caption: String
        }
        let shorts: [Work]
    }

    private var captions: [String: String] = [:]
    private let coffeeCaption = "Coffee tastes better together."

    override func setUpWithError() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: SafetyTests.self).url(forResource: "catalog", withExtension: "json"))
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        captions = Dictionary(uniqueKeysWithValues: fixtures.shorts.map { ($0.id, $0.caption) })
        XCTAssertGreaterThan(captions.count, 1)
        launchShorts()
    }

    private func launchShorts() {
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let login = app.buttons["Log in"]
        XCTAssertTrue(login.waitForExistence(timeout: 16))
        guard let email = ProcessInfo.processInfo.environment["RORO_QA_EMAIL"],
              let password = ProcessInfo.processInfo.environment["RORO_QA_PASSWORD"] else {
            XCTFail("Configure the QA email and password in the test runner.")
            return
        }
        app.buttons["I agree to the"].tap()
        let address = app.textFields["Email address"]
        address.tap()
        address.typeText(email + "\n")
        app.secureTextFields["Password"].typeText(password + "\n")
        XCTAssertTrue(app.buttons["Discover"].waitForExistence(timeout: 10))
        app.buttons["Shorts"].firstMatch.tap()
    }

    private func clip() throws -> String {
        let caption = app.staticTexts.matching(NSPredicate(format: "label IN %@", Array(captions.values))).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 8))
        let visible = caption.label
        return try XCTUnwrap(captions.first { $0.value == visible }?.key, visible)
    }

    private func swipe(up: Bool) {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.29))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.72))
        (up ? bottom : top).press(forDuration: 0.08, thenDragTo: up ? top : bottom)
    }

    private func confirm(_ action: String) {
        let button = app.alerts.buttons[action]
        XCTAssertTrue(button.waitForExistence(timeout: 6))
        button.tap()
    }

    private func advance(from id: String, up: Bool) throws -> String {
        let caption = try XCTUnwrap(captions[id])
        swipe(up: up)
        XCTAssertTrue(app.staticTexts[caption].waitForNonExistence(timeout: 8), "The feed stayed on " + id)
        return try clip()
    }

    func testRefreshRoundAndTwoSwipeLaps() throws {
        let initial = try clip()
        let later = try advance(from: initial, up: true)
        var pulls = [initial, later]
        var current = later
        for _ in 2..<captions.count {
            current = try advance(from: current, up: false)
            pulls.append(current)
        }
        XCTAssertEqual(Set(pulls), Set(captions.keys))
        current = try advance(from: current, up: false)
        var lap = [current]
        for _ in 0..<(2 * captions.count) {
            current = try advance(from: current, up: true)
            lap.append(current)
        }
        XCTAssertEqual(Set(lap.prefix(captions.count)), Set(captions.keys))
        XCTAssertEqual(Array(lap.prefix(captions.count)), Array(lap.dropFirst(captions.count).prefix(captions.count)))
        XCTAssertEqual(lap.first, lap.last)
        let evidence = XCTAttachment(string: "Refresh round: \(pulls)\nTwo laps: \(lap)")
        evidence.name = "Visible clip IDs"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    private let successMessage = "Report saved for this account."

    private func dismissSavedReport(_ name: String) {
        let message = app.alerts.staticTexts[successMessage]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = name
        evidence.lifetime = .keepAlways
        add(evidence)
        confirm("OK")
        XCTAssertTrue(message.waitForNonExistence(timeout: 4))
    }

    private func checkCommentReport(author: String, text: String, photo: Bool) {
        let menu = "More options for comment by " + author
        let report = app.buttons["Report comment"].firstMatch
        openSafetyMenu(menu, report: "Report comment", author: author)
        XCTAssertTrue(report.waitForExistence(timeout: 8))
        report.tap()
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 6))
        cancel.tap()
        let closeSheet = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(closeSheet.waitForExistence(timeout: 5))
        closeSheet.tap()
        XCTAssertTrue(app.staticTexts[text].firstMatch.exists)
        XCTAssertFalse(app.alerts.staticTexts[successMessage].exists)
        moreControl(menu).tap()
        report.tap()
        confirm("Report")
        dismissSavedReport(photo ? "Photo comment report saved" : "Short comment report saved")
        XCTAssertFalse(app.staticTexts[text].firstMatch.exists)
    }

    private func withdrawCommentReport(author: String, text: String) {
        openSettingsList("Reported comments")
        let undo = app.buttons["Withdraw report for " + author + " — " + text]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.press(forDuration: 0.9)
        confirm("Withdraw")
        XCTAssertTrue(undo.waitForNonExistence(timeout: 6))
    }

    private func search(_ label: String, for text: String) {
        if app.buttons["Close search"].exists { app.buttons["Close search"].tap() }
        let searchButton = app.buttons[label]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 6))
        searchButton.tap()
        let field = app.textFields[label]
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        field.tap()
        field.typeText(text + "\n")
    }

    private func openCoffeePost() {
        app.buttons["Home"].firstMatch.tap()
        search("Search photos or people", for: coffeeCaption)
        let discussion = app.buttons.matching(identifier: "Open photo and comments")
        XCTAssertTrue(discussion.firstMatch.waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts[coffeeCaption].firstMatch.exists)
        XCTAssertEqual(discussion.count, 1)
        discussion.firstMatch.tap()
        XCTAssertTrue(moreControl("More post options").waitForExistence(timeout: 8))
    }

    func testCoffeePostMenuAndReport() {
        openCoffeePost()
        let menu = moreControl("More post options")
        let commentMenu = moreControl("More options for comment by Milo Brooks")
        XCTAssertTrue(menu.exists)
        XCTAssertTrue(commentMenu.exists)
        XCTAssertGreaterThan(menu.frame.midX, app.frame.midX)
        XCTAssertLessThan(menu.frame.midY, app.frame.height / 4)
        XCTAssertFalse(app.buttons["Report comment by Milo Brooks"].exists)
        XCTAssertFalse(app.buttons["Block Milo Brooks"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Coffee detail before opening menus"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        openSafetyMenu("More post options", report: "Report post", author: "Ava Reed")
        app.buttons["Report post"].firstMatch.tap()
        confirm("Report")
        dismissSavedReport("Coffee post report saved")
        XCTAssertTrue(app.staticTexts["Coffee tastes better together."].firstMatch.waitForNonExistence(timeout: 8))
        app.terminate()
        launchShorts()
        openSettingsList("Reported posts")
        undoRecord("Withdraw report for Coffee tastes better together.")
    }

    private func confirmBlockAndDismissSuccess() {
        confirm("Block")
        let message = app.alerts.staticTexts["User blocked."]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        confirm("OK")
        XCTAssertTrue(message.waitForNonExistence(timeout: 4))
    }

    func testBlockingMemberFromShortsReturnsToRefreshedFeed() throws {
        let first = try clip()
        let avatar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open ' AND label ENDSWITH %@", "'s profile")).firstMatch
        let profileLabel = avatar.label
        avatar.tap()
        let block = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Block '")).firstMatch
        XCTAssertTrue(block.waitForExistence(timeout: 8))
        let person = String(block.label.dropFirst("Block ".count))
        block.tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(block.exists)
        block.tap()
        confirmBlockAndDismissSuccess()
        XCTAssertTrue(app.buttons["More video options"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons[profileLabel].exists)
        XCTAssertNotEqual(try clip(), first)
        openSettingsList("Blocked people")
        undoRecord("Unblock " + person)
    }

    func testCoffeeDetailBlocksCommenterAndPublisher() {
        openCoffeePost()
        let commentMenu = "More options for comment by Milo Brooks"
        openSafetyMenu(commentMenu, report: "Report comment", author: "Milo Brooks")
        app.buttons["Block Milo Brooks"].tap()
        XCTAssertTrue(app.alerts.staticTexts["If you block Milo Brooks, you’ll no longer see their posts or comments."].waitForExistence(timeout: 6))
        confirmBlockAndDismissSuccess()
        XCTAssertTrue(moreControl(commentMenu).waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Discover"].waitForExistence(timeout: 8))
        openCoffeePost()
        openSafetyMenu("More post options", report: "Report post", author: "Ava Reed")
        app.buttons["Block Ava Reed"].tap()
        XCTAssertTrue(app.alerts.staticTexts["If you block Ava Reed, you’ll no longer see their posts or comments."].waitForExistence(timeout: 6))
        confirmBlockAndDismissSuccess()
        XCTAssertTrue(app.staticTexts["Coffee tastes better together."].firstMatch.waitForNonExistence(timeout: 8))
        openSettingsList("Blocked people")
        undoRecord("Unblock Milo Brooks")
        undoRecord("Unblock Ava Reed")
    }

    func testPhotoCommentReportDialog() {
        openCoffeePost()
        checkCommentReport(author: "Milo Brooks", text: "The warm tones make this feel so inviting.", photo: true)
        XCTAssertTrue(app.staticTexts["A little pause in a busy day."].firstMatch.exists)
        app.buttons["Back"].firstMatch.tap()
        withdrawCommentReport(author: "Milo Brooks", text: "The warm tones make this feel so inviting.")
    }

    private func selectCameraShort() throws {
        let caption = try XCTUnwrap(captions["short-camera-day"])
        search("Search shorts or people", for: caption)
        XCTAssertTrue(app.staticTexts[caption].waitForExistence(timeout: 8))
        XCTAssertEqual(try clip(), "short-camera-day")
    }

    func testShortCommentReportDialogAndWithdrawal() throws {
        try selectCameraShort()
        let text = "The camera strap makes this feel so familiar."
        app.buttons["Open 4 comments"].tap()
        checkCommentReport(author: "Rowan Ellis", text: text, photo: false)
        XCTAssertTrue(app.staticTexts["That soft light is lovely."].firstMatch.exists)
        app.terminate()
        launchShorts()
        try selectCameraShort()
        XCTAssertTrue(app.buttons["Open 3 comments"].exists)
        withdrawCommentReport(author: "Rowan Ellis", text: text)
        app.terminate()
        launchShorts()
        try selectCameraShort()
        app.buttons["Open 4 comments"].tap()
        XCTAssertTrue(app.staticTexts[text].firstMatch.waitForExistence(timeout: 6))
    }

    private let topicCaption = "Tea, a book and an afternoon with no plans."
    private let topicComment = "That looks like a good place to spend an hour."

    private func openTopicCategory() {
        app.buttons["Topics"].firstMatch.tap()
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "At home")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        tile.tap()
        XCTAssertTrue(app.buttons["Add a photo"].waitForExistence(timeout: 8))
    }

    private func moreControl(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private var topicCover: XCUIElement { app.buttons["photo-cover-reading-break-0"] }

    private func openTopicPost() {
        XCTAssertTrue(topicCover.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts[topicCaption].firstMatch.exists)
        topicCover.tap()
        XCTAssertTrue(moreControl("More post options").waitForExistence(timeout: 8))
    }

    private func openSafetyMenu(_ name: String, report: String, author: String) {
        let more = moreControl(name)
        if name.hasPrefix("More options for comment") {
            for _ in 0..<5 {
                if more.exists && more.isHittable { break }
                app.swipeUp()
            }
        }
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons[report].firstMatch.exists)
        XCTAssertFalse(app.buttons["Block " + author].firstMatch.exists)
        if !more.isHittable { app.swipeUp() }
        more.tap()
        XCTAssertTrue(app.buttons[report].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Report author " + author].firstMatch.exists)
        XCTAssertTrue(app.buttons["Block " + author].firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openSettingsList(_ name: String) {
        app.buttons["Me"].firstMatch.tap()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch.tap()
    }

    private func undoRecord(_ name: String) {
        let undo = app.buttons[name].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.tap()
        confirm(name.hasPrefix("Unblock ") ? "Unblock" : "Withdraw")
        XCTAssertTrue(undo.waitForNonExistence(timeout: 6))
    }

    func testTopicPostReportAndAuthorBlock() {
        openTopicCategory()
        openTopicPost()
        openSafetyMenu("More post options", report: "Report post", author: "Nora Vale")
        app.buttons["Cancel"].firstMatch.tap()
        moreControl("More post options").tap()
        app.buttons["Report post"].firstMatch.tap()
        confirm("Report")
        dismissSavedReport("Topic post report saved")
        XCTAssertFalse(topicCover.exists)
        app.terminate()
        launchShorts()
        openTopicCategory()
        XCTAssertFalse(topicCover.exists)
        app.buttons["Back"].firstMatch.tap()
        openSettingsList("Reported posts")
        undoRecord("Withdraw report for " + topicCaption)

        app.terminate()
        launchShorts()
        openTopicCategory()
        openTopicPost()
        moreControl("More post options").tap()
        app.buttons["Block Nora Vale"].firstMatch.tap()
        confirmBlockAndDismissSuccess()
        XCTAssertTrue(app.buttons["Open photo and comments"].firstMatch.waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Filter topics"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.buttons["Back"].exists)
        openSettingsList("Blocked people")
        undoRecord("Unblock Nora Vale")
    }

    func testTopicCommentReportAndAuthorBlock() {
        openTopicCategory()
        openTopicPost()
        let more = "More options for comment by Kit Lane"
        openSafetyMenu(more, report: "Report comment", author: "Kit Lane")
        app.buttons["Report comment"].firstMatch.tap()
        confirm("Report")
        dismissSavedReport("Topic comment report saved")
        XCTAssertFalse(app.staticTexts[topicComment].firstMatch.exists)
        XCTAssertTrue(moreControl("More post options").exists)
        app.terminate()
        launchShorts()
        withdrawCommentReport(author: "Kit Lane", text: topicComment)

        app.terminate()
        launchShorts()
        openTopicCategory()
        openTopicPost()
        openSafetyMenu(more, report: "Report comment", author: "Kit Lane")
        app.buttons["Block Kit Lane"].firstMatch.tap()
        confirmBlockAndDismissSuccess()
        XCTAssertTrue(moreControl(more).waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Filter topics"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Back"].exists)
        app.terminate()
        launchShorts()
        openSettingsList("Blocked people")
        undoRecord("Unblock Kit Lane")
    }

    func testReportAndLongPressWithdrawal() throws {
        let first = try clip()
        let title = try XCTUnwrap(captions[first])
        app.buttons["More video options"].tap()
        app.buttons["Report video"].tap()
        confirm("Report")
        dismissSavedReport("Video report saved")
        XCTAssertFalse(app.staticTexts[title].exists)
        app.terminate()
        launchShorts()
        XCTAssertNotEqual(try clip(), first)
        openSettingsList("Reported videos")
        let undo = app.buttons["Withdraw report for " + title]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.press(forDuration: 0.9)
        confirm("Withdraw")
        XCTAssertTrue(app.staticTexts["No reported videos"].firstMatch.waitForExistence(timeout: 8))
    }

    func testShortOptionsReportAndBlockThePublisher() throws {
        try selectCameraShort()
        app.buttons["More video options"].tap()
        app.buttons["Report author Milo Brooks"].tap()
        confirm("Report")
        dismissSavedReport("Short publisher report saved")
        XCTAssertEqual(try clip(), "short-camera-day")
        app.terminate()
        launchShorts()
        openSettingsList("Reported authors")
        undoRecord("Withdraw report for Milo Brooks")
        returnToRoot()
        app.buttons["Shorts"].firstMatch.tap()
        try selectCameraShort()
        app.buttons["More video options"].tap()
        app.buttons["Block Milo Brooks"].tap()
        confirmBlockAndDismissSuccess()
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(app.staticTexts[try XCTUnwrap(captions["short-camera-day"])].exists)
        openSettingsList("Blocked people")
        undoRecord("Unblock Milo Brooks")
    }

    func testCancelEachShortSafetyActionKeepsTheCurrentVideo() throws {
        let initial = try clip()
        let profile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open ' AND label ENDSWITH %@", "'s profile")).firstMatch
        let name = String(profile.label.dropFirst("Open ".count).dropLast("'s profile".count))
        app.buttons["More video options"].tap()
        XCTAssertTrue(app.buttons["Block " + name].waitForExistence(timeout: 6))
        let menu = XCTAttachment(screenshot: app.screenshot())
        menu.name = "Short publisher safety options"
        menu.lifetime = .keepAlways
        add(menu)
        for label in ["Report video", "Report author " + name, "Block " + name] {
            let action = app.buttons[label]
            XCTAssertTrue(action.waitForExistence(timeout: 6))
            action.tap()
            confirm("Cancel")
            XCTAssertTrue(action.waitForExistence(timeout: 6))
            XCTAssertFalse(app.alerts.staticTexts[successMessage].exists)
            XCTAssertFalse(app.alerts.staticTexts["User blocked."].exists)
        }
        app.buttons["Close"].firstMatch.tap()
        XCTAssertEqual(try clip(), initial)
        XCTContext.runActivity(named: "Home photo card safety options") { _ in
            app.buttons["Home"].firstMatch.tap()
            search("Search photos or people", for: coffeeCaption)
            let options = moreControl("Photo options")
            XCTAssertTrue(options.waitForExistence(timeout: 6))
            options.tap()
            XCTAssertTrue(app.buttons["Report post"].waitForExistence(timeout: 6))
            XCTAssertTrue(app.buttons["Report author Ava Reed"].exists)
            XCTAssertTrue(app.buttons["Block Ava Reed"].exists)
            app.buttons["Cancel"].firstMatch.tap()
            XCTAssertTrue(options.exists)
        }
    }

    func testTopicCommentAuthorReportUsesTheCommenter() {
        openTopicCategory()
        openTopicPost()
        openSafetyMenu("More options for comment by Kit Lane", report: "Report comment", author: "Kit Lane")
        app.buttons["Report author Kit Lane"].tap()
        confirm("Report")
        dismissSavedReport("Topic commenter report saved")
        XCTAssertTrue(app.staticTexts[topicComment].exists)
        returnToRoot()
        openSettingsList("Reported authors")
        XCTAssertFalse(app.buttons["Withdraw report for Nora Vale"].exists)
        undoRecord("Withdraw report for Kit Lane")
    }

    private func returnToRoot() {
        for _ in 0..<5 {
            let back = app.buttons["Back"].firstMatch
            if !back.exists { break }
            back.tap()
        }
        XCTAssertFalse(app.buttons["Back"].exists)
    }

    func testAccountChatBlockHidesAnExistingConversation() throws {
        let profile = app.buttons["View June Park's profile"]
        app.buttons["Chats"].firstMatch.tap()
        app.buttons["Find friends"].firstMatch.tap()
        search("Search people", for: "June Park")
        let accept = app.buttons["Accept request from June Park"]
        if accept.exists { accept.tap() }
        let conversation = app.buttons["Message June Park"]
        try XCTSkipUnless(conversation.exists, "This test needs a QA journal with June's incoming request or existing messaging access.")
        conversation.tap()
        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        field.tap()
        field.typeText("Hello")
        XCTAssertEqual(field.value as? String, "Hello")
        app.buttons["Send message"].tap()
        XCTAssertTrue(app.staticTexts["Hello"].firstMatch.waitForExistence(timeout: 6))
        profile.tap()
        app.buttons["Block June Park"].tap()
        confirmBlockAndDismissSuccess()
        XCTAssertTrue(app.buttons["Find friends"].firstMatch.waitForExistence(timeout: 6))
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(profile.exists)
        openSettingsList("Blocked people")
        undoRecord("Unblock June Park")
        returnToRoot()
        app.buttons["Chats"].firstMatch.tap()
        XCTAssertTrue(profile.waitForExistence(timeout: 6))
    }

    func testReportAndBlockRestoreSavedVideoOnlyAfterBothAreUndone() throws {
        let title = try XCTUnwrap(captions["short-camera-day"])
        try selectCameraShort()
        let save = app.buttons["Save short"]
        let previouslySaved = save.isSelected
        if !previouslySaved { save.tap() }
        for unblockFirst in [true, false] {
            app.buttons["More video options"].tap()
            app.buttons["Report video"].tap()
            confirm("Report")
            dismissSavedReport("Reported saved video")
            XCTAssertTrue(app.staticTexts["No matching shorts"].waitForExistence(timeout: 6))
            swipe(up: false)
            XCTAssertTrue(app.staticTexts["No matching shorts"].exists)
            XCTAssertFalse(app.staticTexts[title].exists)

            app.buttons["Chats"].firstMatch.tap()
            app.buttons["Find friends"].firstMatch.tap()
            search("Search people", for: "Milo Brooks")
            app.buttons["View Milo Brooks's profile"].tap()
            app.buttons["Block Milo Brooks"].tap()
            confirmBlockAndDismissSuccess()
            XCTAssertTrue(app.buttons["Find friends"].firstMatch.waitForExistence(timeout: 6))
            XCTAssertFalse(app.buttons["Back"].exists)
            XCTAssertFalse(app.buttons["View Milo Brooks's profile"].exists)

            func undo(block: Bool) {
                openSettingsList(block ? "Blocked people" : "Reported videos")
                undoRecord(block ? "Unblock Milo Brooks" : "Withdraw report for " + title)
                returnToRoot()
            }
            undo(block: unblockFirst)
            app.buttons["Shorts"].firstMatch.tap()
            search("Search shorts or people", for: title)
            XCTAssertTrue(app.staticTexts["No matching shorts"].waitForExistence(timeout: 6))
            app.buttons["Me"].firstMatch.tap()
            app.buttons["Saved"].firstMatch.tap()
            let savedVideo = app.buttons["Play " + title]
            XCTAssertFalse(savedVideo.exists)

            undo(block: !unblockFirst)
            app.buttons["Saved"].firstMatch.tap()
            XCTAssertTrue(savedVideo.waitForExistence(timeout: 6))
            savedVideo.tap()
            XCTAssertEqual(try clip(), "short-camera-day")
            app.buttons["Shorts"].firstMatch.tap()
            try selectCameraShort()
        }
        if !previouslySaved { app.buttons["Save short"].tap() }
    }
}
