import SwiftUI

/// 내 레시피 — 사용자 커스텀 레시피 목록·추가·편집·삭제. 저장하면 즉시 추천 풀에 합류한다
/// (커스텀이 시드보다 우선). 시드 레시피는 여기 나오지 않는다(편집 불가 데이터).
struct MyRecipesView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Recipe?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                if store.userRecipes.isEmpty {
                    Text("Recipes you add appear in the ticket deck alongside the built-in ones.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                ForEach(store.userRecipes) { recipe in
                    Button { editing = recipe } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: recipe.displayName)
                                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                            Text(verbatim: recipe.ingredients.map(\.displayName).joined(separator: ", "))
                                .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { store.deleteUserRecipe(id: store.userRecipes[i].id) }
                }
            }
            .navigationTitle(Text("My recipes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { creating = true } label: { ReffiIcon.add.reffi(16, .bold) }
                        .accessibilityLabel(Text("Add recipe"))
                }
            }
            .sheet(isPresented: $creating) { RecipeEditorView(recipe: nil) }
            .sheet(item: $editing) { RecipeEditorView(recipe: $0) }
        }
    }
}

/// 커스텀 레시피 편집기 — 이름·재료(쉼표 구분)·단계(줄바꿈 구분)·시간.
/// 재료는 저장 시 정본 사전으로 canonical 매칭돼 추천·발주에 정확히 물린다.
struct RecipeEditorView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe?   // nil = 새로 만들기

    @State private var name = ""
    @State private var ingredientsText = ""
    @State private var stepsText = ""
    @State private var minutes = 20

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedIngredients: [String] {
        ingredientsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    private var parsedSteps: [String] {
        stepsText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Recipe name", text: $name)
                    Stepper(value: $minutes, in: 5...240, step: 5) {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text("\(minutes) min").foregroundStyle(ReffiColor.ink2)
                        }
                    }
                }
                Section("Ingredients (comma separated)") {
                    TextField("Onion, Egg, Rice…", text: $ingredientsText, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Steps (one per line)") {
                    TextField("Chop, stir-fry, season…", text: $stepsText, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(recipe == nil ? Text("Add recipe") : Text("Edit recipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .tint(ReffiColor.blue)
                        .disabled(trimmedName.isEmpty || parsedIngredients.isEmpty)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let r = recipe, name.isEmpty else { return }
        name = r.displayName
        ingredientsText = r.ingredients.map(\.displayName).joined(separator: ", ")
        stepsText = r.displaySteps.joined(separator: "\n")
        minutes = r.minutes
    }

    private func save() {
        var new = Recipe.userRecipe(name: trimmedName, ingredientNames: parsedIngredients,
                                    minutes: minutes, steps: parsedSteps)
        if let existing = recipe {
            new.id = existing.id
            store.updateUserRecipe(new)
        } else {
            store.addUserRecipe(new)
        }
        dismiss()
    }
}
