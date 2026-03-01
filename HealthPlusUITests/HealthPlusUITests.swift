import XCTest

final class HealthPlusUITests: XCTestCase {
    private enum ShellTab: String, CaseIterable {
        case log
        case history
        case stats
        case settings

        var accessibilityIdentifier: String {
            "shell.tab.\(rawValue)"
        }

        var fallbackTitle: String {
            switch self {
            case .log:
                return "Log"
            case .history:
                return "History"
            case .stats:
                return "Stats"
            case .settings:
                return "Settings"
            }
        }

        var navigationTitle: String {
            fallbackTitle
        }
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        launchApp(useInMemoryStore: true)
    }

    func testShellRendersTabsAndSupportsAccessibility() throws {
        let shellChrome = findElement("shell.tab.chrome")
        XCTAssertTrue(shellChrome.waitForExistence(timeout: 8))

        for tab in ShellTab.allCases {
            let button = shellButton(for: tab)
            XCTAssertTrue(button.waitForExistence(timeout: 8))
            XCTAssertTrue(button.isHittable)
            XCTAssertFalse(button.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testShellTabSwitchingShowsExpectedRootTitles() throws {
        let cycle: [ShellTab] = [.history, .stats, .settings, .log]

        for tab in cycle {
            switchToTab(tab)
            let navTitle = app.navigationBars[tab.navigationTitle].firstMatch
            XCTAssertTrue(navTitle.waitForExistence(timeout: 8))
        }
    }

    func testStatsShowsNoSessionsStateOnFreshLaunch() throws {
        switchToTab(.stats)

        let noSessions = findElement("stats.placeholder.noSessions")
        XCTAssertTrue(noSessions.waitForExistence(timeout: 8))
    }

    func testLogFeedRowTapNavigatesToSessionDetail() throws {
        createAndSaveSimpleSession(exerciseName: "Incline Press", reps: "8", weight: "155")

        switchToTab(.log)
        let sessionRow = app.buttons.matching(identifier: "log.feed.row").firstMatch
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 8))
        sessionRow.tap()

        let exerciseField = app.textFields["Exercise"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 8))
        XCTAssertEqual(exerciseField.value as? String, "Incline Press")
    }

