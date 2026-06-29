import SwiftUI

/// 재료 편집 시트 — 상세(영수증)의 edit 아이콘에서 진입. 초안을 고쳐 Save 시 store에 반영.
struct IngredientEditView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Ingredient

    init(ingredient: Ingredient) { _draft = State(initialValue: ingredient) }

    private let storages = ["Fridge", "Freezer", "Pantry", "Room"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $draft.name)
                    TextField("Category", text: $draft.category)
                }
                Section("Details") {
                    TextField("Quantity", text: $draft.amount)
                    TextField("Where", text: $draft.place)
                    Picker("Storage", selection: $draft.storage) {
                        ForEach(storages, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("Days left: \(draft.daysLeft)", value: $draft.daysLeft, in: -5...90)
                }
            }
            .navigationTitle("Edit \(draft.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.update(draft); dismiss() }
                        .tint(ReffiColor.blue)
                }
            }
        }
    }
}
