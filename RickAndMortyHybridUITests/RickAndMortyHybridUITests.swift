//
//  RickAndMortyHybridUITests.swift
//  RickAndMortyHybridUITests
//
//  Created by rico on 22.01.2026.
//

import XCTest

final class FeatureHomeUITests: XCTestCase {
    
    var app: XCUIApplication!
    private let aliveNames = ["Rick Sanchez", "Morty Smith"]
    private let deadName = "Birdperson"
    private let unknownName = "Squanchy"
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    func testUserCanScrollAndOpenDetailWithoutCrash() throws {
        //harness:criterion=c-scroll-behavior-preserved,c-detail-navigation-preserved
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

    func testStatusFilterSegmentsAreVisible() throws {
        //harness:criterion=c-picker-control-present
        waitForCharacterList()

        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 5), "Status segmented control was not visible")
        XCTAssertEqual(segmentedControl.buttons.count, 4)
        XCTAssertTrue(segmentedControl.buttons["All"].exists)
        XCTAssertTrue(segmentedControl.buttons["Alive"].exists)
        XCTAssertTrue(segmentedControl.buttons["Dead"].exists)
        XCTAssertTrue(segmentedControl.buttons["Unknown"].exists)
    }

    func testAllFilterShowsFixtureRowsAndPreservesAccessibilityIdentifiers() throws {
        //harness:criterion=c-picker-all-segment-restores-full-list,c-accessibility-character-list-preserved,c-accessibility-row-name-preserved,c-app-configurator-fixture-covers-all-statuses
        waitForCharacterList()

        tapSegment("Alive")
        tapSegment("All")

        XCTAssertTrue(characterList.exists)
        for name in aliveNames + [deadName, unknownName] {
            assertRowExists(name)
        }
    }

    func testAliveFilterShowsOnlyAliveRows() throws {
        //harness:criterion=c-picker-bound-to-selected-filter
        waitForCharacterList()

        tapSegment("Alive")

        for name in aliveNames {
            assertRowExists(name)
        }
        assertRowDoesNotExist(deadName)
        assertRowDoesNotExist(unknownName)
    }

    func testDeadFilterShowsOnlyDeadRows() throws {
        //harness:criterion=c-picker-dead-segment-filters-ui
        waitForCharacterList()

        tapSegment("Dead")

        assertRowExists(deadName)
        for name in aliveNames + [unknownName] {
            assertRowDoesNotExist(name)
        }
    }

    func testUnknownFilterShowsOnlyUnknownRows() throws {
        //harness:criterion=c-picker-unknown-segment-filters-ui
        waitForCharacterList()

        tapSegment("Unknown")

        assertRowExists(unknownName)
        for name in aliveNames + [deadName] {
            assertRowDoesNotExist(name)
        }
    }

    func testTappingFilteredRowNavigatesToDetail() throws {
        //harness:criterion=c-detail-navigation-preserved
        waitForCharacterList()
        tapSegment("Alive")

        let row = app.buttons["row_Rick Sanchez"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Alive row was not visible")
        row.tap()

        let detailName = app.staticTexts["detail_character_name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3), "Detail screen was not presented")
        XCTAssertEqual(detailName.label, "Rick Sanchez")
    }

    func testLoadingIndicatorAccessibilityIdentifierIsPreserved() throws {
        //harness:criterion=c-accessibility-loading-indicator-preserved
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()

        XCTAssertTrue(waitForLoadingIndicator(timeout: 1), "Loading indicator was not exposed while the list was loading")
    }

    func testFilteredCharacterListCanStillBeScrolled() throws {
        //harness:criterion=c-scroll-behavior-preserved
        waitForCharacterList()
        tapSegment("Alive")

        let list = characterList
        XCTAssertTrue(list.exists)

        let offscreenAliveRow = app.buttons["row_Alexander"]
        XCTAssertFalse(offscreenAliveRow.isHittable, "Expected row_Alexander to start outside the visible filtered list")

        var swipeAttempts = 0
        while !offscreenAliveRow.isHittable && swipeAttempts < 6 {
            list.swipeUp()
            swipeAttempts += 1
        }

        XCTAssertTrue(offscreenAliveRow.isHittable, "Expected the filtered character list to scroll to row_Alexander")
    }

    private var characterList: XCUIElement {
        let collectionView = app.collectionViews["character_list"]
        if collectionView.exists {
            return collectionView
        }

        let table = app.tables["character_list"]
        if table.exists {
            return table
        }

        return collectionView
    }

    private func waitForCharacterList(file: StaticString = #filePath, line: UInt = #line) {
        let collectionView = app.collectionViews["character_list"]
        if collectionView.waitForExistence(timeout: 5) {
            return
        }

        let table = app.tables["character_list"]
        if table.waitForExistence(timeout: 1) {
            return
        }

        XCTFail("Character list was not visible", file: file, line: line)
    }

    private func tapSegment(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let segment = app.segmentedControls.buttons[title]
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "Missing \(title) segment", file: file, line: line)
        segment.tap()
    }

    private func waitForLoadingIndicator(timeout: TimeInterval) -> Bool {
        let activityIndicator = app.activityIndicators["loading_indicator"]
        if activityIndicator.waitForExistence(timeout: timeout) {
            return true
        }

        return app.otherElements["loading_indicator"].waitForExistence(timeout: timeout)
    }

    private func assertRowExists(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["row_\(name)"].waitForExistence(timeout: 5), "Expected row_\(name) to exist", file: file, line: line)
    }

    private func assertRowDoesNotExist(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.buttons["row_\(name)"].waitForExistence(timeout: 1), "Expected row_\(name) to be hidden", file: file, line: line)
    }
}
