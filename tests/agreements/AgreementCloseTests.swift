import XCTest

final class AgreementCloseTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.roro.photography")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(welcome.waitForExistence(timeout: 15))
    }

    private var welcome: XCUIElement { app.staticTexts["Welcome to Roro"] }
    private var settings: XCUIElement { app.buttons["Edit profile"] }

    private func openSettings() {
        let login = app.buttons["Log in"]
        if !login.isEnabled {
            app.buttons["I agree to the"].tap()
        }
        login.tap()
        let me = app.buttons["Me"]
        XCTAssertTrue(me.waitForExistence(timeout: 10))
        me.tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
    }

    private func verifyClose(_ title: String, returningTo origin: XCUIElement) {
        let link = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ AND (elementType == %d OR elementType == %d)",
            title, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.link.rawValue
        )).firstMatch
        XCTAssertTrue(link.isHittable)
        link.tap()

        let toolbar = app.otherElements["TopBrowserBar"]
        let close = toolbar.buttons.matching(NSPredicate(
            format: "label IN %@", ["Close", "Done", "关闭", "完成"]
        )).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        let document = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Roro - " + title)).firstMatch
        XCTAssertTrue(document.waitForExistence(timeout: 30), "Expected the selected agreement to load")
        XCTAssertFalse(origin.exists && origin.isHittable)
        // Safari's suggested hit point can fall outside its circular close button.
        close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: toolbar)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(origin.waitForExistence(timeout: 10))
        XCTAssertTrue(origin.isHittable)
        XCTAssertTrue(link.isHittable)
    }

    func testTermsCloseReturnsToWelcome() {
        verifyClose("Terms of Service", returningTo: welcome)
    }

    func testPrivacyCloseReturnsToWelcome() {
        verifyClose("Privacy Policy", returningTo: welcome)
    }

    func testTermsCloseReturnsToSettings() {
        openSettings()
        verifyClose("Terms of Service", returningTo: settings)
    }

    func testPrivacyCloseReturnsToSettings() {
        openSettings()
        verifyClose("Privacy Policy", returningTo: settings)
    }
}
