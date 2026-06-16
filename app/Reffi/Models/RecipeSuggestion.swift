import Foundation

/// AI recipe suggestion derived from the real fridge (`Ingredient`).
struct RecipeSuggestion: Identifiable, Hashable {
    // Deterministic id (title is unique in the catalog) so recomputed suggestions
    // compare equal across re-renders — avoids spurious deck resets.
    var id: String { title }
    let title: String
    let category: FoodCategory
    let usedIngredients: [String]   // owned ingredients this recipe uses
    let pantry: [String]             // pantry/seasoning staples (salt, pepper, oil…)
    let needsShopping: Bool          // any required item missing
    let minutes: Int
    let imageAssetName: String?      // card image (Blue fallback if nil)
    let rationale: String            // one-line "why now"
    let topFreshness: Freshness      // color of the rationale chip

    /// "Tofu·Spinach — no shopping · 12 min"
    var subtitle: String {
        let used = usedIngredients.joined(separator: "·")
        let shop = needsShopping ? "buy a few" : "no shopping"
        return "\(used) — \(shop) · \(minutes) min"
    }
}

extension RecipeSuggestion {
    private struct CatalogEntry {
        let title: String
        let category: FoodCategory
        let requires: [String]
        let pantry: [String]   // 양념·기본 재료 (냉장고에 안 잡혀도 항상 표시)
        let minutes: Int
        let image: String?
    }

    private static let catalog: [CatalogEntry] = [
        CatalogEntry(title: "Tofu & Spinach Stew",     category: .korean,  requires: ["Tofu", "Spinach"],                    pantry: ["Salt", "Soy sauce", "Sesame oil", "Garlic"], minutes: 12, image: "recipe_tofu_egg"),
        CatalogEntry(title: "Chicken Veggie Stir-fry", category: .asian,   requires: ["Chicken breast", "Carrot", "Spinach"], pantry: ["Salt", "Pepper", "Soy sauce", "Cooking oil"], minutes: 15, image: "recipe_chicken_veg"),
        CatalogEntry(title: "Potato Milk Soup",        category: .western, requires: ["Potato", "Milk"],                     pantry: ["Salt", "Pepper", "Butter"],                  minutes: 20, image: "recipe_potato_soup"),
        CatalogEntry(title: "Carrot Apple Slaw",       category: .vegan,   requires: ["Carrot", "Apple"],                    pantry: ["Salt", "Lemon juice", "Olive oil"],          minutes: 10, image: "recipe_carrot_slaw"),
        CatalogEntry(title: "Spinach Tofu Salad",      category: .vegan,   requires: ["Spinach", "Tofu"],                    pantry: ["Salt", "Pepper", "Olive oil"],               minutes: 8,  image: "recipe_spinach_salad"),
        CatalogEntry(title: "Chicken Potato Bake",     category: .western, requires: ["Chicken breast", "Potato"],           pantry: ["Salt", "Pepper", "Olive oil", "Rosemary"],   minutes: 30, image: "recipe_chicken_bake"),
    ]

    /// Recommend from the fridge, optionally filtered by category, sorted most-urgent first.
    static func recommend(from ingredients: [Ingredient], category: FoodCategory = .all) -> [RecipeSuggestion] {
        let byName = Dictionary(grouping: ingredients, by: { $0.name })

        var scored: [(suggestion: RecipeSuggestion, daysLeft: Int)] = []
        for entry in catalog {
            if category != .all, entry.category != category { continue }

            let owned = entry.requires.filter { byName[$0] != nil }
            guard !owned.isEmpty else { continue }

            let ownedItems = owned.compactMap { byName[$0]?.min(by: { $0.daysLeft < $1.daysLeft }) }
            guard let top = ownedItems.min(by: { $0.daysLeft < $1.daysLeft }) else { continue }

            let missing = entry.requires.contains { byName[$0] == nil }
            let suggestion = RecipeSuggestion(
                title: entry.title,
                category: entry.category,
                usedIngredients: owned,
                pantry: entry.pantry,
                needsShopping: missing,
                minutes: entry.minutes,
                imageAssetName: entry.image,
                rationale: rationaleLine(for: top),
                topFreshness: top.freshness
            )
            scored.append((suggestion, top.daysLeft))
        }
        return scored.sorted { $0.daysLeft < $1.daysLeft }.map(\.suggestion)
    }

    private static func rationaleLine(for ing: Ingredient) -> String {
        let days = ing.daysLeft
        switch ing.freshness {
        case .urgent:
            return days < 0 ? "\(ing.name) is overdue — cook now" : "\(ing.name) is due today — cook now"
        case .soon:
            return "\(ing.name) in \(days)d — use it soon"
        case .fresh:
            return "\(ing.name) — plenty of time"
        }
    }
}
