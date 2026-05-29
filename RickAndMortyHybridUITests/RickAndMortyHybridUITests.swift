//
//  RickAndMortyHybridUITests.swift
//  RickAndMortyHybridUITests
//
//  Created by rico on 22.01.2026.
//

import XCTest

final class FeatureHomeUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // harness:criterion=c-homeview-existing-list-preserved,c-homeview-loading-state-unchanged
    func testUserCanScrollAndOpenDetailWithoutCrash() throws {
        launchUITestingApp()
        let loadingIndicator = app.otherElements["loading_indicator"]
        if loadingIndicator.exists {
            
            let doesNotExist = loadingIndicator.waitForExistence(timeout: 10)
            
            XCTAssertFalse(doesNotExist == false, "Loading ekranı takılı kaldı!")
            
        }
        let list = app.collectionViews["character_list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Karakter listesi yüklenemedi!")
        list.swipeUp()
        list.swipeUp()
        list.swipeDown()
        
        let targetRow = app.buttons["row_Morty Smith"]
        var scrollAttempts = 0
        
        while !targetRow.exists && scrollAttempts < 5 {
            list.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(targetRow.exists, "Morty Smith listede bulunamadı!")
        targetRow.tap()
        
        let detailName = app.staticTexts["detail_character_name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3), "Detay sayfasına geçiş yapılamadı!")
        XCTAssertEqual(detailName.label, "Morty Smith")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.exists, "Geri dönüldüğünde liste görüntülenemedi!")
        
    }

    // harness:criterion=c-homeview-picker-present-in-success-branch
    func testStatusFilterControlAppearsAfterSuccessfulLoad() throws {
        launchUITestingApp()
        _ = waitForCharacterList()

        let filter = statusFilterControl()
        XCTAssertTrue(filter.waitForExistence(timeout: 2), "Status filter control was not shown after successful load.")
        XCTAssertTrue(filter.isHittable, "Status filter control exists but cannot be used.")
        XCTAssertTrue(app.buttons["All"].exists)
        XCTAssertTrue(app.buttons["Alive"].exists)
        XCTAssertTrue(app.buttons["Dead"].exists)
        XCTAssertTrue(app.buttons["Unknown"].exists)
    }

    // harness:criterion=c-homeview-picker-absent-outside-success-branch
    func testStatusFilterControlIsNotShownWhileLoading() throws {
        launchUITestingApp()

        if app.otherElements["loading_indicator"].exists {
            XCTAssertFalse(statusFilterControl().exists, "Status filter control should not be visible before the success state.")
        }

        _ = waitForCharacterList()
    }

    // harness:criterion=c-uitesting-repo-fixture-has-alive-character,c-uitesting-repo-fixture-has-dead-character,c-uitesting-repo-fixture-has-unknown-character,c-uitest-alive-filter-shows-alive-rows,c-uitest-dead-filter-shows-dead-rows,c-uitest-unknown-filter-shows-unknown-rows,c-uitest-all-filter-shows-all-rows
    func testStatusFiltersShowExpectedFixtureRows() throws {
        launchUITestingApp()
        _ = waitForCharacterList()

        selectFilter(named: "Alive")
        assertRows(visible: ["Rick Sanchez", "Morty Smith"], hidden: ["Birdperson", "Squanchy"])

        selectFilter(named: "Dead")
        assertRows(visible: ["Birdperson"], hidden: ["Rick Sanchez", "Morty Smith", "Squanchy"])

        selectFilter(named: "Unknown")
        assertRows(visible: ["Squanchy"], hidden: ["Rick Sanchez", "Morty Smith", "Birdperson"])

        selectFilter(named: "All")
        assertRows(visible: ["Rick Sanchez", "Morty Smith", "Birdperson", "Squanchy"], hidden: [])
    }

    // harness:criterion=c-uitest-filter-detail-navigation,c-uitest-detail-back-returns-to-filtered-list
    func testDetailNavigationPreservesActiveFilter() throws {
        launchUITestingApp()
        _ = waitForCharacterList()

        selectFilter(named: "Dead")
        let deadRow = row(named: "Birdperson")
        XCTAssertTrue(deadRow.waitForExistence(timeout: 2), "Dead fixture row was not visible after selecting the Dead filter.")
        deadRow.tap()

        let detailName = app.staticTexts["detail_character_name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3), "Detail screen did not appear for the filtered row.")
        XCTAssertEqual(detailName.label, "Birdperson")

        app.navigationBars.buttons.element(boundBy: 0).tap()

        _ = waitForCharacterList()
        XCTAssertTrue(statusFilterControl().buttons["Dead"].isSelected, "Dead filter should still be selected after returning from detail.")
        assertRows(visible: ["Birdperson"], hidden: ["Rick Sanchez", "Morty Smith", "Squanchy"])
    }

    private func launchUITestingApp() {
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    private func waitForCharacterList(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let list = app.collectionViews["character_list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Character list did not load.", file: file, line: line)
        return list
    }

    private func statusFilterControl() -> XCUIElement {
        let segmentedControl = app.segmentedControls["status_filter_picker"]
        let picker = app.pickers["status_filter_picker"]
        return picker.exists && !segmentedControl.exists ? picker : segmentedControl
    }

    private func selectFilter(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let filter = statusFilterControl()
        XCTAssertTrue(filter.waitForExistence(timeout: 2), "Status filter control was not visible.", file: file, line: line)

        let segment = filter.buttons[name].exists ? filter.buttons[name] : app.buttons[name]
        XCTAssertTrue(segment.waitForExistence(timeout: 2), "Filter segment \(name) was not available.", file: file, line: line)
        segment.tap()
    }

    private func assertRows(
        visible visibleNames: [String],
        hidden hiddenNames: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for name in visibleNames {
            XCTAssertTrue(row(named: name).waitForExistence(timeout: 2), "Expected row for \(name) to be visible.", file: file, line: line)
        }

        for name in hiddenNames {
            XCTAssertFalse(row(named: name).exists, "Expected row for \(name) to be hidden.", file: file, line: line)
        }
    }

    private func row(named name: String) -> XCUIElement {
        app.buttons["row_\(name)"]
    }
}
