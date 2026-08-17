import SwiftUI

/// 사야 할 식재료 — 자주 쓰는데(이력) 지금 냉장고에 없는 항목이 자동으로 채워지고, 습관이 못 잡는 품목은
/// 하단 "Add item"으로 직접 담는다(§13.5 To buy 예외 — **재고 추가가 아니라 장보기 메모**다).
/// Bought = 시트 없이 **즉시 재입고** — 직전 이력 스냅샷(보관·구매처·수량, 냉동이었다면 냉장으로)과
/// 사전 기본 기한으로 바로 store에 채워 넣는다(§13.6 재입고 경로 — AddIngredientSheet 의존 없음).
///
/// **커버 크롬(헤더·닫기)을 갖지 않는 임베더블 본문**이다 — 냉장고 To buy 탭이 이 뷰를 그대로 얹고,
/// 풀스크린 커버가 필요한 자리는 아래 `ShoppingListView`가 헤더만 씌운다. 목록·재입고·빼기·검색 시트
/// 같은 실제 동작은 **여기 한 곳**에 산다(두 표면이 같은 규칙을 각자 적으면 조용히 갈린다).
struct ShoppingListContent: View {
    /// 하단 도킹 CTA 아래로 남길 여백 — 커버는 기본값(`s3`), 떠 있는 캡슐 네비가 있는 탭 패인은
    /// 그 자리(`ReffiChrome.navReserve`)를 비운다.
    var ctaBottomInset: CGFloat = ReffiSpace.s3

    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var restockHaptic = 0
    /// 메모에서 빼기는 §7.6의 **판정·확정**이다(Ate/Tossed와 같은 결의 "이번엔 안 사기") — `.impact(.light)`.
    /// 19차에 라벨이 "Skip"에서 조용한 ✕로 바뀌었지만 **햅틱은 그대로다**: §7.6의 매핑 기준은 어포던스가
    /// 아니라 **의미**이고, 부르는 액션(`store.skipBuy`)이 그대로라 의미도 그대로다.
    /// 사서 채우는 Bought 쪽이 성공 완료(`.success`)이므로 같은 행의 두 컨트롤이 다른 의미로 갈린다.
    @State private var skipHaptic = 0
    @State private var showSearch = false
    #if DEBUG
    /// `-toBuy.search` 자동 오픈을 **런치당 한 번**으로 묶는다 — 탭 패인은 커버와 달리 오갈 때마다
    /// `onAppear`가 다시 도는데, 그때마다 시트가 튀어나오면 QA 세션에서 다른 탭을 볼 수가 없다.
    @State private var searchArgHandled = false
    #endif

    private typealias Row = (name: String, glyph: FoodGlyph, manual: Bool, key: String)

    /// 화면에 세우는 목록 — **직접 담은 것만**(2026-08 owner decision). 이력에서 파생된 "자주 쓰는데
    /// 떨어진 것" 제안 구역을 걷어냈다: 장보기 메모는 내가 적은 것이어야 하고, 앱이 추측해 채워 넣은
    /// 줄이 그 위에 섞이면 목록이 내 것이 아니게 된다.
    ///
    /// 걸러 내는 자리를 **여기(뷰)로 잡은 이유**는 `store.toBuy`의 파생 절반이 아직 살아 있어야 하기
    /// 때문이다 — 흡수 의미론(수동이 같은 키의 제안을 먹는다)·`skipBuy`의 두 갈래·로케일 매칭이 전부
    /// 그 절반 위에서 검증되고 있고, 덱의 "부족 재료 담기"(`addMissingToBuy`)가 그 규약을 그대로 탄다.
    /// 모델을 잘라내면 그 계약이 함께 무너지므로 표시 층에서만 좁힌다.
    private var items: [Row] { store.toBuy.filter(\.manual) }

