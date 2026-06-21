import SwiftUI

/// 재료 정보 편집 — 펜슬 버튼에서 진입. @Bindable로 모델에 직접 바인딩(SwiftData 자동 저장).
struct IngredientEditView: View {
    @Bindable var ingredient: Ingredient
    @Environment(\.dismiss) private var dismiss

    private var categoryBinding: Binding<IngredientCategory> {
        Binding(
            get: { IngredientCategory(raw: ingredient.category) },
            set: { ingredient.category = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s4) {
                    field("Name") {
                        TextField("Name", text: $ingredient.name)
                    }
                    categoryField
                    dateField("Purchased", $ingredient.addedDate)
                    dateField("Expires", $ingredient.expiryDate)
                    field("Where") {
                        TextField("Store", text: $ingredient.purchasePlace)
                    }
                    field("Quantity") {
                        TextField("e.g. 300 g", text: $ingredient.quantity)
                    }
                    field("Storage") {
                        TextField("Fridge", text: $ingredient.storage)
                    }
                }
                .padding(Space.s4)
            }
            .background(ReffiColor.canvas)
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label)
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)
            content()
                .reffiText(ReffiType.body)
                .foregroundStyle(ReffiColor.ink)
                .padding(Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReffiColor.neutral200, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Category")
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)
            Picker("Category", selection: categoryBinding) {
                ForEach(IngredientCategory.allCases, id: \.self) { c in
                    Text(c.label).tag(c)
                }
            }
            .pickerStyle(.menu)
            .tint(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2)
            .background(ReffiColor.neutral200, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private func dateField(_ label: String, _ binding: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label)
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)
            DatePicker("", selection: binding, displayedComponents: .date)
                .labelsHidden()
                .padding(Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReffiColor.neutral200, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }
}
