import XCTest
import SwiftUI
@testable import LinkAJADemo

final class PersonaDesignTests: XCTestCase {
    private let b = PersonaTheme.budi
    private let s = PersonaTheme.siti

    func testThemesDifferOnEveryMainToken() {
        XCTAssertNotEqual(b.headerStartHex, s.headerStartHex, "header gradient start")
        XCTAssertNotEqual(b.headerEndHex, s.headerEndHex, "header gradient end")
        XCTAssertNotEqual(b.backgroundHex, s.backgroundHex, "background")
        XCTAssertNotEqual(b.accentHex, s.accentHex, "accent")
        XCTAssertNotEqual(b.secondaryHex, s.secondaryHex, "secondary")
        XCTAssertNotEqual(b.radius, s.radius, "radius")
        XCTAssertNotEqual(b.fontDesign, s.fontDesign, "font design")
        XCTAssertNotEqual(b.tabs, s.tabs, "tab set")
        XCTAssertNotEqual(b.homeModules, s.homeModules, "home module order")
    }

    func testSpecValues() {
        XCTAssertEqual(b.headerStartHex, "#12294D"); XCTAssertEqual(b.headerEndHex, "#2F4B7C")
        XCTAssertEqual(s.headerStartHex, "#0E9F8E"); XCTAssertEqual(s.headerEndHex, "#6C4BD6")
        XCTAssertEqual(b.radius, 12); XCTAssertEqual(s.radius, 24)
        XCTAssertEqual(b.tabs, [.home, .bills, .scan, .inbox, .profile])
        XCTAssertEqual(s.tabs, [.home, .promo, .scan, .shop, .profile])
        XCTAssertEqual(b.ctaHex, PersonaTheme.brandRed); XCTAssertEqual(s.ctaHex, PersonaTheme.brandRed)
    }

    func testHomeModuleListsAreSeparate() {
        XCTAssertTrue(b.homeModules.contains(.dueBill) && !s.homeModules.contains(.dueBill))
        XCTAssertTrue(s.homeModules.contains(.sales) && !b.homeModules.contains(.sales))
        XCTAssertEqual(b.homeModules.first, .header)
        XCTAssertEqual(s.homeModules.first, .header)
    }

    func testAtLeast25Of30ResolvedVariablesDiffer() {
        let rows = PersonaDiff.variableRows()
        XCTAssertEqual(rows.count, 30)
        let differing = rows.filter(\.differs).count
        XCTAssertGreaterThanOrEqual(differing, 25, "only \(differing) of \(rows.count) differ")
    }

    func testDashboardOverrideStillWinsOverPersona() {
        // A persona value is replaced when the live store value differs from the variable default.
        let key = PEKeys.heroTitle
        PEStore.shared.setOverride(key, "Dashboard title")
        defer { PEStore.shared.clearLocalChanges() }
        XCTAssertEqual(PEResolver.shared.display(key, for: PersonaRegistry.budi), "Dashboard title")
        XCTAssertEqual(PEResolver.shared.display(key, for: PersonaRegistry.siti), "Dashboard title")
    }

    func testStartingPoints() {
        XCTAssertEqual(PersonaRegistry.budi.startingPoints, 1_250)
        XCTAssertEqual(PersonaRegistry.siti.startingPoints, 400)
    }
}
