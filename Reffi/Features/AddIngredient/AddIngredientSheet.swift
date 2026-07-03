import SwiftUI
import PhosphorSwift

/// 재료 추가 시트 — 중앙 ＋의 목적지. **탭 즉시 입력 폼**(죽은 옵션 메뉴 없음 — 스캔/바코드는
/// 출시 시점에 폼 상단 보조 버튼으로 돌아온다). `prefillName`이 오면(쇼핑리스트 재입고) 이름과
/// 직전 이력 스냅샷(보관·구매처·수량)까지 채워 연다.
struct AddIngredientSheet: View {
    var prefillName: String = ""

    var body: some View {
        ManualAddForm(prefillName: prefillName)
    }
}

/// 직접 입력 폼 — 이름 + 소비기한(필수), 수량·구매처·보관(선택).
/// ① 이름을 입력하면 정본 재료 사전이 실시간으로 글리프·카테고리·**보관별 기본 소비기한**을 채운다
///    (사용자가 날짜를 직접 만지면 그 뒤로는 존중).
/// ② 이름 아래 제안 칩(이력 + 사전) — 탭 한 번으로 반복 구매 재료를 채운다.
/// ③ "저장하고 계속" — 장보기 직후 연속 등록의 왕복을 없앤다.
struct ManualAddForm: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var prefillName: String = ""

    @AppStorage("defaultQuantityValue") private var defaultQuantityValue = 1.0
    @AppStorage("defaultQuantityUnit") private var defaultQuantityUnit = IngredientUnit.piece.rawValue

    @State private var name = ""
    @State private var expiresAt = Ingredient.day(offset: 3)
    @State private var expiryTouched = false     // 사용자가 날짜를 만졌으면 스마트 기본값 중지
    @State private var quantityValue: Double = 1
    @State private var unit: IngredientUnit = .piece
    @State private var place = ""
    @State private var storage: StorageLocation = .fridge
    @State private var savedCount = 0            // 연속 추가 피드백(햅틱)
    @State private var showScanner = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 제안 칩 — 입력 중엔 사전 매칭, 비어 있으면 자주 쓰는 이력(재구매 패턴).
    private var suggestions: [String] {
        if trimmedName.isEmpty {
            var seen = Set<String>()
            return store.toBuy.map(\.name).filter { seen.insert($0.lowercased()).inserted }
                .prefix(6).map { $0 }
        }
        let fromLexicon = IngredientLexicon.shared.suggestions(matching: trimmedName)
            .map(\.displayName)
        return fromLexicon.filter { $0.lowercased() != trimmedName.lowercased() }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 영수증 스캔 — 직접 입력의 보조 입구(폼 직행 원칙 유지, 죽은 메뉴로 돌아가지 않음).
                Section {
                    Button { showScanner = true } label: {
                        HStack(spacing: ReffiSpace.s3) {
                            ReffiIcon.receipt.reffi(20).foregroundStyle(ReffiColor.blueDark)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Scan a receipt")
                                    .reffiType(.body).foregroundStyle(ReffiColor.ink)
                                Text("Add a whole grocery run at once")
                                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                            }
                            Spacer()
                            ReffiIcon.chevron.reffi(13).foregroundStyle(ReffiColor.muted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Section("Item") {
                    TextField("Name", text: $name)
                        .submitLabel(.done)
                        .focused($nameFocused)
                    if !suggestions.isEmpty {
                        suggestionChips
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                    DatePicker("Use by", selection: $expiresAt,
                               in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                               displayedComponents: .date)
                        .onChange(of: expiresAt) { _, _ in
                            // 프로그램이 바꾼 게 아니라면(플래그) 사용자의 선택으로 간주.
                            if !applyingSmartExpiry { expiryTouched = true }
                        }
                }
                Section("Details (optional)") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", value: $quantityValue, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                        Picker("Unit", selection: $unit) {
                            ForEach(IngredientUnit.allCases) { u in
                                Text(verbatim: u.label).tag(u)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    TextField("Where you bought it", text: $place)
                    Picker("Storage", selection: $storage) {
                        // 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
                        ForEach(StorageLocation.allCases) { s in
                            Text(LocalizedStringKey(s.rawValue)).tag(s)
                        }
                    }
                }
                Section {
                    Button {
                        save(dismissAfter: false)
                    } label: {
                        Label { Text("Save & add another") } icon: { ReffiIcon.add.reffi(15, .bold) }
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .navigationTitle(Text("Add ingredient"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(dismissAfter: true) }
                        .tint(ReffiColor.blue)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .sensoryFeedback(.success, trigger: savedCount)
            .sheet(isPresented: $showScanner) { ReceiptScanView() }
        }
        .onAppear { applyPrefill() }
        .onChange(of: name) { _, _ in applySmartExpiry() }
        .onChange(of: storage) { _, _ in applySmartExpiry() }
    }

    // MARK: - 제안 칩

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        name = s
                        nameFocused = false
                    } label: {
                        Text(verbatim: s)
                            .font(.custom("Pretendard-SemiBold", size: 13, relativeTo: .caption))
                            .foregroundStyle(ReffiColor.blueDark)
                            .padding(.horizontal, ReffiSpace.s3)
                            .padding(.vertical, ReffiSpace.s1 + 2)
                            .background(ReffiColor.blueLight, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 스마트 기본값

    @State private var applyingSmartExpiry = false

    /// 사전 기반 기본 소비기한 — 이름·보관이 바뀔 때마다, 사용자가 날짜를 만지기 전까지만.
    private func applySmartExpiry() {
        guard !expiryTouched else { return }
        let smart = IngredientLexicon.shared.defaultExpiry(for: trimmedName, storage: storage)
        applyingSmartExpiry = true
        expiresAt = smart ?? Ingredient.day(offset: 3)
        DispatchQueue.main.async { applyingSmartExpiry = false }
    }

    /// 첫 표시 구성 — 프로필 기본 수량/단위를 깔고, 재입고면 이름 + 직전 이력 스냅샷
    /// (보관·구매처·수량)까지 복원한다. 기한은 사전 기본값으로 새로 계산.
    private func applyPrefill() {
        quantityValue = defaultQuantityValue
        unit = IngredientUnit(rawValue: defaultQuantityUnit) ?? .piece
        if name.isEmpty, !prefillName.isEmpty {
            name = prefillName
            if let last = store.lastSnapshot(named: prefillName) {
                storage = last.storage == .freezer ? .fridge : last.storage   // 재구매는 냉동 상태가 아님
                place = last.place
                quantityValue = last.quantity.value
                unit = last.quantity.unit
            }
        }
        applySmartExpiry()
    }

    // MARK: - 저장

    private func save(dismissAfter: Bool) {
        let n = trimmedName
        guard !n.isEmpty else { return }
        let glyph = FoodGlyph.match(n)
        store.add(Ingredient(name: n,
                             category: glyph.categoryLabel,
                             expiresAt: expiresAt,
                             quantity: Quantity(value: max(0.1, quantityValue), unit: unit),
                             glyph: glyph,
                             place: place,
                             storage: storage))
        savedCount += 1
        if dismissAfter {
            dismiss()
        } else {
            // 연속 추가 — 이름·수량만 리셋(보관·구매처는 같은 장보기일 확률이 높아 유지).
            name = ""
            expiryTouched = false
            quantityValue = defaultQuantityValue
            unit = IngredientUnit(rawValue: defaultQuantityUnit) ?? .piece
            applySmartExpiry()
            nameFocused = true
        }
    }
}
