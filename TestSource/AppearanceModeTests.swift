import SwiftUI
import Testing
@testable import IosCW

@MainActor
struct AppearanceModeTests {
    @Test("Each choice maps to the right colour scheme, and System follows the phone")
    func colourSchemes() {
        #expect(AppearanceMode.system.colorScheme == nil)
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }

    @Test("A saved value is turned back into a choice")
    func savedValues() {
        #expect(AppearanceMode.resolve("light") == .light)
        #expect(AppearanceMode.resolve("dark") == .dark)
        #expect(AppearanceMode.resolve("system") == .system)
    }

    @Test("An unknown or empty saved value falls back to System")
    func unknownValue() {
        #expect(AppearanceMode.resolve("") == .system)
        #expect(AppearanceMode.resolve("purple") == .system)
    }

    @Test("Every choice has a name and a stable saved value")
    func names() {
        #expect(AppearanceMode.allCases.map(\.title) == ["System", "Light", "Dark"])
        #expect(AppearanceMode.allCases.map(\.rawValue) == ["system", "light", "dark"])
    }
}
