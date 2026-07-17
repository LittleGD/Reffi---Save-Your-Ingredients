import SwiftUI
import PhosphorSwift

/// 재료 추가 시트 — 중앙 ＋의 목적지. **일러스트 사전 픽커 + 영수증 스캔**이 추가 플로우의 전부다
/// (사용자 결정: 임의 재료를 타이핑으로 만드는 직접 입력 폼은 주 플로우에서 제거됐다 — 검색이
/// 사전 밖 재료를 못 찾을 때만 컴팩트 폴백 시트로 진입한다, `CustomItemSheet`).
///
/// 표면은 §13 행동표면 언어를 따른다 — **크림 캔버스 + 흰 영수증 카드 + 모노 섹션 라벨 + PaperButton**.
/// 시스템 글래스 툴바·리퀴드글래스 배경은 쓰지 않는다(입력 표면은 조용한 종이).
/// presentationDetents는 여기서 적용한다(호출부 중복 금지).
struct AddIngredientSheet: View {
    var body: some View {
        IngredientPickerSheet()
    }
}

/// 일러스트 사전 픽커 — 탭 한 번이 곧 등록이다(폼 없음). 구조(위→아래):
/// 종이 헤더 → 스캔 카드(기존 유지) → 검색 필드(사전 필터, 임의 생성용 아님) →
/// 픽커 그리드(FREQUENT 이력/시드 → 카테고리 섹션, 탭 = lexicon 기본값으로 즉시 추가).
/// 일러스트는 카테고리를 대표할 뿐 사용자가 고른 재료와 1:1로 묶이지 않는다 — 정확한 표기는
/// 하단 피드백 스트립의 이름과 Edit 진입(사후 정정)이 책임진다.
struct IngredientPickerSheet: View {
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("defaultQuantityValue") private var defaultQuantityValue = 1.0
    @AppStorage("defaultQuantityUnit") private var defaultQuantityUnit = IngredientUnit.piece.rawValue

    @State private var query = ""
    @State private var detent: PresentationDetent = .medium
    @State private var savedCount = 0            // 이번 세션 누적(피드백 스트립·햅틱)
    @State private var lastAdded: Ingredient?     // 직전 추가 항목(피드백 캡션 + Edit 진입 대상)
    @State private var editingIngredient: Ingredient?
    @State private var showScanner = false
    @State private var customDraft: CustomDraft?

    @FocusState private var searchFocused: Bool