    var body: some View {
        ScrollView {
            // 헤드라인 ↔ 카드는 s3(12) — 위의 탭 행과는 s5(24, `FridgeView.fridgeHeader`가 준다)다.
            // 2:1이라 헤드라인이 **아래 카드에 붙어** 읽힌다(제목은 자기가 이름 붙이는 것 쪽에 살아야 한다).
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                headline
                if items.isEmpty {
                    emptyCard
                } else {
                    listCard
                }
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.bottom, ReffiSpace.s6)
        }
        // 직접 담기 진입은 목록 꼬리가 아니라 화면 하단에 도킹한다(§13.5) — 목록이 짧든 길든 같은
        // 자리에 있고, 커버·시트·메인이 공유하는 하단 CTA 관례와 어긋나지 않는다.
        .dockedCTA(over: ReffiColor.canvas, bottomInset: ctaBottomInset) { addItemButton }
        .sensoryFeedback(.success, trigger: restockHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: skipHaptic)
        .sheet(isPresented: $showSearch) { ToBuySearchSheet() }
        #if DEBUG
        // `-toBuy.search` — 검색 시트 자동 오픈(스크린샷·QA용). 탭 착지 자체는 `FridgeView`가 한다.
        // 탭 전환·커버 전환과 같은 프레임에 시트를 올리면 프레젠테이션이 씹히므로 전환 뒤로 미룬다.
        .onAppear {
            guard !searchArgHandled,
                  ProcessInfo.processInfo.arguments.contains("-toBuy.search") else { return }
            searchArgHandled = true
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

    /// 패인 헤드라인 — **영수증 카드 밖**에 선다. 이 화면이 무엇인지는 카드 안의 캡션이 아니라
    /// 카드를 이름 붙이는 제목이 말해야 한다(카드 안에 있으면 목록의 첫 줄처럼 읽힌다).
    ///
    /// role이 `.heading`(24)인 근거는 **구조 층위**다. §3.2의 역할 정의가 그대로 답이다:
    /// `display`=워드마크(화면 제목 "Fridge") · `heading`=제목 · `subhead`=소제목·**카드 이름**.
    /// 이건 카드 하나가 아니라 **패인 전체**를 이름 붙이는 제목이라 `heading`이고, History의
    /// "Tally · past 30 days"가 `subhead`인 것과 어긋나지 않는다 — 그건 카드 **안**에서 그 카드를
    /// 이름 붙이는 줄이라 한 층 아래다. 즉 둘은 같은 규칙의 다른 층이다(display 34 → heading 24 → subhead 18).
    ///
    /// `subhead`(18)를 쓰지 않은 실질적 이유도 있다: 빈 상태 카드의 제목이 이미 `subhead`라,
    /// 헤드라인까지 18이면 "Grocery memo" 바로 아래 "Nothing on the list"가 같은 굵기로 붙어
    /// 어느 쪽이 제목인지가 사라진다.
    private var headline: some View {
        Text("Grocery memo")
            .reffiType(.heading)
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    /// 목록 카드 — 구역도 캡션도 하나뿐이다. 옛 이력 제안 구역("Ran out, based on what you use often")과
    /// 두 구역을 가르던 절취선(`ReffiRule(.ticket)`)은 16차에, 카드 안 `Added by you` 캡션은 17차에
    /// 사라졌다 — 카드 밖 헤드라인이 그 이름표 역할을 가져갔고, 캡션이 남으면 제목이 두 번 선다.
    private var listCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            ForEach(items, id: \.key) { row($0) }
        }
        .receiptSurface()
    }

