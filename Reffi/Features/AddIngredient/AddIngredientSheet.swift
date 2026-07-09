import SwiftUI
import PhosphorSwift

/// 재료 추가 시트 — 중앙 ＋의 목적지. **탭 즉시 입력 폼**(죽은 옵션 메뉴 없음 — 스캔/바코드는
/// 출시 시점에 폼 상단 보조 버튼으로 돌아온다). `prefillName`이 오면(쇼핑리스트 재입고) 이름과
/// 직전 이력 스냅샷(보관·구매처·수량)까지 채워 연다.
///
/// 표면은 §13 행동표면 언어를 따른다 — **크림 캔버스 + 흰 영수증 카드 + 모노 섹션 라벨 + DashedRule +
/// PaperButton**. 시스템 글래스 툴바·리퀴드글래스 배경은 쓰지 않는다(입력 표면은 조용한 종이).
/// presentationDetents는 여기서 적용한다(호출부 중복 금지).
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
/// ③ 하단 고정 액션 바의 **Add** = 저장 후 폼을 리셋하고 시트를 유지(연속 등록) — 장보기 직후 왕복 제거.
///    재입고(prefill) 진입일 때만 단건 의도로 저장 후 닫는다.
struct ManualAddForm: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var savedCount = 0            // 이번 세션 누적(연속 추가 피드백·햅틱)
    @State private var lastAdded: String?        // 직전 추가 항목명(피드백 캡션)
    @State private var showScanner = false
    @State private var detent: PresentationDetent = .medium   // 텍스트 포커스 시 .large로 승격

    /// 키보드를 여는 텍스트 필드 — 포커스가 잡히면 시트를 .large로 올려 액션 바까지 보이게 한다.
    private enum Field { case name, quantity, place }
    @FocusState private var field: Field?

    private let margin = ReffiGrid.margin

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// 재입고(쇼핑리스트) 진입 — 단건 의도라 저장 후 시트를 닫는다.
    private var isRestock: Bool { !prefillName.isEmpty }

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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: ReffiSpace.s4) {
                    scanCard
                    itemCard
                    detailsCard
                }
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s1)
                .padding(.bottom, ReffiSpace.s5)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ReffiColor.canvas)
        .safeAreaInset(edge: .bottom) { actionBar }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .sensoryFeedback(.success, trigger: savedCount)
        .sheet(isPresented: $showScanner) { ReceiptScanView() }
        .onAppear { applyPrefill() }
        .onChange(of: name) { _, _ in applySmartExpiry() }
        .onChange(of: storage) { _, _ in applySmartExpiry() }
        // 텍스트 필드 포커스 → 시트를 .large로. 키보드가 떠도 내용·액션 바가 가리지 않는다(P0-2).
        .onChange(of: field) { _, focused in
            if focused != nil, detent != .large {
                withAnimation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)) {
                    detent = .large
                }
            }
        }
    }

    // MARK: - 헤더 (종이 X 닫기)

    /// 좌측 타이틀 + 우측 종이 X 닫기(§7.3 — 시각 34, 히트 44). 시스템 글래스 툴바를 대체한다.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Add ingredient").reffiType(.heading).foregroundStyle(ReffiColor.ink)
            Spacer()
            Button { dismiss() } label: {
                ReffiIcon.close.reffi(14, .bold)
                    .foregroundStyle(ReffiColor.ink)
                    .frame(width: 34, height: 34)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 4)
                        s.fill(ReffiColor.paper).paperEdge(s)
                    }
                    .reffiShadow1()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, margin)
        .padding(.top, ReffiSpace.s5)
        .padding(.bottom, ReffiSpace.s3)
    }

    // MARK: - 스캔 카드 (흰 영수증 종이)

    /// 영수증 스캔 — 직접 입력의 보조 입구. Fridge 카드와 같은 흰 영수증 종이 + receipt 아이콘 + chevron.
    private var scanCard: some View {
        let shape = ReceiptShape(tooth: 7)
        return Button { showScanner = true } label: {
            HStack(spacing: ReffiSpace.s3) {
                ReffiIcon.receipt.reffi(22).foregroundStyle(ReffiColor.blueDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a receipt")
                        .reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Text("Add a whole grocery run at once")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                Spacer(minLength: ReffiSpace.s2)
                ReffiIcon.chevron.reffi(13).foregroundStyle(ReffiColor.muted)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
            .contentShape(shape)
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel("Scan a receipt")
    }

    // MARK: - 입력 카드 1 · ITEM

    private var itemCard: some View {
        receiptCard {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                sectionLabel("ITEM")

                TextField("Name", text: $name,
                          prompt: Text("Name").foregroundStyle(ReffiColor.ink2))
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .submitLabel(.done)
                    .focused($field, equals: .name)
                    .frame(minHeight: 44)

                if !suggestions.isEmpty { suggestionChips }

                DashedRule()

                // Use by — 라벨 좌 + DatePicker(.compact) 우, 파란 tint.
                HStack {
                    Text("Use by").reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    DatePicker("", selection: $expiresAt,
                               in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                               displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(ReffiColor.blue)
                        .onChange(of: expiresAt) { _, _ in
                            // 프로그램이 바꾼 게 아니라면(플래그) 사용자의 선택으로 간주.
                            if !applyingSmartExpiry { expiryTouched = true }
                        }
                }
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: - 입력 카드 2 · DETAILS · OPTIONAL

    private var detailsCard: some View {
        receiptCard {
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                sectionLabel("DETAILS · OPTIONAL")

                // 수량 — 값 필드 + 단위 Picker(.menu), 파란 tint.
                HStack {
                    Text("Quantity").reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    TextField("1", value: $quantityValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($field, equals: .quantity)
                        .reffiType(.body).foregroundStyle(ReffiColor.ink)
                        .frame(width: 64)
                    Picker("Unit", selection: $unit) {
                        ForEach(IngredientUnit.allCases) { u in
                            Text(verbatim: u.label).tag(u)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(ReffiColor.blue)
                }
                .frame(minHeight: 44)

                DashedRule()

                // 구매처 — 자유 입력(전폭). 라벨 대신 placeholder가 설명한다.
                TextField("Where you bought it", text: $place,
                          prompt: Text("Where you bought it").foregroundStyle(ReffiColor.ink2))
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .focused($field, equals: .place)
                    .frame(minHeight: 44)

                DashedRule()

                // 보관 — 라벨 좌 + Picker(.menu) 우.
                HStack {
                    Text("Storage").reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Picker("Storage", selection: $storage) {
                        // 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
                        ForEach(StorageLocation.allCases) { s in
                            Text(LocalizedStringKey(s.rawValue)).tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(ReffiColor.blue)
                }
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: - 하단 고정 액션 바 (키보드 위에서도 항상 보임)

    /// safeAreaInset(.bottom) — 키보드가 떠도 액션 바가 그 위에 남는다(P0-2).
    /// Add = 기본 연속 등록(저장 후 폼 리셋·시트 유지). 재입고는 저장 후 닫기.
    private var actionBar: some View {
        VStack(spacing: ReffiSpace.s2) {
            if let lastAdded, savedCount > 0 {
                // 방금 추가 피드백 — 직전 항목 + 이번 세션 누적.
                Text("Added \(lastAdded) · \(savedCount) this run")
                    .font(.custom("Pretendard-Medium", size: 13, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .transition(.opacity)
            }
            PaperButton(title: "Add", kind: .primary) { addTapped() }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, margin)
        .padding(.top, ReffiSpace.s3)
        .padding(.bottom, ReffiSpace.s3)
        .background(ReffiColor.canvas)
    }

    // MARK: - 카드 래퍼 · 모노 라벨

    /// 흰 영수증 카드 — Fridge 스택(ShoppingList·History)과 같은 종이·톱니·약한 드롭섀도.
    private func receiptCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = ReceiptShape(tooth: 7)
        return content()
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + 3)   // 톱니 인셋
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    /// 모노 섹션 라벨(오더 티켓 언어, §13.5) — 한/영 공통 영문 대문자(주방 패스 라벨).
    private func sectionLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
            .tracking(1.4)
            .foregroundStyle(ReffiColor.ink2)
    }

    // MARK: - 제안 칩

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        name = s
                        field = nil
                    } label: {
                        Text(verbatim: s)
                            .font(.custom("Pretendard-SemiBold", size: 13, relativeTo: .caption))
                            .foregroundStyle(ReffiColor.blueDark)
                            .padding(.horizontal, ReffiSpace.s3)
                            .padding(.vertical, ReffiSpace.s1 + 2)
                            .background(ReffiColor.blueLight, in: Capsule())
                            .frame(minHeight: 44)              // §7.3 최소 터치 타깃
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.reffiPress)
                    .accessibilityLabel(Text("Use \(s)"))
                }
            }
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

    /// Add 탭 — 재입고면 단건(닫기), 아니면 연속 등록(시트 유지·폼 리셋).
    private func addTapped() {
        save(dismissAfter: isRestock)
    }

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
            withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                lastAdded = n
            }
            name = ""
            expiryTouched = false
            quantityValue = defaultQuantityValue
            unit = IngredientUnit(rawValue: defaultQuantityUnit) ?? .piece
            applySmartExpiry()
            field = .name
        }
    }
}
