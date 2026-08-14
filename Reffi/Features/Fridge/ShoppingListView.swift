import SwiftUI

/// 사야 할 식재료 — 자주 쓰는데(이력) 지금 냉장고에 없는 항목이 자동으로 채워지고, 습관이 못 잡는 품목은
/// 하단 "Add item"으로 직접 담는다(§13.5 To buy 예외 — **재고 추가가 아니라 장보기 메모**다).
/// Add = 시트 없이 **즉시 재입고** — 직전 이력 스냅샷(보관·구매처·수량, 냉동이었다면 냉장으로)과
/// 사전 기본 기한으로 바로 store에 채워 넣는다(§13.6 재입고 경로 — AddIngredientSheet 의존 없음).
struct ShoppingListView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var restockHaptic = 0
    /// Skip은 §7.6의 **판정·확정**이다(Ate/Tossed와 같은 결의 "이번엔 안 사기") — `.impact(.light)`.
    /// 목록에 담기는 Add 쪽이 성공 완료(`.success`)이므로 같은 행의 두 알약이 다른 의미로 갈린다.
    @State private var skipHaptic = 0
    @State private var showSearch = false

    private typealias Row = (name: String, glyph: FoodGlyph, manual: Bool, key: String)

    private var items: [Row] { store.toBuy }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: ReffiColor.blue.opacity(0.5))
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: ReffiSpace.s4) {
                        if items.isEmpty {
                            emptyCard
                        } else {
                            listCard
                        }
                        addItemButton
                    }
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.bottom, ReffiSpace.s6)
                }
            }
        }
        .sensoryFeedback(.success, trigger: restockHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: skipHaptic)
        .sheet(isPresented: $showSearch) { ToBuySearchSheet() }
        #if DEBUG
        // `-toBuy.search` — 검색 시트 자동 오픈(스크린샷·QA용). 커버 자체는 `FridgeView`가 연다.
        // 커버 전환과 같은 프레임에 시트를 올리면 프레젠테이션이 씹히므로 전환이 끝난 뒤로 미룬다.
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("-toBuy.search") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showSearch = true }
        }
        #endif
    }

    /// 직전 이력 스냅샷이 있으면 보관·구매처·수량을 복원(냉동이었다면 냉장으로 — 재구매는 냉동 상태가
    /// 아니다), 없으면 사전 기본값으로 새로 채운다. 소비기한은 항상 그 보관의 사전 기본값으로 재계산.
    /// 가구 인원 배율은 **스냅샷이 없는 폴백 경로에만** 적용한다 — 스냅샷이 있으면 사용자가 이미 그
    /// 수량을 한 번 결정한 값이라 존중하고 그대로 복원한다(재입고 때마다 배율이 누적되지 않게).
    /// 직접 담은 항목이었다면 `store.add`가 그 메모를 함께 내린다(샀으니 목록에 남을 이유가 없다).
    private func restock(name: String, glyph: FoodGlyph) {
        let lex = IngredientLexicon.shared
        if let last = store.lastSnapshot(named: name) {
            let storage = last.storage == .freezer ? .fridge : last.storage
            let expiresAt = lex.defaultExpiry(for: name, storage: storage) ?? Ingredient.day(offset: 3)
            store.add(Ingredient(name: name, category: glyph.categoryLabel, expiresAt: expiresAt,
                                 quantity: last.quantity, glyph: glyph, place: last.place, storage: storage))
        } else {
            let expiresAt = lex.defaultExpiry(for: name, storage: .fridge) ?? Ingredient.day(offset: 3)
            // 폴백 기본 수량(1개)은 개수 차원이라 가구 인원 배율을 그대로 곱한다.
            let quantity = Quantity(value: max(1, profile.household.quantityMultiplier.rounded()), unit: .piece)
            store.add(Ingredient(name: name, category: glyph.categoryLabel, expiresAt: expiresAt,
                                 quantity: quantity, glyph: glyph))
        }
        restockHaptic += 1
    }

    private var header: some View {
        CoverHeader(title: "To buy",
                    subtitle: "Restock what you use often",
                    onClose: { dismiss() })
    }

    /// 직접 담은 구역(맨 위) / 이력 제안 구역 — 두 구역은 캡션이 다르다(제안 캡션이 수동 항목까지
    /// 설명하면 거짓말이 된다). 목록은 한 번만 읽어 나눈다(파생 계산이 이력 전체를 훑는다).
    private var listCard: some View {
        let rows = items
        let manual = rows.filter(\.manual)
        let suggested = rows.filter { !$0.manual }
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            if !manual.isEmpty {
                Text("Added by you")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                ForEach(manual, id: \.key) { row($0) }
            }
            if !suggested.isEmpty {
                // 두 구역 구분은 절취선 어휘로(보더 금지 §6).
                if !manual.isEmpty { DashedRule() }
                Text("Ran out, based on what you use often")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                ForEach(suggested, id: \.key) { row($0) }
            }
        }
        .receiptSurface()
    }

    /// 목록 한 줄 — 두 구역이 같은 문법을 쓴다(직접 담은 것도 제안과 똑같이 Add/Skip으로 처리한다).
    private func row(_ item: Row) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: item.glyph, fresh: .fresh).frame(width: 36, height: 36)
            Text(verbatim: item.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
            Spacer()
            Button {
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    restock(name: item.name, glyph: item.glyph)
                }
            } label: {
                Text("Add")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.blueDark)
                    .padding(.horizontal, ReffiSpace.s3 + 2)
                    .padding(.vertical, ReffiSpace.s1 + 1)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: 1)
                        s.fill(ReffiColor.blueLight).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text("Restock \(item.name)"))
            Button {
                withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                    store.skipBuy(key: item.key)
                }
                skipHaptic += 1   // §7.6 판정·확정 = .impact (Add의 .success와 짝)
            } label: {
                Text("Skip")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.ink2)
                    .padding(.horizontal, ReffiSpace.s3 + 2)
                    .padding(.vertical, ReffiSpace.s1 + 1)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.pill, seed: 2)
                        s.fill(ReffiColor.sub).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel(Text("Skip \(item.name) this time"))
        }
    }

    /// 목록 아래 직접 담기 진입 — 하단 CTA 관례대로 `PaperButton`을 쓰되 `secondary`다: 이 화면의 1차
    /// 행동은 행마다의 파란 Add(재입고)라, 파란 와이드 버튼이 그 위계를 뒤집으면 안 된다.
    private var addItemButton: some View {
        PaperButton(title: "Add item", kind: .secondary, seed: 3) { showSearch = true }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("All stocked up").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Nothing you regularly use has run out.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .receiptSurface(elevated: .flat)
    }
}

