//
//  RickAndMortyHybridUITests.swift
//  RickAndMortyHybridUITests
//
//  Created by rico on 22.01.2026.
//

import XCTest

final class RickAndMortyHybridUITests: XCTestCase {
    
    var app: XCUIApplication!
    private let aliveCharacterName = "Rick Sanchez"
    private let secondAliveCharacterName = "Morty Smith"
    private let deadCharacterName = "Adjudicator Rick"
    private let unknownCharacterName = "Antenna Morty"
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    func testUserCanScrollAndOpenDetailWithoutCrash() throws {
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

    func testFilterPickerExists() throws {
        //harness:criterion=c-homeview-filter-picker-accessibility-identifier,c-ui-test-filter-picker-exists
        XCTAssertTrue(waitForCharacterList().exists)

        let picker = waitForFilterPicker()

        XCTAssertTrue(picker.exists)
    }

    func testFilterPickerSegmentCount() throws {
        //harness:criterion=c-homeview-filter-picker-segments-match-cases
        XCTAssertTrue(waitForCharacterList().exists)
        let picker = waitForFilterPicker()

        XCTAssertEqual(picker.buttons.count, 4)
        XCTAssertTrue(picker.buttons["All"].exists)
        XCTAssertTrue(picker.buttons["Alive"].exists)
        XCTAssertTrue(picker.buttons["Dead"].exists)
        XCTAssertTrue(picker.buttons["Unknown"].exists)
    }

    func testAliveSegmentShowsOnlyAliveRows() throws {
        //harness:criterion=c-ui-test-alive-segment-shows-only-alive-rows
        XCTAssertTrue(waitForCharacterList().exists)

        tapFilterSegment("Alive")

        XCTAssertTrue(waitForRow(named: aliveCharacterName).exists)
        XCTAssertTrue(waitForRow(named: secondAliveCharacterName).exists)
        XCTAssertFalse(row(named: deadCharacterName).exists)
        XCTAssertFalse(row(named: unknownCharacterName).exists)
    }

    func testDeadSegmentShowsOnlyDeadRows() throws {
        //harness:criterion=c-homeview-list-reflects-filtered-characters,c-app-configurator-mock-includes-dead-character,c-ui-test-dead-segment-shows-only-dead-rows
        XCTAssertTrue(waitForCharacterList().exists)

        tapFilterSegment("Dead")

        XCTAssertTrue(waitForRow(named: deadCharacterName).exists)
        XCTAssertFalse(row(named: aliveCharacterName).exists)
        XCTAssertFalse(row(named: secondAliveCharacterName).exists)
        XCTAssertFalse(row(named: unknownCharacterName).exists)
    }

    func testUnknownSegmentShowsRows() throws {
        //harness:criterion=c-app-configurator-mock-includes-unknown-character
        XCTAssertTrue(waitForCharacterList().exists)

        tapFilterSegment("Unknown")

        XCTAssertTrue(waitForRow(named: unknownCharacterName).exists)
        XCTAssertFalse(row(named: aliveCharacterName).exists)
        XCTAssertFalse(row(named: deadCharacterName).exists)
    }

    func testFilteredRowNavigatesToCorrectDetail() throws {
        //harness:criterion=c-ui-test-filtered-row-navigates-to-correct-detail
        XCTAssertTrue(waitForCharacterList().exists)
        tapFilterSegment("Dead")

        let deadRow = waitForRow(named: deadCharacterName)
        XCTAssertTrue(deadRow.exists)
        deadRow.tap()

        let detailName = app.staticTexts["detail_character_name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3), "Detay sayfasına geçiş yapılamadı!")
        XCTAssertEqual(detailName.label, deadCharacterName)
    }

    func testExistingAccessibilityIdentifiersPreserved() throws {
        //harness:criterion=c-homeview-existing-identifiers-preserved
        let list = waitForCharacterList()

        XCTAssertTrue(list.exists)
        XCTAssertTrue(waitForRow(named: aliveCharacterName).exists)
    }

    private func waitForCharacterList() -> XCUIElement {
        let list = app.collectionViews["character_list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Karakter listesi yüklenemedi!")
        return list
    }

    private func waitForFilterPicker() -> XCUIElement {
        let segmentedControl = app.segmentedControls["filter_picker"]
        if segmentedControl.waitForExistence(timeout: 5) {
            return segmentedControl
        }

        let otherElement = app.otherElements["filter_picker"]
        XCTAssertTrue(otherElement.waitForExistence(timeout: 5), "Filtre seçici bulunamadı!")
        return otherElement
    }

    private func tapFilterSegment(_ label: String) {
        let picker = waitForFilterPicker()
        let segment = picker.buttons[label]
        XCTAssertTrue(segment.waitForExistence(timeout: 3), "\(label) filtresi bulunamadı!")
        segment.tap()
    }

    private func waitForRow(named name: String) -> XCUIElement {
        let row = row(named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 3), "\(name) satırı bulunamadı!")
        return row
    }

    private func row(named name: String) -> XCUIElement {
        app.buttons["row_\(name)"]
    }
}
