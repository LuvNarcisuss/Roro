import XCTest

final class SafetyTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.roro.photography")
    private let captions = [
        "short-camera-day": "A little practice before heading out. Finding the frame is half the fun.",
        "short-bridge-walk": "Look for the lines. An ordinary walk can turn into a whole photo story.",
        "short-coffee-light": "Window light, a warm cup, and a few quiet seconds before the first sip.",
        "short-cat-pause": "The most patient subject in the house. Until the next nap, anyway.",
        "short-evening-sky": "Stayed a little longer for the last light. Some colors are worth waiting for."
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchShorts()
    }

    private func launchShorts() {
        app.launch()
        let login = app.buttons["Log in"]
        XCTAssertTrue(login.waitForExistence(timeout: 16))
        if !login.isEnabled { app.staticTexts["I agree to the"].firstMatch.tap() }
        login.tap()
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

    private func confirm() {
        let ok = app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["OK", "Ok", "好", "确定"])).firstMatch
        XCTAssertTrue(ok.waitForExistence(timeout: 6))
        ok.tap()
    }

    func testRefreshRoundAndTwoSwipeLaps() throws {
        let initial = try clip()
        swipe(up: true)
        let later = try clip()
        XCTAssertNotEqual(initial, later)
        var pulls = [initial, later]
        for _ in 0..<3 {
            swipe(up: false)
            pulls.append(try clip())
        }
        XCTAssertEqual(Set(pulls).count, 5, pulls.description)
        swipe(up: false)
        var lap = [try clip()]
        XCTAssertNotEqual(lap[0], pulls.last)
        for _ in 0..<10 {
            swipe(up: true)
            lap.append(try clip())
        }
        XCTAssertEqual(Set(lap.prefix(5)).count, 5)
        XCTAssertEqual(Array(lap[0..<5]), Array(lap[5..<10]))
        XCTAssertEqual(lap.first, lap.last)
        let evidence = XCTAttachment(string: "Refresh round: \(pulls)\nTwo laps: \(lap)")
        evidence.name = "Visible clip IDs"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    private let successMessage = "Report saved successfully. Your report is stored only on this iPhone."

    private func dismissSavedReport(_ name: String) {
        let message = app.alerts.staticTexts[successMessage]
        XCTAssertTrue(message.waitForExistence(timeout: 8))
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = name
        evidence.lifetime = .keepAlways
        add(evidence)
        confirm()
        XCTAssertTrue(message.waitForNonExistence(timeout: 4))
    }

    private func checkCommentReport(author: String, text: String, photo: Bool) {
        let menu = "More options for comment by " + author
        let report = app.buttons[photo ? "Report comment" : "Report comment by " + author].firstMatch
        if photo { openSafetyMenu(menu, report: "Report comment", author: author) }
        XCTAssertTrue(report.waitForExistence(timeout: 8))
        report.tap()
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 6))
        cancel.tap()
        XCTAssertTrue(app.staticTexts[text].firstMatch.exists)
        XCTAssertFalse(app.alerts.staticTexts[successMessage].exists)
        if photo { moreControl(menu).tap() }
        report.tap()
        confirm()
        dismissSavedReport(photo ? "Photo comment report saved" : "Short comment report saved")
        XCTAssertFalse(app.staticTexts[text].firstMatch.exists)
    }

    private func withdrawCommentReport(author: String, text: String) {
        app.buttons["Me"].firstMatch.tap()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reported comments")).firstMatch.tap()
        let undo = app.buttons["Withdraw report for " + author + " — " + text]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.press(forDuration: 0.9)
        confirm()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 6))
    }

    private func openCoffeePost() {
        app.buttons["Home"].firstMatch.tap()
        app.buttons["Open photo and comments"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Coffee tastes better together."].firstMatch.waitForExistence(timeout: 8))
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
        confirm()
        dismissSavedReport("Coffee post report saved")
        XCTAssertTrue(app.staticTexts["Coffee tastes better together."].firstMatch.waitForNonExistence(timeout: 8))
        app.terminate()
        launchShorts()
        openSettingsList("Reported posts")
        undoRecord("Withdraw report for Coffee tastes better together.")
    }

    func testCoffeeDetailBlocksCommenterAndPublisher() {
        openCoffeePost()
        let commentMenu = "More options for comment by Milo Brooks"
        openSafetyMenu(commentMenu, report: "Report comment", author: "Milo Brooks")
        app.buttons["Block Milo Brooks"].tap()
        confirm()
        XCTAssertTrue(moreControl(commentMenu).waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Coffee tastes better together."].firstMatch.exists)
        openSafetyMenu("More post options", report: "Report post", author: "Ava Reed")
        app.buttons["Block Ava Reed"].tap()
        confirm()
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

    func testShortCommentReportDialogAndWithdrawal() throws {
        let initial = try clip()
        let text = "The camera strap makes this feel so familiar."
        app.buttons["Open 4 comments"].tap()
        checkCommentReport(author: "Rowan Ellis", text: text, photo: false)
        XCTAssertTrue(app.staticTexts["That soft light is lovely."].firstMatch.exists)
        app.terminate()
        launchShorts()
        XCTAssertEqual(try clip(), initial)
        XCTAssertTrue(app.buttons["Open 3 comments"].exists)
        withdrawCommentReport(author: "Rowan Ellis", text: text)
        app.terminate()
        launchShorts()
        app.buttons["Open 4 comments"].tap()
        XCTAssertTrue(app.staticTexts[text].firstMatch.waitForExistence(timeout: 6))
    }

    private let topicCaption = "A few stems brought the whole table to life."
    private let topicComment = "The yellow against that green is so good."

    private func openTopicCategory() {
        app.buttons["Topics"].firstMatch.tap()
        let tile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Little joys")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        tile.tap()
    }

    private func moreControl(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func openTopicPost() {
        let photo = app.buttons["Open photo and comments"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8))
        photo.tap()
        XCTAssertTrue(moreControl("More post options").waitForExistence(timeout: 8))
    }

    private func openSafetyMenu(_ name: String, report: String, author: String) {
        let more = moreControl(name)
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons[report].firstMatch.exists)
        XCTAssertFalse(app.buttons["Block " + author].firstMatch.exists)
        if !more.isHittable { app.swipeUp() }
        more.tap()
        XCTAssertTrue(app.buttons[report].firstMatch.waitForExistence(timeout: 8))
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
        confirm()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 6))
    }

    func testTopicPostReportAndAuthorBlock() {
        openTopicCategory()
        openTopicPost()
        openSafetyMenu("More post options", report: "Report post", author: "Nora Vale")
        app.buttons["Cancel"].firstMatch.tap()
        moreControl("More post options").tap()
        app.buttons["Report post"].firstMatch.tap()
        confirm()
        dismissSavedReport("Topic post report saved")
        XCTAssertFalse(app.buttons["Open photo and comments"].firstMatch.exists)
        app.terminate()
        launchShorts()
        openTopicCategory()
        XCTAssertFalse(app.buttons["Open photo and comments"].firstMatch.exists)
        app.buttons["Back"].firstMatch.tap()
        openSettingsList("Reported posts")
        undoRecord("Withdraw report for " + topicCaption)

        app.terminate()
        launchShorts()
        openTopicCategory()
        openTopicPost()
        moreControl("More post options").tap()
        app.buttons["Block Nora Vale"].firstMatch.tap()
        confirm()
        XCTAssertTrue(app.buttons["Open photo and comments"].firstMatch.waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Add a photo"].firstMatch.waitForExistence(timeout: 6))
        app.buttons["Back"].firstMatch.tap()
        openSettingsList("Blocked people")
        undoRecord("Unblock Nora Vale")
    }

    func testTopicCommentReportAndAuthorBlock() {
        openTopicCategory()
        openTopicPost()
        let more = "More options for comment by Kit Lane"
        openSafetyMenu(more, report: "Report comment", author: "Kit Lane")
        app.buttons["Report comment"].firstMatch.tap()
        confirm()
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
        confirm()
        XCTAssertTrue(moreControl(more).waitForNonExistence(timeout: 8))
        XCTAssertTrue(moreControl("More post options").exists)
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
        confirm()
        dismissSavedReport("Video report saved")
        XCTAssertFalse(app.staticTexts[title].exists)
        app.terminate()
        launchShorts()
        XCTAssertNotEqual(try clip(), first)
        app.buttons["Me"].firstMatch.tap()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reported videos")).firstMatch.tap()
        let undo = app.buttons["Withdraw report for " + title]
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.press(forDuration: 0.9)
        confirm()
        XCTAssertTrue(app.staticTexts["No reported videos"].firstMatch.waitForExistence(timeout: 8))
    }
}
