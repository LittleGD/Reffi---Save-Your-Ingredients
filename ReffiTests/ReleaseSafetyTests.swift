import Testing
import Foundation
@testable import Reffi

struct ReleaseSafetyTests {
    @Test func expiredMilkCannotBeRevivedByFreezing() {
        let now = Ingredient.day(offset: 0)
        var milk = Ingredient(name: "Milk", category: "Dairy", expiresAt: Ingredient.day(offset: -1, from: now))
        milk.canonicalID = "milk"
        #expect(!milk.canFreeze(asOf: now))
        milk.storage = .freezer
        milk.frozenAt = now
        #expect(milk.effectiveDaysLeft(asOf: now) == -1)
    }

    @Test func sameDayFreezingRemainsAvailable() {
        let now = Date()
        var milk = Ingredient(name: "Milk", category: "Dairy", expiresAt: now)
        milk.canonicalID = "milk"
        #expect(milk.canFreeze(asOf: now))
        milk.storage = .freezer
        milk.frozenAt = now
        #expect(milk.effectiveDaysLeft(asOf: now) == Ingredient.freezerGraceDays)
    }

    @Test func soyAllergyCannotBeBypassedWithMilkSubstitution() throws {
        let recipe = try #require(RecipeCatalog.loadSeed().first { $0.id == "lasagna-style-bake" })
        let ids = Set(recipe.ingredients.compactMap(\.ref)).subtracting(["milk"]).union(["soy-milk"])
        let stock = ids.map { id in
            var item = Ingredient(name: id, category: "Other", expiresAt: Ingredient.day(offset: 3))
            item.canonicalID = id
            return item
        }
        var preferences = RecipePreferences.none
        preferences.allergenIDs = ["soybean"]
        let unrestricted = RecipeRecommender.result(for: recipe, ingredients: stock)
        #expect(unrestricted.substituted.contains { $0.with.canonicalID == "soy-milk" })
        let results = RecipeRecommender.rank(for: stock, from: [recipe], preferences: preferences)
        #expect(results.allSatisfy { !$0.used.contains { $0.canonicalID == "soy-milk" } })
        let detail = RecipeRecommender.result(for: recipe, ingredients: stock, preferences: preferences)
        #expect(detail.missing.contains { $0.ref == "milk" })
    }

    @Test func expiredInventoryDoesNotFillMissingLines() throws {
        let recipe = try #require(RecipeCatalog.loadSeed().first { $0.id == "egg-fried-rice" })
        var egg = Ingredient(name: "Egg", category: "Other", expiresAt: Ingredient.day(offset: -1))
        egg.canonicalID = "egg"
        #expect(RecipeRecommender.rank(for: [egg], from: [recipe]).isEmpty)
        #expect(RecipeRecommender.result(for: recipe, ingredients: [], inventory: [egg]).missing.contains { $0.ref == "egg" })
    }

    @Test @MainActor func staleTicketCannotReserveExpiredStock() throws {
        let recipe = try #require(RecipeCatalog.loadSeed().first { $0.id == "egg-fried-rice" })
        var egg = Ingredient(name: "Egg", category: "Other", expiresAt: Ingredient.day(offset: 1))
        egg.canonicalID = "egg"
        let result = RecipeRecommender.result(for: recipe, ingredients: [egg])
        egg.expiresAt = Ingredient.day(offset: -1)
        let store = FridgeStore(ingredients: [egg])
        #expect(!store.cook(result))
        #expect(store.activeCook == nil)
        #expect(store.ingredients.count == 1)
    }

    @Test func descriptiveStockAndUnknownIngredientsRespectRestrictions() throws {
        let recipe = try #require(RecipeCatalog.loadSeed().first { $0.id == "doenjang-jjigae" })
        var tofu = Ingredient(name: "Tofu", category: "Other", expiresAt: Ingredient.day(offset: 3))
        tofu.canonicalID = "tofu"
        var preferences = RecipePreferences.none
        preferences.allergenIDs = ["anchovy"]
        #expect(RecipeRecommender.rank(for: [tofu], from: [recipe], preferences: preferences).isEmpty)
        preferences.allergenIDs = []
        preferences.vegetarian = true
        #expect(RecipeRecommender.rank(for: [tofu], from: [recipe], preferences: preferences).isEmpty)
    }
}
