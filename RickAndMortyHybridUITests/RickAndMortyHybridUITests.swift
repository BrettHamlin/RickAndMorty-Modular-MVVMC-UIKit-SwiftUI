//
//  RickAndMortyHybridUITests.swift
//  RickAndMortyHybridUITests
//
//  Created by rico on 22.01.2026.
//

import XCTest

final class FeatureHomeUITests: XCTestCase {

    var app: XCUIApplication!

    private let filterPickerIdentifier = "status_filter_picker"
    private let allFilterIdentifier = "status_filter_all"
    private let aliveFilterIdentifier = "status_filter_alive"
    private let deadFilterIdentifier = "status_filter_dead"
    private let unknownFilterIdentifier = "status_filter_unknown"
    private let fixtureRows = [
        "row_Rick Sanchez",
        "row_Morty Smith",
        "row_Adjudicator Rick",
        "row_Alien Googah"
    ]
    private let aliveRows = ["row_Rick Sanchez", "row_Morty Smith"]
    private let deadRows = ["row_Adjudicator Rick"]
    private let unknownRows = ["row_Alien Googah"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }

    //harness:criterion=c-existing-scroll-test-preserved,c-existing-detail-routing-test-preserved,c-existing-accessibility-ids-preserved
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

    //harness:criterion=c-segmented-control-present,c-filter-control-accessibility-id,c-filter-segments-accessibility-ids
    func testStatusFilterPickerAndAllSegmentsAreAccessibleAboveCharacterList() throws {
        let list = waitForCharacterList()
        let picker = app.segmentedControls[filterPickerIdentifier]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Status filter picker was not exposed as a segmented control.")
        XCTAssertTrue(picker.isHittable, "Status filter picker should be tappable on the home screen.")
        XCTAssertLessThanOrEqual(picker.frame.maxY, list.frame.minY, "Status filter should render above the character list.")

        let segmentIdentifiers = [
            allFilterIdentifier,
            aliveFilterIdentifier,
            deadFilterIdentifier,
            unknownFilterIdentifier
        ]
        XCTAssertEqual(Set(segmentIdentifiers).count, 4)

        for identifier in segmentIdentifiers {
            let segment = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(segment.exists, "Missing filter segment \(identifier).")
            XCTAssertTrue(segment.isHittable, "Filter segment \(identifier) should be tappable.")
        }
    }

    //harness:criterion=c-ui-test-all-filter-shows-all-rows
    func testAllStatusFilterShowsAllFixtureRows() {
        _ = waitForCharacterList()

        tapFilterSegment(allFilterIdentifier)

        XCTAssertEqual(waitForRowIdentifiers(count: fixtureRows.count), fixtureRows)
        assertRows(fixtureRows, exist: true)
    }

    //harness:criterion=c-uitesting-repo-alive-fixture,c-ui-test-alive-filter-hides-non-alive
    func testAliveStatusFilterShowsOnlyAliveFixtureRows() {
        _ = waitForCharacterList()

        tapFilterSegment(aliveFilterIdentifier)

        XCTAssertEqual(waitForRowIdentifiers(count: aliveRows.count), aliveRows)
        assertRows(aliveRows, exist: true)
        assertRows(deadRows + unknownRows, exist: false)
    }

    //harness:criterion=c-uitesting-repo-dead-fixture,c-ui-test-dead-filter-hides-non-dead
    func testDeadStatusFilterShowsOnlyDeadFixtureRows() {
        _ = waitForCharacterList()

        tapFilterSegment(deadFilterIdentifier)

        XCTAssertEqual(waitForRowIdentifiers(count: deadRows.count), deadRows)
        assertRows(deadRows, exist: true)
        assertRows(aliveRows + unknownRows, exist: false)
    }

    //harness:criterion=c-uitesting-repo-unknown-fixture,c-ui-test-unknown-filter-hides-non-unknown
    func testUnknownStatusFilterShowsOnlyUnknownFixtureRows() {
        _ = waitForCharacterList()

        tapFilterSegment(unknownFilterIdentifier)

        XCTAssertEqual(waitForRowIdentifiers(count: unknownRows.count), unknownRows)
        assertRows(unknownRows, exist: true)
        assertRows(aliveRows + deadRows, exist: false)
    }

    //harness:criterion=c-ui-test-detail-nav-filtered-list
    func testTappingRowWhileFilteredNavigatesToThatCharacterDetail() {
        _ = waitForCharacterList()

        tapFilterSegment(aliveFilterIdentifier)
        XCTAssertEqual(waitForRowIdentifiers(count: aliveRows.count), aliveRows)

        app.buttons["row_Rick Sanchez"].tap()

        let detailName = app.staticTexts["detail_character_name"]
        XCTAssertTrue(detailName.waitForExistence(timeout: 3), "Detail screen did not appear after tapping a filtered row.")
        XCTAssertEqual(detailName.label, "Rick Sanchez")
    }

    private func waitForCharacterList() -> XCUIElement {
        let list = app.collectionViews["character_list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Character list did not load.")
        return list
    }

    private func tapFilterSegment(_ identifier: String) {
        let segment = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "Filter segment \(identifier) did not exist.")
        segment.tap()
    }

    private func rowButtons() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "row_"))
    }

    private func waitForRowIdentifiers(count expectedCount: Int, timeout: TimeInterval = 3) -> [String] {
        let deadline = Date().addingTimeInterval(timeout)
        var identifiers: [String] = []

        repeat {
            identifiers = rowButtons().allElementsBoundByIndex.map(\.identifier)
            if identifiers.count == expectedCount {
                return identifiers
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline

        return identifiers
    }

    private func assertRows(_ rows: [String], exist expectedExistence: Bool) {
        for row in rows {
            XCTAssertEqual(app.buttons[row].exists, expectedExistence, "Unexpected existence for \(row).")
        }
    }
}