    /// 목록 한 줄 — **라벨 붙은 알약 하나 + 조용한 아이콘 하나**다(19차).
    ///
    /// 라벨이 "Add"가 아니라 **"Bought"**인 이유는 이 화면이 장보기 메모이기 때문이다. "Add"는 앱이
    /// 무엇을 하는지(재고에 넣는다)를 말하고, 사용자가 방금 한 일은 **샀다**는 것이다. 메커니즘이 아니라
    /// 행위를 라벨에 세운다 — 동작(`restock`)은 그대로고 바뀐 건 이름뿐이다.
    ///
    /// 반대쪽이 "Skip" 알약에서 **면 없는 ✕**로 내려온 이유는 위계다. 알약 둘이 나란히 서면 "사기"와
    /// "안 사기"가 같은 무게로 읽히는데, 이 행에서 사용자가 실제로 누르는 건 압도적으로 앞쪽이다.
    /// 빼기는 늘 닿을 수 있되 먼저 눈에 들어오면 안 되는 정리 동작이라, `QuietButton`이 정의한
    /// **면 없는 보조 액션** 문법(§13.5)으로 내리고 종이 면 하나를 행에서 걷어냈다.
    /// 확인 다이얼로그는 두지 않는다 — §7.6이 확인을 요구하는 파괴는 "삭제·초기화 **확정**"(계정·전체
    /// 초기화·재료/레시피 삭제)이고, 이건 메모 한 줄을 내리는 것이라 이력도 재고도 건드리지 않으며
    /// 같은 이름을 다시 담으면 원상 복구된다. 되돌리기 비용이 한 번의 탭인 동작에 다이얼로그를 세우면
    /// 정리가 결심이 된다.
    private func row(_ item: Row) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: item.glyph, fresh: .fresh)
                .frame(width: ReffiFoodIcon.row, height: ReffiFoodIcon.row)
            Text(verbatim: item.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
            Spacer()
            // 두 컨트롤 사이만 **s2(8)** — §7.3이 정한 인접 탭 타깃의 최소값이다. ✕는 44pt 히트 안에
            // 14pt 글리프라 좌우로 15pt의 투명 여백을 스스로 갖고 있어, 눈에 보이는 간격은 8+15 ≈ s5(24)로
            // 앉는다. 바깥 s3(12)를 그대로 물려주면 체감 27이 되어 ✕가 행에서 떨어져 나온 조각으로 읽힌다.
            // 바깥 s3은 실루엣↔이름 쪽에 그대로 남는다(영수증 행의 읽는 리듬은 안 건드린다).
            HStack(spacing: ReffiSpace.s2) {
                Button {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        restock(name: item.name, glyph: item.glyph)
                    }
                } label: {
                    Text("Bought")
                        .reffiType(.pillLabel)
                        .fixedSize()   // 이름 열이 길어도 라벨은 꺾이지 않는다 — 폭 경합에선 이름이 접힌다
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
                .accessibilityLabel(Text("Bought \(item.name)"))
                .accessibilityHint(Text("Puts it back in the fridge and clears it from the memo."))
                Button {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        store.skipBuy(key: item.key)
                    }
                    skipHaptic += 1   // §7.6 판정·확정 = .impact (Bought의 .success와 짝)
                } label: {
                    // 글리프는 정본 `ReffiIcon.close`(x) 그대로 — 새 글리프를 만들지 않는다.
                    // 시각 14pt / 히트 44×44로 갈라 §7.3을 채운다(`PaperCloseButton`이 40/44로 쓰는 그 분리다).
                    ReffiIcon.close.reffi(14, .bold)
                        .foregroundStyle(ReffiColor.ink2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                // 면이 없는 보조 액션이라 `QuietButton`과 같은 프레스(0.97)를 쓴다 —
                // `.paperPress`(0.96)는 종이 면이 눌리는 감각이라 면 없는 글리프엔 근거가 없다.
                .buttonStyle(.reffiPress)
                .accessibilityLabel(Text("Remove \(item.name) from the memo"))
                .accessibilityHint(Text("Takes it off the list without buying it."))
            }
        }
    }

    /// 직접 담기 진입 — 하단 도킹 CTA(`dockedCTA`)로 `PaperButton`을 쓰되 `secondary`다: 이 화면의 1차
    /// 행동은 행마다의 파란 Bought(재입고)라, 파란 와이드 버튼이 그 위계를 뒤집으면 안 된다.
    private var addItemButton: some View {
        PaperButton(title: "Add item", kind: .secondary, seed: 3) { showSearch = true }
    }

    /// 빈 상태 — 이제 **직접 담은 것이 없을 때** 뜬다(제안 구역이 사라져 목록의 유일한 소스가 수동이다).
    ///
    /// 카피도 함께 바꿨다: 옛 문구("All stocked up" / "Nothing you regularly use has run out.")는
    /// **이력 제안의 언어**였다 — 앱이 소비 이력을 보고 "떨어진 게 없다"고 단언하는 말인데, 그 계산
    /// 결과를 더 이상 이 화면에 세우지 않으므로 그대로 두면 거짓말이 된다. 지금 참인 사실은 하나다:
    /// 아직 아무것도 안 적었다. 그래서 다음 행동(하단 "Add item")을 가리킨다.
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("Nothing on the list").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Tap Add item to jot down what you need.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .receiptSurface(elevated: .flat)
    }
}

