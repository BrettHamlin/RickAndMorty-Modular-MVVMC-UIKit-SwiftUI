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

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    private func launchApp(useUITestingFixture: Bool = true, keepHomeLoading: Bool = false) {
        app = XCUIApplication()
        if keepHomeLoading {
            app.launchArguments.append("--uitesting-loading")
        } else if useUITestingFixture {
            app.launchArguments.append("--uitesting")
        }
        app.launch()
    }

    private func waitForCharacterList(file: StaticString = #filePath, line: UInt = #line) {
        let list = app.collectionViews["character_list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Karakter listesi yüklenemedi!", file: file, line: line)
    }

    private var filterPicker: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "filter_picker").firstMatch
    }

    private func selectFilter(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let picker = filterPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Filter picker bulunamadı!", file: file, line: line)

        let segment = picker.buttons[title].firstMatch
        if segment.exists {
            segment.tap()
            return
        }

        let fallbackSegment = app.buttons[title].firstMatch
        XCTAssertTrue(fallbackSegment.waitForExistence(timeout: 2), "\(title) filtresi bulunamadı!", file: file, line: line)
        fallbackSegment.tap()
    }

    private func row(named name: String) -> XCUIElement {
        app.buttons["row_\(name)"].firstMatch
    }

    private func assertRowVisible(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(row(named: name).waitForExistence(timeout: 2), "\(name) row should be visible", file: file, line: line)
    }

    private func assertRowHidden(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(row(named: name).waitForNonExistence(timeout: 2), "\(name) row should be hidden", file: file, line: line)
    }
    
    func testUserCanScrollAndOpenDetailWithoutCrash() throws {
        launchApp()
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

    //harness:criterion=c-homeview-picker-present-in-success-branch,c-homeview-picker-accessibility-identifier
    func testFilterPickerIsVisibleInSuccessState() throws {
        launchApp()
        waitForCharacterList()

        XCTAssertTrue(filterPicker.exists)
        XCTAssertGreaterThanOrEqual(
            app.descendants(matching: .any).matching(identifier: "filter_picker").count,
            1
        )
    }

    //harness:criterion=c-homeview-picker-not-shown-outside-success
    func testFilterPickerIsNotVisibleBeforeSuccessState() throws {
        launchApp(keepHomeLoading: true)
        XCTAssertTrue(app.otherElements["loading_indicator"].waitForExistence(timeout: 5))

        XCTAssertFalse(filterPicker.exists)
    }

    //harness:criterion=c-uitest-all-segment-shows-all-characters
    func testAllFilterShowsCharactersForEveryStatus() throws {
        launchApp()
        waitForCharacterList()

        selectFilter("Alive")
        assertRowHidden(named: "Birdperson")

        selectFilter("All")

        assertRowVisible(named: "Rick Sanchez")
        assertRowVisible(named: "Birdperson")
        assertRowVisible(named: "Dr. Wong")
    }

    //harness:criterion=c-uitest-alive-segment-shows-alive-hides-others
    func testAliveFilterShowsAliveAndHidesDeadCharacters() throws {
        launchApp()
        waitForCharacterList()
        selectFilter("All")
        assertRowVisible(named: "Birdperson")

        selectFilter("Alive")

        assertRowVisible(named: "Rick Sanchez")
        assertRowHidden(named: "Birdperson")
    }

    //harness:criterion=c-appconfigurator-includes-dead-character,c-uitest-dead-segment-shows-dead-hides-others
    func testDeadFilterShowsDeadAndHidesAliveCharacters() throws {
        launchApp()
        waitForCharacterList()
        selectFilter("All")
        assertRowVisible(named: "Rick Sanchez")

        selectFilter("Dead")

        assertRowVisible(named: "Birdperson")
        assertRowHidden(named: "Rick Sanchez")
    }

    //harness:criterion=c-appconfigurator-includes-unknown-character,c-uitest-unknown-segment-shows-unknown-hides-others
    func testUnknownFilterShowsUnknownAndHidesAliveCharacters() throws {
        launchApp()
        waitForCharacterList()
        selectFilter("All")
        assertRowVisible(named: "Rick Sanchez")

        selectFilter("Unknown")

        assertRowVisible(named: "Dr. Wong")
        assertRowHidden(named: "Rick Sanchez")
    }

    //harness:criterion=c-uitest-detail-navigation-preserved
    func testFilteredCharacterStillNavigatesToDetail() throws {
        launchApp()
        waitForCharacterList()

        selectFilter("Alive")
        let targetRow = row(named: "Rick Sanchez")
        XCTAssertTrue(targetRow.waitForExistence(timeout: 2))
        targetRow.tap()

        let detailName = app.staticTexts["detail_character_name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3), "Detay sayfasına geçiş yapılamadı!")
        XCTAssertEqual(detailName.label, "Rick Sanchez")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
