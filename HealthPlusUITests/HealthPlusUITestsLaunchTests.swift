import XCTest

final class HealthPlusUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-in-memory"]
        app.launch()

        let shellButton = app.buttons["shell.tab.log"]
        if shellButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(shellButton.isHittable)
            return
        }

        XCTAssertTrue(app.tabBars.buttons["Log"].waitForExistence(timeout: 8))
    }
}