/// To buy의 **풀스크린 커버 형태** — 배경 + `CoverHeader`(§14.2)만 씌운 얇은 래퍼이고 본문은
/// `ShoppingListContent`가 전부 그린다. 냉장고에서는 탭이 이 화면을 대신하지만, 커버로 띄워야 하는
/// 진입 경로(딥링크·다른 화면에서의 호출)가 생겼을 때 헤더·닫기 크롬을 다시 조립하지 않게 남겨 둔다.
struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: ReffiColor.blue.opacity(0.5))
            VStack(spacing: 0) {
                CoverHeader(title: "To buy",
                            subtitle: "Restock what you use often",
                            onClose: { dismiss() })
                ShoppingListContent()
            }
        }
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
        // 섹션까지 쌓이는 재료 배열은 스크롤·.large 승격을 전제한다(Frequent가 늘 첫 화면에 온다).
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
            // 그레인도 타일과 같은 대역으로 얹는다 — 바로 아래 타일이 전부 종이결을 갖는데 필드만
            // 매끈하면 같은 시트 안에서 인풋만 다른 재질(플라스틱)로 읽힌다.
            s.fill(ReffiColor.receipt)
                .overlay(PaperGrain(seed: 6, strength: 0.5).clipShape(s))
                .paperEdge(s, tint: ReffiColor.ink.opacity(0.1))
                .compositingGroup()
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
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {   // 그리드 섹션 간격과 같은 값
                // 직접 입력 담기는 **결과 위**에 상시 선다 — 결과가 있어도 사용자가 친 표기가 사전
                // 표제어와 다를 수 있고(브랜드·규격), 결과가 없으면 이 행이 곧 빈 결과의 해법이다.
                directAddRow(trimmedQuery)
                if hits.isEmpty { noMatchCard } else { searchGrid(hits) }
            }
        }
    }

    /// 직접 입력 담기 — **친 그대로** 메모에 담는다(사전에 없어도). 사전 픽커가 닿지 못하는 칸을
    /// 사용자가 손으로 채우는 §13.5 To buy 예외의 마지막 조각이다.
    ///
    /// **타일이 아니라 전폭 행**인 이유: 타일은 74~96pt라 "Fish sauce brand X" 같은 자유 입력이
    /// 곧바로 잘린다. 사용자가 무엇을 담게 되는지는 이 행의 유일한 payload라 잘리면 안 된다.
    ///
    /// **담김 판정은 하되 탭을 막지 않는다** — 그리드와 같은 규약이다(`add(name:...)` 주석 참고):
    /// 뷰가 게이팅하면 파생 제안으로만 있던 품목을 수동으로 흡수하는 경로가 UI에서 도달 불가해진다.
    /// 담긴 상태에서는 타일과 **같은 도장**(`GlyphStamp`)이 찍히고 라벨이 'Added'로 바뀐다.
    private func directAddRow(_ query: String) -> some View {
        // 키 유도는 `appendToBuy`와 **같은 식**이다(캐논 우선, 없으면 소문자 이름) — 축이 갈리면
        // 도장과 실제 담김 판정이 어긋난다.
        let key = IngredientLexicon.shared.canonicalID(for: query) ?? query.lowercased()
        let listed = store.toBuyKeys.contains(key)
        return Button {
            addTyped(query)
        } label: {
            HStack(spacing: ReffiSpace.s3) {
                ReffiIcon.add.reffi(16, .bold).foregroundStyle(ReffiColor.blueDark)
                Text("Add \"\(query)\"")
                    .reffiType(.body)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(2)                      // 긴 자유 입력도 잘리지 않게(두 줄까지)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: ReffiSpace.s2)
                GlyphStamp(icon: ReffiIcon.check, color: ReffiColor.blueDark, size: 13)
                    .opacity(listed ? 1 : 0)
                    .scaleEffect(listed ? 1 : 0.6)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s3)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)   // §7.3 터치 타깃
            .background {
                // 그리드 타일과 같은 종이 문법(면 `receipt` + 옅은 그레인 + 헤어라인).
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 7)
                s.fill(ReffiColor.receipt)
                    .overlay(PaperGrain(seed: 7, strength: 0.6).clipShape(s))
                    .paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                    .compositingGroup()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        // 라벨 문법은 타일과 같다(담김 여부를 라벨이 직접 말한다 — 트레잇만으론 상태가 어긋나 읽힌다).
        .accessibilityLabel(listed ? Text("Added \(query)") : Text("Add \(query)"))
        .accessibilityHint(Text("Adds the name exactly as typed."))
        .accessibilityAddTraits(listed ? [.isButton, .isSelected] : .isButton)
    }

    /// 직접 입력 담기 실행 — 캐논 ID·글리프 해석을 **store에 맡긴다**(사전에 있으면 표제어로 묶이고,
    /// 없으면 이름 매칭 → `.generic`으로 떨어진다). 뷰가 다시 추측하면 규칙이 두 곳으로 갈린다.
    /// 애니메이션·햅틱 규약은 타일 담기(`add`)와 같다. 담긴 뒤에도 **시트는 닫히지 않고 검색어도
    /// 그대로 둔다** — 타일과 같은 연속 추가 UX이고, 남은 검색어 덕에 같은 행이 그 자리에서
    /// '담김' 도장으로 뒤집혀 방금 한 일이 눈에 보인다.
    private func addTyped(_ name: String) {
        let added = withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.addToBuy(name: name)
        }
        if added { addHaptic += 1 }
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
    /// Frequent(빨리 담기 단축키) → 사전 전체를 카테고리로 묶은 섹션(`FoodGlyph.categoryOrder` — 냉장고 필터 칩과 같은 순서 상수).
    /// **의미만 To buy 문맥이다**: 탭은 냉장고 반입이 아니라 `addToBuy`(장보기 메모)고, 시트는 닫히지
    /// 않으며, 이미 담긴 타일에는 결과 행과 같은 체크가 남는다.
    private var pickerGrid: some View {
        let listed = store.toBuyKeys      // 섹션당 한 번만 — 타일마다 파생 목록을 다시 계산하지 않게
        let frequent = store.frequentIngredients().map {
            GridTile(id: "freq-\($0.key)", name: $0.name, glyph: $0.glyph, key: $0.key)
        }
        return LazyVStack(alignment: .leading, spacing: ReffiSpace.s5) {
            if !frequent.isEmpty { gridSection("Frequent", tiles: frequent, listed: listed) }
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
            // 카테고리·Frequent는 **번역되는** 라벨이라 올캡 모노 role을 쓰지 않는다(§3.5) —
            // 한국어에선 `.textCase(.uppercase)`가 무동작이라 올캡이라는 시각 문법이 사라지고
            // 11pt에 자간 1.4만 남는다. 번역되는 섹션 라벨은 caption으로 내린다.
            Text(label)
                .reffiType(.caption)
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
                    .frame(width: ReffiFoodIcon.tile, height: ReffiFoodIcon.tile)
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
                // 셰입 시드는 `% 4`(PaperRect의 지터 표가 4행)이고 **그레인 시드는 해시 전체**다 —
                // 셰입이 4종으로 겹쳐도 반점·섬유결이 칸마다 달라 12칸이 서로 다른 종이 조각으로 읽힌다.
                let h = ReffiHash.stable(item.key)
                let s = PaperRect(cornerRadius: ReffiRadius.md, seed: Int(h % 4))
                // 면색은 `receipt` — 원본 타일의 인라인 값 oklch(0.985, 0.004, 90)이 곧 이 토큰이고,
                // 같은 시트의 noMatchCard도 receipt라 시트 안 흰 종이가 한 토큰으로 통일된다.
                s.fill(ReffiColor.receipt)
                    // 반복되는 소형 면이라 옅게(§13.5 — 드롭다운 0.6·냉장고 카드 0.7과 같은 대역).
                    .overlay(PaperGrain(seed: h, strength: 0.6).clipShape(s))
                    .paperEdge(s, tint: ReffiColor.ink.opacity(0.06))
                    .compositingGroup()   // overlay 블렌드 그레인을 타일 경계에 가둔다
            }
            .overlay(alignment: .topTrailing) {
                // 담김 = **도장 각인**(§13.5). 체크 글리프만 있으면 어느 앱에나 있는 픽커 체크로 읽혀
                // 이 시트에서 브랜드가 사라진다 — D-day 도장과 같은 문법(기울어진 외곽선 + 잉크)으로
                // 찍어, 담긴 칸이 "도장 찍힌 종이"가 되게 한다.
                GlyphStamp(icon: ReffiIcon.check, color: ReffiColor.blueDark, size: 13)
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

    /// 사전에 결과가 없을 때 — "없다"는 사실만 말하고, 해법은 **위의 직접 입력 행**이 쥔다.
    /// 옛 문구("Try another name.")는 이제 나쁜 조언이다: 바로 위에 친 그대로 담는 길이 열려 있는데
    /// 다른 이름을 찾으라고 미는 셈이라, 두 안내가 서로를 부정한다.
    private var noMatchCard: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("No match").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Add it as typed, or try another name.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .receiptSurface(elevated: .flat)
    }
}
