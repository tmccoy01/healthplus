import XCTest

final class HealthPlusUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-in-memory"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Log"].waitForExistence(timeout: 8))
    }
}