    func testLogFeedSwipeActionsExposeQuickActions() throws {
        createAndSaveSimpleSession(exerciseName: "Dumbbell Row", reps: "10", weight: "85")

        switchToTab(.log)
        let sessionRow = app.buttons.matching(identifier: "log.feed.row").firstMatch
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 8))

        sessionRow.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 8))

        sessionRow.swipeRight()
        let duplicateButton = app.buttons["Duplicate"]
        XCTAssertTrue(duplicateButton.waitForExistence(timeout: 8))
    }

    func testLogFeedEditModeToggleShowsAndHidesEditingIndicator() throws {
        createAndSaveSimpleSession(exerciseName: "Lat Pulldown", reps: "12", weight: "140")

        switchToTab(.log)
        let editButton = app.buttons["log.feed.toolbar.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 8))

        editButton.tap()
        let editingIndicator = findElement("log.feed.editing.indicator")
        XCTAssertTrue(editingIndicator.waitForExistence(timeout: 8))

        editButton.tap()
        XCTAssertFalse(editingIndicator.waitForExistence(timeout: 1))
    }

    func testCreateSessionAndVerifyHistoryEntry() throws {
        createAndSaveSimpleSession(exerciseName: "Bench Press", reps: "8", weight: "185")

        switchToTab(.history)

        let sessionLink = app.buttons.matching(identifier: "history.session.link").firstMatch
        XCTAssertTrue(sessionLink.waitForExistence(timeout: 8))
        sessionLink.tap()

        let exerciseField = app.textFields["Exercise"]
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 8))
        XCTAssertTrue(exerciseField.value as? String == "Bench Press")

        let repsField = app.textFields.matching(identifier: "log.set.reps.field").firstMatch
        let weightField = app.textFields.matching(identifier: "log.set.weight.field").firstMatch
        XCTAssertTrue(repsField.exists)
        XCTAssertTrue(weightField.exists)
        XCTAssertTrue(repsField.value as? String == "8")
        XCTAssertTrue(weightField.value as? String == "185")
    }

    func testEditSetInHistoryPersists() throws {
        createAndSaveSimpleSession(exerciseName: "Overhead Press", reps: "6", weight: "115")

        switchToTab(.history)
        let sessionLink = app.buttons.matching(identifier: "history.session.link").firstMatch
        XCTAssertTrue(sessionLink.waitForExistence(timeout: 8))
        sessionLink.tap()

        let repsField = app.textFields.matching(identifier: "log.set.reps.field").firstMatch
        let weightField = app.textFields.matching(identifier: "log.set.weight.field").firstMatch
        XCTAssertTrue(repsField.waitForExistence(timeout: 8))
        XCTAssertTrue(weightField.waitForExistence(timeout: 8))

        repsField.replaceText(with: "10")
        weightField.replaceText(with: "135")

        app.navigationBars.buttons["History"].firstMatch.tap()
        sessionLink.tap()

        XCTAssertTrue(repsField.waitForExistence(timeout: 8))
        XCTAssertTrue(weightField.waitForExistence(timeout: 8))
        XCTAssertTrue(repsField.value as? String == "10")
        XCTAssertTrue(weightField.value as? String == "135")
    }

    func testSessionDetailSupportsAddEditDeleteUndoAndReorderSetRows() throws {
        switchToTab(.log)
        let startButton = app.buttons["log.start.button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 8))
        startButton.tap()

        let addExerciseButton = app.buttons["log.exercise.add.button"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 8))
        addExerciseButton.tap()

        let exerciseNameField = app.textFields["log.exercise.name.field"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 8))
        exerciseNameField.tap()
        exerciseNameField.typeText("Phase 7 Rows")

        let saveExerciseButton = app.buttons["log.exercise.save.button"]
        XCTAssertTrue(saveExerciseButton.waitForExistence(timeout: 8))
        saveExerciseButton.tap()

        let addSetButton = app.buttons.matching(identifier: "log.set.add.button").firstMatch
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 8))
        addSetButton.tap()
        addSetButton.tap()

        var repsFields = app.textFields.matching(identifier: "log.set.reps.field")
        let weightFields = app.textFields.matching(identifier: "log.set.weight.field")
        XCTAssertTrue(repsFields.element(boundBy: 0).waitForExistence(timeout: 8))
        XCTAssertTrue(repsFields.element(boundBy: 1).waitForExistence(timeout: 8))
        XCTAssertTrue(weightFields.element(boundBy: 0).waitForExistence(timeout: 8))
        XCTAssertTrue(weightFields.element(boundBy: 1).waitForExistence(timeout: 8))

        repsFields.element(boundBy: 0).replaceText(with: "12")
        weightFields.element(boundBy: 0).replaceText(with: "95")
        repsFields.element(boundBy: 1).replaceText(with: "10")
        weightFields.element(boundBy: 1).replaceText(with: "115")

        let moveDownButton = app.buttons.matching(identifier: "log.set.move.down.button").firstMatch
        XCTAssertTrue(moveDownButton.waitForExistence(timeout: 8))
        moveDownButton.tap()

        repsFields = app.textFields.matching(identifier: "log.set.reps.field")
        XCTAssertEqual(repsFields.element(boundBy: 0).value as? String, "10")

        let firstRow = app.otherElements.matching(identifier: "log.set.row").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8))
        firstRow.swipeLeft()

        let deleteSetButton = app.buttons["Delete Set"]
        XCTAssertTrue(deleteSetButton.waitForExistence(timeout: 8))
        deleteSetButton.tap()

        repsFields = app.textFields.matching(identifier: "log.set.reps.field")
        XCTAssertEqual(repsFields.element(boundBy: 0).value as? String, "12")

        let undoDeleteButton = app.buttons["Undo Deleted Set"]
        XCTAssertTrue(undoDeleteButton.waitForExistence(timeout: 8))
        undoDeleteButton.tap()

        repsFields = app.textFields.matching(identifier: "log.set.reps.field")
        XCTAssertEqual(repsFields.element(boundBy: 0).value as? String, "10")
    }

    func testSetEditsPersistThroughRelaunch() throws {
        app.terminate()
        launchApp(useInMemoryStore: false)
        finishAnyActiveSessionIfNeeded()

        let uniqueExerciseName = "Phase7 Relaunch \(UUID().uuidString.prefix(6))"
        createAndSaveSimpleSession(exerciseName: uniqueExerciseName, reps: "9", weight: "135")

        app.terminate()
        launchApp(useInMemoryStore: false)
        finishAnyActiveSessionIfNeeded()

        switchToTab(.log)
        let sessionRow = app.buttons.matching(identifier: "log.feed.row").firstMatch
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 8))
        sessionRow.tap()

        let exerciseField = app.textFields.matching(identifier: "log.exercise.name.inline").firstMatch
        XCTAssertTrue(exerciseField.waitForExistence(timeout: 8))
        XCTAssertEqual(exerciseField.value as? String, uniqueExerciseName)

        let repsField = app.textFields.matching(identifier: "log.set.reps.field").firstMatch
        let weightField = app.textFields.matching(identifier: "log.set.weight.field").firstMatch
        XCTAssertTrue(repsField.waitForExistence(timeout: 8))
        XCTAssertTrue(weightField.waitForExistence(timeout: 8))
        XCTAssertEqual(repsField.value as? String, "9")
        XCTAssertEqual(weightField.value as? String, "135")
    }

    func testOpenStatsApplyDateFiltersAndKeepChartsVisible() throws {
        createAndSaveSimpleSession(exerciseName: "Barbell Row", reps: "8", weight: "155")
        switchToTab(.stats)

        let topSetChart = findElement("stats.chart.topSet")
        let weeklyVolumeChart = findElement("stats.chart.weeklyVolume")
        XCTAssertTrue(topSetChart.waitForExistence(timeout: 8))
        XCTAssertTrue(weeklyVolumeChart.waitForExistence(timeout: 8))

        let allRange = app.buttons["All"]
        XCTAssertTrue(allRange.waitForExistence(timeout: 8))
        allRange.tap()
        XCTAssertTrue(topSetChart.waitForExistence(timeout: 8))

        let fourWeeks = app.buttons["4W"]
        XCTAssertTrue(fourWeeks.waitForExistence(timeout: 8))
        fourWeeks.tap()
        XCTAssertTrue(weeklyVolumeChart.waitForExistence(timeout: 8))
    }

    private func createAndSaveSimpleSession(
        exerciseName: String,
        reps: String,
        weight: String
    ) {
        finishAnyActiveSessionIfNeeded()
        switchToTab(.log)

        let startButton = app.buttons["log.start.button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 8))
        startButton.tap()

        let addExerciseButton = app.buttons["log.exercise.add.button"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 8))
        addExerciseButton.tap()

        let exerciseNameField = app.textFields["log.exercise.name.field"]
        XCTAssertTrue(exerciseNameField.waitForExistence(timeout: 8))
        exerciseNameField.tap()
        exerciseNameField.typeText(exerciseName)

        let saveExerciseButton = app.buttons["log.exercise.save.button"]
        XCTAssertTrue(saveExerciseButton.waitForExistence(timeout: 8))
        saveExerciseButton.tap()

        let addSetButton = app.buttons.matching(identifier: "log.set.add.button").firstMatch
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 8))
        addSetButton.tap()

        let repsField = app.textFields.matching(identifier: "log.set.reps.field").firstMatch
        let weightField = app.textFields.matching(identifier: "log.set.weight.field").firstMatch
        XCTAssertTrue(repsField.waitForExistence(timeout: 8))
        XCTAssertTrue(weightField.waitForExistence(timeout: 8))

        repsField.tap()
        repsField.typeText(reps)
        weightField.tap()
        weightField.typeText(weight)

        let saveSessionButton = app.buttons["log.session.save.button"]
        XCTAssertTrue(saveSessionButton.waitForExistence(timeout: 8))
        saveSessionButton.tap()

        XCTAssertTrue(startButton.waitForExistence(timeout: 8))
    }

    private func launchApp(useInMemoryStore: Bool) {
        app = XCUIApplication()
        app.launchArguments = launchArguments(useInMemoryStore: useInMemoryStore)
        app.launch()
    }

    private func launchArguments(useInMemoryStore: Bool) -> [String] {
        var arguments = [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
        if useInMemoryStore {
            arguments.insert("-ui-testing-in-memory", at: 0)
        }
        return arguments
    }

    private func finishAnyActiveSessionIfNeeded() {
        switchToTab(.log)
        let saveSessionButton = app.buttons["log.session.save.button"]
        if saveSessionButton.exists || saveSessionButton.waitForExistence(timeout: 1) {
            saveSessionButton.tap()
            _ = app.buttons["log.start.button"].waitForExistence(timeout: 8)
        }
    }

    private func switchToTab(_ tab: ShellTab) {
        let button = shellButton(for: tab)
        XCTAssertTrue(button.waitForExistence(timeout: 8))
        button.tap()
    }

    private func shellButton(for tab: ShellTab) -> XCUIElement {
        let custom = app.buttons[tab.accessibilityIdentifier]
        if custom.exists || custom.waitForExistence(timeout: 1) {
            return custom
        }

        return app.tabBars.buttons[tab.fallbackTitle]
    }

    private func findElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }
}

private extension XCUIElement {
    func replaceText(with text: String) {
        tap()

        let currentValue = value as? String ?? ""
        let placeholder = placeholderValue ?? ""
        if currentValue.isEmpty || currentValue == placeholder {
            typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
        typeText(text)
    }
}
