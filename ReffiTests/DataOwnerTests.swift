import Testing
import Foundation
@testable import Reffi

@MainActor
struct DataOwnerTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func switchPreservesBothFridgesAndGuest() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let egg = Ingredient(name: "Egg", category: "Other", expiresAt: Ingredient.day(offset: 3))
        let store = FridgeStore(ingredients: [egg], persistenceURL: dir.appendingPathComponent("fridge-guest.json"))
        try store.switchAccount(to: "a", inheritGuest: true, directory: dir)
        #expect(store.ingredients.map(\.id) == [egg.id])
        try store.switchAccount(to: "b", inheritGuest: false, directory: dir)
        #expect(store.ingredients.isEmpty)
        let milk = Ingredient(name: "Milk", category: "Dairy", expiresAt: Ingredient.day(offset: 2))
        var snap = store.snapshot
        snap.ingredients = [milk]
        store.restore(snap)
        try store.switchAccount(to: "a", inheritGuest: false, directory: dir)
        #expect(store.ingredients.map(\.id) == [egg.id])
        try store.switchAccount(to: "b", inheritGuest: false, directory: dir)
        #expect(store.ingredients.map(\.id) == [milk.id])
        try store.switchAccount(to: nil, inheritGuest: false, directory: dir)
        #expect(store.ingredients.isEmpty, "Transferred guest data must not leak after logout")
        try store.switchAccount(to: "a", inheritGuest: false, directory: dir)
        #expect(store.ingredients.map(\.id) == [egg.id])
    }

    @Test func corruptDestinationDoesNotEraseCurrentFridge() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let egg = Ingredient(name: "Egg", category: "Other", expiresAt: Ingredient.day(offset: 3))
        let store = FridgeStore(ingredients: [egg], persistenceURL: dir.appendingPathComponent("fridge-a.json"))
        try Data("broken".utf8).write(to: dir.appendingPathComponent("fridge-b.json"))
        #expect(throws: (any Error).self) {
            try store.switchAccount(to: "b", inheritGuest: false, directory: dir)
        }
        #expect(store.ingredients.map(\.id) == [egg.id])
    }

    @Test func profilePreferencesAreIsolatedAndRestored() {
        let name = "reffi.profile.accounts.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let profile = ProfileStore(defaults: defaults)
        profile.allergies = ["milk"]
        profile.switchAccount(to: "a", inheritGuest: true)
        profile.switchAccount(to: "b", inheritGuest: false)
        #expect(profile.allergies.isEmpty)
        profile.allergies = ["peanut"]
        profile.switchAccount(to: "a", inheritGuest: false)
        #expect(profile.allergies == ["milk"])
        profile.switchAccount(to: "b", inheritGuest: false)
        #expect(profile.allergies == ["peanut"])
    }
}
