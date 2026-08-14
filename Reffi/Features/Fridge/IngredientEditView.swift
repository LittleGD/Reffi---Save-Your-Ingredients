import SwiftUI

/// 재료 편집 시트 — 상세(영수증)의 edit 아이콘에서 진입. 초안을 고쳐 Save 시 store에 반영.
/// 소비기한·구매일은 날짜로 편집(시간 모델이 절대 날짜라 하루가 지나면 D-N도 함께 흐른다).
/// 이름이 바뀌면 글리프·카테고리는 store가 다시 매칭한다.
/// **삭제**는 이력 없는 제거 — 오입력·중복이 낭비율·쇼핑리스트를 오염시키지 않는 정정 경로.
///
/// 표면은 §13 행동표면 언어(`CandidateEditSheet`와 같은 문법):
/// 크림 캔버스(`--color-canvas`) + 흰 영수증 카드(`ReceiptShape`) + 모노 섹션 라벨(`ITEM`·`DETAILS`) +
/// `DashedRule` + 종이 X 닫기 헤더 + 도킹된 `PaperButton`. 시스템 폼·글래스 툴바를 쓰지 않는다(조용한 종이).
struct IngredientEditView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// 이 시트에서 열릴 수 있는 종이 드롭다운 — 한 번에 하나만 연다(`DropdownAnchorKey` 전제).
    private enum OpenDropdown { case unit, storage }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft: Ingredient
    @State private var showDeleteConfirm = false
    @State private var showDiscardConfirm = false
    @State private var deleteHaptic = 0
    @State private var openDropdown: OpenDropdown?

    private let original: Ingredient

    init(ingredient: Ingredient) {
        original = ingredient
        _draft = State(initialValue: ingredient)
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 초안이 원본과 다르면(룰⑨) 스와이프/닫기 시 Discard 확인을 띄운다.
    private var isDirty: Bool { draft != original }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: ReffiSpace.s3) {
                    itemCard
                    detailsCard
                    deleteSection
                }
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.top, ReffiSpace.s2)
                .padding(.bottom, ReffiSpace.s3)
            }
            .scrollDismissesKeyboard(.interactively)
            actionBar
        }
        .background(ReffiColor.canvas)
        // 종이 드롭다운 오버레이 2종 — 열린 트리거만 앵커를 올리므로 동시에 하나만 뜬다.
        .paperDropdownOverlay(isPresented: openDropdown == .unit,
                              options: IngredientUnit.allCases,
                              selected: draft.quantity.unit,
                              label: { $0.label }, seed: 5,
                              onDismiss: { closeDropdown() },
                              onSelect: { draft.quantity.unit = $0 })
        .paperDropdownOverlay(isPresented: openDropdown == .storage,
                              options: storageOptions,
                              selected: draft.storage,
                              label: { $0.label }, seed: 3,
                              onDismiss: { closeDropdown() },
                              onSelect: { draft.storage = $0 })
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .interactiveDismissDisabled(isDirty)
        .sensoryFeedback(.warning, trigger: deleteHaptic)
        .confirmationDialog(Text("Delete this ingredient?"), isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.remove(draft)
                deleteHaptic += 1
                dismiss()
            }
        } message: {
            Text("Removes it without history. Stats and the shopping list won't count it.")
        }
        .confirmationDialog(Text("Discard changes?"), isPresented: $showDiscardConfirm,
                            titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your changes won't be saved.")
        }
    }

    // MARK: - 헤더 (§14.2 단일 공급원 `SheetHeader` — 룰②③)

    /// 커스텀 HStack을 남겼던 사유("동적 타이틀 truncation 보호")는 `SheetHeader`가 한 줄·말줄임을
    /// 컴포넌트로 흡수하며 사라졌다. 인라인으로 두면 패딩이 달라(위 s4/아래 s2 vs 컴포넌트 s5/s3)
    /// 이 시트와 `CandidateEditSheet`를 연달아 열 때 타이틀 기준선이 서로 다른 높이에 앉는다.
    private var header: some View {
        SheetHeader(title: "Edit \(draft.name)", showsClose: true) { requestClose() }
    }

    // MARK: - 종이 드롭다운 (단위·보관)

    /// 재냉동 금지 — 이미 한 번 얼렸던 재료는 Freezer를 다시 고를 수 없다(§13.6 유예 1회 제한).
    private var storageOptions: [StorageLocation] {
        StorageLocation.allCases.filter {
            $0 != .freezer || draft.storage == .freezer || draft.frozenAt == nil
        }
    }

    private func toggle(_ which: OpenDropdown) {
        let opening = openDropdown != which
        withAnimation(ReffiMotion.gated(opening ? ReffiMotion.pop : ReffiMotion.exit,
                                        reduce: reduceMotion)) {
            openDropdown = opening ? which : nil
        }
    }

    private func closeDropdown() {
        withAnimation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion)) { openDropdown = nil }
    }

    /// 미저장 변경이 있으면 즉시 닫지 않고 Discard 확인을 띄운다(룰⑨).
    private func requestClose() {
        if isDirty {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    // MARK: - ITEM 카드 (이름)

    private var itemCard: some View {
        receiptCard {
            sectionLabel("ITEM")
            TextField("Name", text: $draft.name,
                      prompt: Text("Name").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body).foregroundStyle(ReffiColor.ink)
                .frame(minHeight: 40)
        }
    }

    // MARK: - DETAILS 카드 (수량·구매처·보관·소비기한·구매일)

    private var detailsCard: some View {
        receiptCard {
            sectionLabel("DETAILS")

            HStack {
                Text("Quantity").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                TextField("1", value: $draft.quantity.value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.reffiNum(16, relativeTo: .body))
                    .foregroundStyle(ReffiColor.ink)
                    .frame(width: 64)
                // 스톡 `.pickerStyle(.menu)`(흰 시스템 팝업) 대신 앱 커스텀 종이 드롭다운 —
                // "탭 → 옵션 목록"이 앱 전체에서 한 문법이어야 한다(커먼 룰 H).
                PaperDropdownTrigger(label: draft.quantity.unit.label,
                                     isOpen: openDropdown == .unit, seed: 5) { toggle(.unit) }
                    .accessibilityLabel(Text("Unit"))
                    .accessibilityValue(Text(verbatim: draft.quantity.unit.label))
            }
            .frame(minHeight: 40)

            DashedRule()

            HStack {
                Text("Where").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer(minLength: ReffiSpace.s4)
                TextField("Add place", text: $draft.place,
                          prompt: Text("Add place").foregroundStyle(ReffiColor.ink2))
                    .multilineTextAlignment(.trailing)
                    .reffiType(.body).foregroundStyle(ReffiColor.ink)
            }
            .frame(minHeight: 40)

            DashedRule()

            HStack {
                Text("Storage").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                // 저장값은 영문 식별자 그대로, 표시만 로컬라이즈(`StorageLocation.label`).
                PaperDropdownTrigger(label: draft.storage.label,
                                     isOpen: openDropdown == .storage, seed: 3) { toggle(.storage) }
                    .accessibilityLabel(Text("Storage"))
                    .accessibilityValue(Text(verbatim: draft.storage.label))
            }
            .frame(minHeight: 40)

            DashedRule()

            HStack {
                Text("Use by").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                DatePicker("", selection: $draft.expiresAt,
                           in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(ReffiColor.blue)
            }
            .frame(minHeight: 40)

            DashedRule()

            HStack {
                Text("Purchased").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                DatePicker("", selection: $draft.purchasedAt,
                           in: ...Date(),
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(ReffiColor.blue)
            }
            .frame(minHeight: 40)
        }
    }

    // MARK: - 삭제 (이력 없는 정정 경로 — Save보다 조용한 면)

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Button { showDeleteConfirm = true } label: {
                HStack(spacing: ReffiSpace.s2) {
                    ReffiIcon.delete.reffi(15, .bold).foregroundStyle(ReffiColor.urgentDark)
                    Text("Delete ingredient")
                        .reffiType(.body).foregroundStyle(ReffiColor.urgentDark)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, ReffiSpace.s5)
                .frame(minHeight: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background {
                    // 조용한 종이 면 + urgent 틴트 헤어라인(보더 아님) — 그림자 없이 Save보다 잔잔하게.
                    let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 9)
                    s.fill(ReffiColor.paper).paperEdge(s, tint: ReffiColor.urgentDark.opacity(0.18))
                }
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Delete ingredient")

            Text("Removes it without history. Stats and the shopping list won't count it.")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                .padding(.horizontal, ReffiSpace.s2)
        }
    }

    // MARK: - 저장 (도킹 CTA)

    private var actionBar: some View {
        PaperButton(title: "Save") {
            draft.name = trimmedName
            // 폼에서 냉동으로 옮겼다면 전환 시점을 기록(유예 시계 시작 + 재냉동 방지).
            if draft.storage == .freezer, draft.frozenAt == nil {
                draft.frozenAt = Date()
            }
            store.update(draft)
            dismiss()
        }
        .disabled(trimmedName.isEmpty)   // 이름이 비면 저장 불가 — PaperButton이 투명도로 표시(§7.2, 색 변경 X).
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s2)
        .padding(.bottom, ReffiSpace.s2)
    }

    // MARK: - 헬퍼

    /// 흰 영수증 카드 — `CandidateEditSheet`와 같은 면(오린 톱니 + 헤어라인 + 옅은 그림자).
    private func receiptCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = ReceiptShape(tooth: ReffiTooth.card)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) { content() }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReffiColor.receipt, in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .shadow(color: ReffiColor.shadowTint.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    /// 모노 올캡 섹션 라벨 — 오더 티켓 언어(§13.5). `ReceiptScanView` 쪽 카드와 동일 문법.
    private func sectionLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .reffiType(.sectionLabel)
            .foregroundStyle(ReffiColor.ink2)
    }
}
