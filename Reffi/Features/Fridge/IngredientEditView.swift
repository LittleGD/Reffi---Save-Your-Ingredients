import SwiftUI

/// 재료 편집 시트 — 상세(영수증)의 edit 아이콘에서 진입. 초안을 고쳐 Save 시 store에 반영.
/// 소비기한·구매일은 날짜로 편집(시간 모델이 절대 날짜라 하루가 지나면 D-N도 함께 흐른다).
/// 이름이 바뀌면 글리프·카테고리는 store가 다시 매칭한다.
/// **삭제**는 이력 없는 제거 — 오입력·중복이 낭비율·쇼핑리스트를 오염시키지 않는 정정 경로.
struct IngredientEditView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Ingredient
    @State private var showDeleteConfirm = false

    init(ingredient: Ingredient) { _draft = State(initialValue: ingredient) }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $draft.name)
                }
                Section("Details") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", value: $draft.quantity.value, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                        Picker("Unit", selection: $draft.quantity.unit) {
                            ForEach(IngredientUnit.allCases) { u in
                                Text(verbatim: u.label).tag(u)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    TextField("Where", text: $draft.place)
                    Picker("Storage", selection: $draft.storage) {
                        // 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
                        // 재냉동 금지: 이미 한 번 얼렸던 재료는 Freezer 재선택 불가.
                        ForEach(StorageLocation.allCases) { s in
                            if s != .freezer || draft.storage == .freezer || draft.frozenAt == nil {
                                Text(LocalizedStringKey(s.rawValue)).tag(s)
                            }
                        }
                    }
                    DatePicker("Use by", selection: $draft.expiresAt,
                               in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                               displayedComponents: .date)
                    DatePicker("Purchased", selection: $draft.purchasedAt,
                               in: ...Date(),
                               displayedComponents: .date)
                }
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label { Text("Delete ingredient") } icon: { ReffiIcon.delete.reffi(15) }
                    }
                } footer: {
                    Text("Removes it without history — stats and the shopping list won't count it.")
                }
            }
            .navigationTitle(Text("Edit \(draft.name)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.name = trimmedName
                        // 폼에서 냉동으로 옮겼다면 전환 시점을 기록(유예 시계 시작 + 재냉동 방지).
                        if draft.storage == .freezer, draft.frozenAt == nil {
                            draft.frozenAt = Date()
                        }
                        store.update(draft)
                        dismiss()
                    }
                    .tint(ReffiColor.blue)
                    .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog(Text("Delete this ingredient?"), isPresented: $showDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.remove(draft)
                    dismiss()
                }
            } message: {
                Text("Removes it without history — stats and the shopping list won't count it.")
            }
        }
    }
}