    private let margin = ReffiGrid.margin
    private let gridColumns = [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: ReffiSpace.s2)]

    /// 첫 사용자 시드 칩 — '재료 지식'이 아니라 온보딩 UX 순서(무엇을 먼저 보여줄지)라 코드 상수로 둔다.
    /// 재료 자체의 사실(글리프·기한 등)은 여전히 IngredientLexicon(JSON)에서만 나온다.
    private static let seedCanonicalIDs = ["egg", "milk", "onion", "green-onion", "tofu", "kimchi", "potato", "apple"]

    /// 오더 티켓 언어의 카테고리 섹션 순서(§13.3 categoryLabel과 1:1) — 항목 있는 섹션만 그린다.
    private static let categoryOrder = ["Veg", "Fruit", "Meat", "Seafood", "Dairy", "Protein", "Grain", "Bakery", "Pantry", "Other"]

    private struct CustomDraft: Identifiable { let name: String; var id: String { name } }

    private struct GridTile: Identifiable {
        let id: String
        let name: String
        let glyph: FoodGlyph
        let canonicalID: String?
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// FREQUENT — 이력(자주 사는데 지금 없는 재료) 기반, 이력이 없는 첫 사용자는 사전 대표 8종.
    private var frequentItems: [GridTile] {
        let history = store.toBuy.map {
            GridTile(id: "freq-\($0.name)", name: $0.name, glyph: $0.glyph,
                     canonicalID: IngredientLexicon.shared.canonicalID(for: $0.name))
        }
        if !history.isEmpty { return history }
        return Self.seedCanonicalIDs.compactMap { id in
            guard let e = IngredientLexicon.shared.entry(id: id) else { return nil }
            return GridTile(id: "freq-\(id)", name: e.displayName,
                            glyph: FoodGlyph(rawValue: e.glyph) ?? .generic, canonicalID: e.id)
        }
    }

    /// 사전 전체를 categoryLabel로 묶은 섹션 — 항목이 있는 카테고리만, 고정 순서로.
    private var categorySections: [(category: String, items: [GridTile])] {
        var buckets: [String: [GridTile]] = [:]
        for e in IngredientLexicon.shared.entries {
            let glyph = FoodGlyph(rawValue: e.glyph) ?? .generic
            buckets[glyph.categoryLabel, default: []].append(
                GridTile(id: "cat-\(e.id)", name: e.displayName, glyph: glyph, canonicalID: e.id))
        }
        return Self.categoryOrder.compactMap { cat in
            guard let items = buckets[cat], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return (cat, sorted)
        }
    }

    /// 검색 결과 — lexicon.suggestions(matching:) 그대로. 필터일 뿐 임의 생성 경로가 아니다.
    private var searchResults: [GridTile] {
        IngredientLexicon.shared.suggestions(matching: trimmedQuery, limit: 60).map {
            GridTile(id: "search-\($0.id)", name: $0.displayName,
                     glyph: FoodGlyph(rawValue: $0.glyph) ?? .generic, canonicalID: $0.id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            scanCard
                .padding(.horizontal, margin)
                .padding(.bottom, ReffiSpace.s3)
            searchField
                .padding(.horizontal, margin)
                .padding(.bottom, ReffiSpace.s3)
            ScrollView {
                pickerGrid
                    .padding(.horizontal, margin)
                    .padding(.bottom, ReffiSpace.s6)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ReffiColor.canvas)
        .safeAreaInset(edge: .bottom) { feedbackBar }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .sensoryFeedback(.success, trigger: savedCount)
        .sheet(isPresented: $showScanner) { ReceiptScanView() }
        .sheet(item: $editingIngredient) { IngredientEditView(ingredient: $0) }
        .sheet(item: $customDraft) { CustomItemSheet(name: $0.name) }
        // 검색 필드 포커스 → 시트를 .large로. 키보드가 떠도 그리드가 가리지 않는다(P0-2 계승).
        .onChange(of: searchFocused) { _, focused in
            if focused, detent != .large {
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

    /// 영수증 스캔 — 사전 픽커의 보조 입구. Fridge 카드와 같은 흰 영수증 종이 + receipt 아이콘 + chevron.
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

    // MARK: - 검색 필드 (사전 필터 — 임의 생성용 아님)

    private var searchField: some View {
        HStack(spacing: ReffiSpace.s2) {
            ReffiIcon.search.reffi(16).foregroundStyle(ReffiColor.muted)
            TextField("Search ingredients", text: $query,
                      prompt: Text("Search ingredients").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink)
                .submitLabel(.search)
                .focused($searchFocused)
            if !trimmedQuery.isEmpty {
                Button { query = "" } label: {
                    ReffiIcon.close.reffi(11).foregroundStyle(ReffiColor.muted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, ReffiSpace.s4)
        .frame(minHeight: 44)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 2)
            s.fill(ReffiColor.oklch(0.985, 0.004, 90)).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
        }
    }

    // MARK: - 픽커 그리드

    @ViewBuilder
    private var pickerGrid: some View {
        if trimmedQuery.isEmpty {
            LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
                if !frequentItems.isEmpty { gridSection("FREQUENT", tiles: frequentItems, localized: true) }
                ForEach(categorySections, id: \.category) { entry in
                    gridSection(entry.category.uppercased(), tiles: entry.items, localized: false)
                }
            }
        } else if searchResults.isEmpty {
            customFallbackRow
        } else {
            LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
                LazyVGrid(columns: gridColumns, spacing: ReffiSpace.s2) {
                    ForEach(searchResults) { tile($0) }
                }
            }
        }
    }

    @ViewBuilder
    private func gridSection(_ label: String, tiles: [GridTile], localized: Bool) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            if localized {
                Text("FREQUENT")
                    .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(ReffiColor.ink2)
            } else {
                sectionLabel(label)
            }
            LazyVGrid(columns: gridColumns, spacing: ReffiSpace.s2) {
                ForEach(tiles) { tile($0) }
            }
        }
    }

    /// 그리드 타일 — PaperSilhouette(fresh 고정 자연색) + displayName. 탭 = 즉시 추가(폼 없음).
    private func tile(_ item: GridTile) -> some View {
        Button {
            addItem(name: item.name, glyph: item.glyph, canonicalID: item.canonicalID)
        } label: {
            VStack(spacing: ReffiSpace.s1) {
                PaperSilhouette(glyph: item.glyph, fresh: .fresh)
                    .frame(width: 56, height: 56)
                Text(verbatim: item.name)
                    .font(.custom("Pretendard-Medium", size: 12, relativeTo: .caption2))
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, ReffiSpace.s2)
            .padding(.horizontal, ReffiSpace.s1)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: abs(item.id.hashValue) % 4)
                s.fill(ReffiColor.oklch(0.985, 0.004, 90)).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Add \(item.name)"))
    }

    /// 검색 미매치 — 사전 밖 재료를 만드는 유일한 경로(컴팩트 커스텀 시트로 진입).
    private var customFallbackRow: some View {
        Button {
            customDraft = CustomDraft(name: trimmedQuery)
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                ReffiIcon.add.reffi(15).foregroundStyle(ReffiColor.blueDark)
                Text("Add “\(trimmedQuery)” as a custom item")
                    .reffiType(.body).foregroundStyle(ReffiColor.blueDark)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 6)
                s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
    }

    // MARK: - 하단 피드백 스트립 (액션 바 자리)

    /// 탭 즉시 추가라 1차 액션 버튼이 없다 — 대신 방금 추가한 항목 피드백 + Edit(미세 조정 경로).
    @ViewBuilder
    private var feedbackBar: some View {
        if let lastAdded, savedCount > 0 {
            HStack(spacing: ReffiSpace.s3) {
                Text("Added \(lastAdded.name) · \(savedCount) this run")
                    .font(.custom("Pretendard-Medium", size: 13, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: ReffiSpace.s2)
                Button { editingIngredient = lastAdded } label: {
                    Text("Edit")
                        .font(.custom("Pretendard-SemiBold", size: 13, relativeTo: .caption))
                        .foregroundStyle(ReffiColor.blueDark)
                        .padding(.horizontal, ReffiSpace.s3)
                        .padding(.vertical, ReffiSpace.s1 + 2)
                        .background {
                            let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: 5)
                            s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
            }
            .padding(.horizontal, margin)
            .padding(.top, ReffiSpace.s3)
            .padding(.bottom, ReffiSpace.s3)
            .background(ReffiColor.canvas)
            .transition(.opacity)
        }
    }

    // MARK: - 카드 래퍼 · 모노 라벨

    /// 모노 섹션 라벨(오더 티켓 언어, §13.5) — 한/영 공통 영문 대문자(주방 패스 라벨).
    private func sectionLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
            .tracking(1.4)
            .foregroundStyle(ReffiColor.ink2)
    }

    // MARK: - 즉시 추가

    /// storage 우선순위(fridge→pantry→room→freezer 중 shelfLife가 정의된 첫 값)로 보관을 고르고,
    /// 그 보관의 사전 기본 기한 + 프로필 기본 수량으로 바로 저장한다 — 폼 없이 탭 한 번.
    private func addItem(name: String, glyph: FoodGlyph, canonicalID: String?) {
        let resolvedID = canonicalID ?? IngredientLexicon.shared.canonicalID(for: name)
        let storage = defaultStorage(for: resolvedID)
        let expiresAt = IngredientLexicon.shared.defaultExpiry(for: name, storage: storage)
            ?? Ingredient.day(offset: 3)
        let unit = IngredientUnit(rawValue: defaultQuantityUnit) ?? .piece
        let ingredient = Ingredient(name: name, category: glyph.categoryLabel, expiresAt: expiresAt,
                                    quantity: Quantity(value: householdScaledQuantity(unit), unit: unit),
                                    glyph: glyph, storage: storage, canonicalID: resolvedID)
        store.add(ingredient)
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
            lastAdded = ingredient
        }
        savedCount += 1
    }

    /// 가구 인원 배율 적용 — **개수 차원(piece/pack/bunch 등)일 때만** 기본 수량에 곱한다.
    /// g/ml 같은 연속 단위는 "1인분=1kg"처럼 단순 비례하지 않아(레시피별로 다름) 배율을 적용하지 않고
    /// 프로필 기본값을 그대로 쓴다. 반올림 후 최소 1 보장(0으로 떨어지지 않게).
    private func householdScaledQuantity(_ unit: IngredientUnit) -> Double {
        guard unit.dimension == .count else { return defaultQuantityValue }
        return max(1, (defaultQuantityValue * profile.household.quantityMultiplier).rounded())
    }

    private func defaultStorage(for canonicalID: String?) -> StorageLocation {
        guard let id = canonicalID, let entry = IngredientLexicon.shared.entry(id: id) else { return .fridge }
        let life = entry.shelfLife
        if life.fridge != nil { return .fridge }
        if life.pantry != nil { return .pantry }
        if life.room != nil { return .room }
        if life.freezer != nil { return .freezer }
        return .fridge
    }
}

/// 검색 미매치 폴백 — 사전에 없는 재료를 커스텀으로 등록하는 컴팩트 시트(주 플로우 아닌 예외 경로).
/// 이름은 검색어로 고정(수정 불가) — 직접 입력 폼을 부활시키지 않는다. 기한·수량·보관만 조정.
private struct CustomItemSheet: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let name: String

    @AppStorage("defaultQuantityValue") private var defaultQuantityValue = 1.0
    @AppStorage("defaultQuantityUnit") private var defaultQuantityUnit = IngredientUnit.piece.rawValue

    @State private var expiresAt = Ingredient.day(offset: 3)
    @State private var expiryTouched = false          // 사용자가 날짜를 만졌으면 스마트 기본값 중지
    @State private var lastProgrammaticExpiry: Date?  // applySmartExpiry가 마지막으로 대입한 값
    @State private var quantityValue: Double = 1
    @State private var unit: IngredientUnit = .piece
    @State private var storage: StorageLocation = .fridge
    @State private var savedHaptic = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                fieldsCard
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.top, ReffiSpace.s1)
                    .padding(.bottom, ReffiSpace.s4)
            }
            .scrollDismissesKeyboard(.interactively)
            actionBar
        }
        .background(ReffiColor.canvas)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .sensoryFeedback(.success, trigger: savedHaptic)
        .onAppear {
            quantityValue = defaultQuantityValue
            unit = IngredientUnit(rawValue: defaultQuantityUnit) ?? .piece
            applySmartExpiry()
        }
        .onChange(of: storage) { _, _ in applySmartExpiry() }
    }

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
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s5)
        .padding(.bottom, ReffiSpace.s3)
    }

    private var fieldsCard: some View {
        let shape = ReceiptShape(tooth: 7)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            sectionLabel("ITEM")
            Text(verbatim: name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                .frame(minHeight: 44, alignment: .leading)

            DashedRule()

            HStack {
                Text("Use by").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                DatePicker("", selection: $expiresAt,
                           in: Ingredient.day(offset: -30)...Ingredient.day(offset: 365),
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(ReffiColor.blue)
                    .onChange(of: expiresAt) { _, newValue in
                        if newValue != lastProgrammaticExpiry { expiryTouched = true }
                    }
            }
            .frame(minHeight: 44)

            expiryHintCaption

            DashedRule()

            HStack {
                Text("Quantity").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                TextField("1", value: $quantityValue, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
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

            HStack {
                Text("Storage").reffiType(.body).foregroundStyle(ReffiColor.ink)
                Spacer()
                Picker("Storage", selection: $storage) {
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
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    /// Use by 아래 상태 캡션 — ManualAddForm의 스마트 기한 힌트를 그대로 재사용(§설계 4).
    @ViewBuilder
    private var expiryHintCaption: some View {
        if !expiryTouched {
            if let days = IngredientLexicon.shared.shelfLifeDays(for: name, storage: storage) {
                Text("\(storage.label) default · \(days)d")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            } else {
                Text("Not in the dictionary — please check the date")
                    .reffiType(.caption).foregroundStyle(ReffiColor.soonDark)
            }
        }
    }

    private var actionBar: some View {
        PaperButton(title: "Add") { save() }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.top, ReffiSpace.s3)
            .padding(.bottom, ReffiSpace.s3)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
            .tracking(1.4)
            .foregroundStyle(ReffiColor.ink2)
    }

    private func applySmartExpiry() {
        guard !expiryTouched else { return }
        let smart = IngredientLexicon.shared.defaultExpiry(for: name, storage: storage)
            ?? Ingredient.day(offset: 3)
        lastProgrammaticExpiry = smart
        expiresAt = smart
    }

    private func save() {
        let glyph = FoodGlyph.match(name)
        store.add(Ingredient(name: name, category: glyph.categoryLabel, expiresAt: expiresAt,
                             quantity: Quantity(value: max(0.1, quantityValue), unit: unit),
                             glyph: glyph, storage: storage))
        savedHaptic += 1
        dismiss()
    }
}
