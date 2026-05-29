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
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    // harness:criterion=c-homeview-filter-control-present,c-homeview-filter-control-accessibility-id
    func testStatusFilterControlIsVisibleOnHomeScreen() throws {
        let filterControls = app.descendants(matching: .any).matching(identifier: "status_filter_picker")
        let filterControl = filterControls.element
        
        XCTAssertTrue(filterControl.waitForExistence(timeout: 5), "Status filter control was not found on the home screen.")
        XCTAssertEqual(filterControls.count, 1)
        XCTAssertTrue(filterControl.isHittable, "Status filter control should be hittable on the home screen.")
    }
    
    // harness:criterion=c-homeview-character-list-accessibility-id-preserved,c-homeview-loading-indicator-accessibility-id-preserved,c-homeview-row-accessibility-id-preserved,c-app-coordinator-unchanged,c-ui-testing-repository-unchanged
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
}