/// 재료 검색 바텀시트 — 정본 사전(`IngredientLexicon`)에서 골라 **장보기 목록에만** 얹는다(냉장고 반입 아님).
/// 검색바 아래는 삭제된 재료 픽커 시트의 **재료 배열 그리드**(`pickerGrid`)가 채우고, 타이핑하면 같은
/// 문법의 결과 그리드(`searchGrid`)로 바뀐다 — 타이핑 전후로 시각 언어가 갈리지 않는다.
/// 연속 추가 UX: 타일을 탭해도 시트는 닫히지 않고 그 타일이 체크로 바뀐다(장보기 메모는 보통 한 번에 여럿 적는다).
/// 사전 밖 이름을 자유 입력으로 **만드는** 경로는 여기 두지 않는다 — 그건 여전히 영수증 스캔의 후보 편집
/// (`CandidateEditSheet`)이 정본이다(§13.5 단일 경로 예외를 최소로 유지).
private struct ToBuySearchSheet: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    @State private var query = ""
    @State private var addHaptic = 0
    /// 시트 높이를 코드에서 올리기 위한 바인딩 축(원본 픽커 `detent`와 같은 역할) — 검색 포커스 시 .large.
    @State private var detent: PresentationDetent = .medium

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// 상한 60은 원본 픽커의 값이다(`suggestions(matching:limit: 60)`) — 결과도 타일 그리드로 그리므로
    /// 한 화면에 스무 개 남짓만 남기는 리스트 기준 기본값(20)으로는 배열이 조기에 잘린다.
    private var results: [IngredientLexicon.Entry] {
        IngredientLexicon.shared.search(query: trimmedQuery, limit: 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Add to list", showsClose: true) { dismiss() }
            searchField
                .padding(.horizontal, ReffiGrid.margin)
            ScrollView {
                content
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.top, ReffiSpace.s3)
                    .padding(.bottom, ReffiSpace.s5)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ReffiColor.canvas)
        // 검색 필드 + 목록/그리드 = 중간 목록·폼 버킷(§14.5): .medium은 진입 높이일 뿐이고, 카테고리
        // 섹션까지 쌓이는 재료 배열은 스크롤·.large 승격을 전제한다(FREQUENT가 늘 첫 화면에 온다).
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(ReffiColor.canvas)
        .sensoryFeedback(.success, trigger: addHaptic)   // 목록에 담김 = 성공 완료(§7.6)
        // 검색 필드 포커스 → 시트를 .large로. 키보드가 떠도 그리드가 가리지 않는다(원본 픽커 P0-2 계승).
        // 진입 자동 포커스는 두지 않는다: 이 시트의 기본 상태는 `content` 주석이 선언한 대로 타이핑 없이
        // 끝나는 재료 배열인데, 자동 포커스는 .medium 높이에서 그 배열을 키보드로 덮어 스스로의 원칙을
        // 무효화했다. `-toBuy.search` QA 인자는 시트를 여는 역할만 하므로(ShoppingListView:44-47) 그대로
        // 동작하고, 이제 그 스크린샷이 기본 상태(=그리드)를 찍는다.
        .onChange(of: searchFocused) { _, focused in
            if focused, detent != .large {
                withAnimation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)) {
                    detent = .large
                }
            }
        }
    }

    /// 원본 픽커 검색 필드(돋보기 + 필드 + 클리어 ×)의 구성을 그대로 되살린다.
    /// 클리어(×)가 필요한 이유: 이 시트의 기본 상태는 재료 배열이고 배열로 돌아가는 유일한 조작이
    /// 쿼리 비우기다 — 전체 선택-삭제밖에 없으면 기본 상태로의 복귀 비용이 배열을 기본으로 둔 설계를
    /// 실사용에서 무너뜨린다. 돋보기도 함께 복원했다: 이 필드가 사전 *필터*이지 임의 재료 *생성*
    /// 입구가 아니라는 어포던스를 원본이 이 아이콘으로 전달했고, 여기도 생성 경로가 없어 의미가 같다.
    private var searchField: some View {
        HStack(spacing: ReffiSpace.s2) {
            ReffiIcon.search.reffi(16).foregroundStyle(ReffiColor.muted)
            TextField("Search ingredients", text: $query,
                      prompt: Text("Search ingredients").foregroundStyle(ReffiColor.ink2))
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink)
                .focused($searchFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
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
        .padding(.vertical, ReffiSpace.s3)
        .frame(minHeight: 44)   // §7.3 터치 타깃
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 6)
            // receipt — 원본 픽커 검색 필드의 인라인 값 oklch(0.985, 0.004, 90)이 곧 이 토큰이고,
            // 시트 안의 다른 종이 면(타일·listCard·emptyCard·noMatchCard)도 전부 receipt다.
            // paper(0.99, 0.006, 90)는 다른 토큰이라 여기만 남으면 시트 안 종이결이 갈라진다.
            s.fill(ReffiColor.receipt).paperEdge(s, tint: ReffiColor.ink.opacity(0.1))
        }
    }

    @ViewBuilder private var content: some View {
        if trimmedQuery.isEmpty {
            // 아직 아무것도 안 친 상태 — 빈 화면 대신 재료 배열(픽커 그리드). 장보기 메모의 대부분은
            // 늘 사는 것들이라 타이핑 없이 끝나는 경로가 기본값이어야 한다(타이핑하면 결과 그리드로 교체).
            pickerGrid
        } else {
            // 사전 검색은 키 입력마다 도는 경로다 — 분기와 그리드에서 `results`를 두 번 평가하지 않게
            // 한 번만 계산해 넘긴다(223종 스캔 x2 → x1).
            let hits = results
            if hits.isEmpty { noMatchCard } else { searchGrid(hits) }
        }
    }

    /// 타일 한 칸의 표시 단위 — `key`는 matchKey(캐논 ID 또는 소문자 이름)로, '이미 담김' 판정과
    /// 종이결 시드와 캐논 해석에 모두 같은 값을 쓴다(축이 갈리면 같은 재료가 두 규칙을 탄다).
    private struct GridTile: Identifiable {
        let id: String
        let name: String
        let glyph: FoodGlyph
        let key: String
    }

    /// 원본 픽커(2026-08-01 삭제)의 열 규격 그대로 — 적응형 74~96pt, 거터 s2.
    private static let gridColumns = [GridItem(.adaptive(minimum: 74, maximum: 96), spacing: ReffiSpace.s2)]

    /// 삭제된 재료 픽커 시트의 **재료 배열 UI**를 그대로 되살린 자리 — 검색어가 비어 있는 동안 이
    /// 그리드가 시트를 채운다. 치수·구조는 원본 그대로다: 적응형 74~96pt 열 + 56pt 실루엣 타일,
    /// 섹션 간 s5 / 타일 간 s2, 모노 올캡 섹션 헤더. 순서도 원본과 같다 —
    /// FREQUENT(빨리 담기 단축키) → 사전 전체를 카테고리로 묶은 섹션(`FoodGlyph.categoryOrder` — 냉장고 필터 칩과 같은 순서 상수).
    /// **의미만 To buy 문맥이다**: 탭은 냉장고 반입이 아니라 `addToBuy`(장보기 메모)고, 시트는 닫히지
    /// 않으며, 이미 담긴 타일에는 결과 행과 같은 체크가 남는다.
    private var pickerGrid: some View {
        let listed = store.toBuyKeys      // 섹션당 한 번만 — 타일마다 파생 목록을 다시 계산하지 않게
        let frequent = store.frequentIngredients().map {
            GridTile(id: "freq-\($0.key)", name: $0.name, glyph: $0.glyph, key: $0.key)
        }
        return LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
            if !frequent.isEmpty { gridSection("FREQUENT", tiles: frequent, listed: listed) }
            ForEach(IngredientLexicon.shared.categorySections, id: \.category) { section in
                gridSection(LocalizedStringKey(section.category),
                            tiles: section.entries.map {
                                GridTile(id: "cat-\($0.id)", name: $0.displayName,
                                         glyph: FoodGlyph(rawValue: $0.glyph) ?? .generic, key: $0.id)
                            },
                            listed: listed)
            }
        }
    }

    /// 섹션 = 모노 올캡 라벨 + 타일 그리드(원본 `gridSection`과 같은 문법).
    private func gridSection(_ label: LocalizedStringKey, tiles: [GridTile],
                             listed: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text(label)
                .reffiType(.sectionLabel)
                // 카테고리 헤더는 §13.5 패스 라벨 언어의 **예외로 로컬라이즈한다**(FREQUENT도 같은 규칙).
                // `.textCase(.uppercase)`가 한국어에서 무동작인 것이지 라벨이 영문으로 남는 게 아니다 —
                // 이 시점의 라벨은 이미 번역된 한국어다(ko: 채소/과일/…). 서체·색만 패스 라벨을 따른다.
                .textCase(.uppercase)
                .foregroundStyle(ReffiColor.ink2)
            LazyVGrid(columns: Self.gridColumns, spacing: ReffiSpace.s2) {
                ForEach(tiles) { tile($0, listed: listed.contains($0.key)) }
            }
        }
    }

    /// 그리드 타일 — 종이 면 + 56pt 실루엣 + 이름(원본 픽커 타일 그대로). 담긴 항목엔 우상단 체크.
    /// 이름은 사전 표제어라 길 수 있어 말줄임보다 축소를 먼저 쓴다(원본과 같은 0.8).
    private func tile(_ item: GridTile, listed: Bool) -> some View {
        Button {
            // key는 이미 matchKey다 — 사전 항목이면 그대로 캐논으로 넘기고, 사전 밖 이름이면 nil로 둬
            // store가 이름 기준으로 폴백하게 한다(`dismissKey`와 같은 판별). 이름 역조회를 쓰면 같은
            // 표기를 공유하는 다른 항목에 붙을 수 있다.
            add(name: item.name,
                canonicalID: IngredientLexicon.shared.entry(id: item.key) != nil ? item.key : nil,
                glyph: item.glyph)
        } label: {
            VStack(spacing: ReffiSpace.s1) {
                PaperSilhouette(glyph: item.glyph, fresh: .fresh)
                    .frame(width: 56, height: 56)
                Text(verbatim: item.name)
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, ReffiSpace.s2)
            .padding(.horizontal, ReffiSpace.s1)
            .frame(maxWidth: .infinity, minHeight: 44)   // §7.3 터치 타깃
            .background {
                // 종이 시드는 `ReffiHash.stable` — `String.hashValue`는 런치마다 시드가 바뀌어 같은 타일이
                // 매번 다른 종이결로 뜨고 스크린샷 회귀가 불가능해진다(요리 아이콘 색과 같은 유틸을 공유한다).
                let s = PaperRect(cornerRadius: ReffiRadius.md,
                                  seed: Int(ReffiHash.stable(item.key) % 4))
                // 면색은 `receipt` — 원본 타일의 인라인 값 oklch(0.985, 0.004, 90)이 곧 이 토큰이고,
                // 같은 시트의 noMatchCard도 receipt라 시트 안 흰 종이가 한 토큰으로 통일된다.
                s.fill(ReffiColor.receipt).paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
            }
            .overlay(alignment: .topTrailing) {
                ReffiIcon.check.reffi(11, .bold)
                    .foregroundStyle(ReffiColor.blueDark)
                    .padding(ReffiSpace.s1)
                    .opacity(listed ? 1 : 0)
                    .scaleEffect(listed ? 1 : 0.6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        // 라벨이 담김 상태를 직접 말한다 — `.isSelected` 트레잇만으로는 "사과, 선택됨, 버튼 / Add 사과"
        // 처럼 라벨과 상태가 어긋나 읽힌다. 검색 결과 타일도 이 함수를 쓰므로 수정 지점은 여기 하나다.
        .accessibilityLabel(listed ? Text("Added \(item.name)") : Text("Add \(item.name)"))
        .accessibilityAddTraits(listed ? [.isButton, .isSelected] : .isButton)
    }

    /// 담기 — **그리드 타일·결과 행 공통**. 탭을 뷰에서 미리 막지 않고 **항상 store로 보낸다**:
    /// 이미 수동으로 담긴 것이면 `addToBuy`가 false를 돌려 자연 no-op이고, 파생 제안으로만 떠 있던
    /// 품목이면 여기서 수동 항목이 되어 그 제안을 흡수한다. 뷰가 `listed`로 게이팅하면 흡수 경로가
    /// UI에서 영영 도달 불가해진다(통합 보고서 §8.3 해소).
    private func add(name: String, canonicalID: String?, glyph: FoodGlyph) {
        let added = withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.addToBuy(name: name, canonicalID: canonicalID, glyph: glyph)
        }
        if added { addHaptic += 1 }
    }

    /// 검색 결과 — 원본 픽커와 같은 **같은 타일 그리드**다(영수증 리스트가 아니다). 한 시트 안에서
    /// 타이핑 전후로 시각 언어가 갈리면 안 된다: 쿼리는 배열을 *거르는* 조작이지 다른 화면으로 가는
    /// 조작이 아니고, 결과 타일은 `tile(_:listed:)`를 그대로 재사용해 표현·접근성·담기 규칙이 한 곳이다.
    private func searchGrid(_ hits: [IngredientLexicon.Entry]) -> some View {
        let listed = store.toBuyKeys      // 그리드당 한 번만 — 타일마다 파생 목록을 다시 계산하지 않게
        let tiles = hits.map {
            GridTile(id: "search-\($0.id)", name: $0.displayName,
                     glyph: FoodGlyph(rawValue: $0.glyph) ?? .generic, key: $0.id)
        }
        return LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
            LazyVGrid(columns: Self.gridColumns, spacing: ReffiSpace.s2) {
                ForEach(tiles) { tile($0, listed: listed.contains($0.key)) }
            }
        }
    }

    private var noMatchCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("No match").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Try another name.").reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .receiptSurface(elevated: .flat)
    }
}
