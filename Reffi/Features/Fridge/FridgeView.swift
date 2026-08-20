import SwiftUI
import PhosphorSwift

/// 냉장고 — 전체 재고를 임박순으로 쌓은 "흰 영수증" 스택(§13).
/// 영수증 냉장고의 IA(스택 + 탭→상세 + 히스토리)를 그대로, 비주얼은 Main의 종이컷 언어로.
/// 카드 탭 → Wallet식으로 펼쳐져 상세(구매정보 + Ate/Tossed), 나머지는 하단에 collapse.
///
/// **화면은 상단 탭 셋으로 갈린다**(2026-08): In stock(이 스택) · To buy · History.
/// 옛 요약 두 버튼과 헤더 리포트 버튼이 열던 풀스크린 커버 둘을 탭 패인이 대신한다 — 목적지가
/// 세 개뿐인데 그중 둘을 커버로 감추면 "지금 뭘 보고 있는가"가 화면에 남지 않는다.
struct FridgeView: View {
    /// 현재 탭으로 표시 중인지 — 아니면 본문을 세우지 않는다(`MainView(isActive:)` 선례).
    ///
    /// 루트는 세 패인을 **모두 살려 둔다**(메인의 물리 더미·되돌리기 창이 탭 전환에 파괴되지 않게).
    /// 그 대가로 가려진 이 화면의 body가 store 변이마다 다시 평가돼, 리퀴드글래스 블롭 세 장과
    /// 영수증 카드 수십 장이 **보이지도 않는 채로** 매번 다시 그려졌다(판정 한 번에 세 화면분).
    /// 그래서 상태(`@AppStorage`·선택·필터)와 시트 프레젠테이션은 그대로 살려 두고 **그리는 것만**
    /// 끊는다 — 아래 body의 게이트는 ZStack 안쪽 콘텐츠에만 걸리고, 모디파이어 체인(시트·훅)은
    /// 활성 여부와 무관하게 그대로 붙어 있다. 포기하는 것은 스크롤 위치 하나다.
    var isActive: Bool = true
    /// 바깥에서 지정하는 착지 패인 — 덱의 담기 흐름이 "보기"로 끝나면 `.toBuy`가 들어온다.
    /// **소비하면 곧바로 nil로 되돌린다**(1회성 신호): 값이 남아 있으면 사용자가 손으로 탭을 옮긴
    /// 다음에도 같은 요청이 다시 살아나 패인이 되돌아간다.
    @Binding var pendingPane: FridgeTab?

    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @Namespace private var ns
    @State private var selectedID: Ingredient.ID?
    /// 상단 탭 — 기본은 In stock. QA 인자(`-toBuy`·`-toBuy.search`·`-showHistory`)는 그 목적지 탭으로 착지.
    @State private var tab: FridgeTab = {
        #if DEBUG
        return FridgeTab.initial(from: ProcessInfo.processInfo.arguments)
        #else
        return .stock
        #endif
    }()
    @State private var editing: Ingredient?
    /// 지금 열린 종이 드롭다운 — **불리언 두 개가 아니라 하나의 상태**다. `DropdownAnchorKey`는
    /// 화면당 한 개 열림을 전제하므로(둘이 동시에 앵커를 올리면 팝업이 엉뚱한 칩 아래에 뜬다),
    /// "동시에 열림"이라는 표현 불가능한 상태를 타입에서 지운다. 세션 한정.
    @State private var openMenu: OpenMenu = .none
    /// 판정(Ate/Tossed) 햅틱 카운터 — `MainView.decisionHaptic`과 동일 트리거·weight(룰⑦: 같은 의미는 같은 햅틱).
    @State private var decisionHaptic = 0
    /// 펼친 영수증의 실측 높이 — 스크롤 뷰가 콘텐츠보다 커지지 않게 묶는 캡(0이면 미측정 = 캡 없음).
    /// 글자 크기·재료가 바뀌면 다시 측정된다.
    @State private var receiptHeight: CGFloat = 0

    /// 정렬·보기 선택 — 세션을 넘어 유지(리서치: 정렬 선택은 기억되어야 재방문 비용이 준다).
    @AppStorage("fridge.sort") private var sortRaw: String = FridgeSort.expiry.rawValue
    @AppStorage("fridge.compact") private var compact = false
    /// 카테고리 필터(nil = 전체) — **영속화하지 않는다**. 정렬은 재방문 비용을 줄이지만 필터는
    /// "지금 이 순간 좁혀 보기"라, 다음 실행에 살아 있으면 재고가 사라진 것처럼 보인다(세션 한정).
    @State private var activeCategory: String?
    /// 직전에 본 전체 재고 id — 이번 변화에서 **새로 나타난** 재료를 가려내는 기준(필터 자동 해제).
    @State private var knownIDs: Set<Ingredient.ID> = []

    /// 하단 스택을 위로 미는 동안의 실시간 변위 — 손을 따라가는 **직접 조작**이라 상태가 아니라
    /// 제스처에 매달아 둔다. `@State`로 두면 스크롤이 제스처를 가로채 `onEnded`가 오지 않는 경로에서
    /// 값이 그대로 굳는다(이 스택은 `simultaneousGesture`라 그 경로가 실제로 있다) — `@GestureState`는
    /// 손을 떼든 취소되든 스스로 0으로 돌아온다. 되돌아가는 길만 안착 스프링을 태운다(§7.5 settle).
    @GestureState(resetTransaction: Transaction(animation: ReffiMotion.settle))
    private var stackLift: CGFloat = 0
    /// 스와이프로 닫은 시각 — 같은 터치가 이어서 던지는 버튼 탭을 한 번 삼키는 데 쓴다(아래 `bottomStack`).
    @State private var stackDismissedAt: Date?

    private let cardHeight: CGFloat = 170   // 길게 늘려 슬립·틸트로 생기는 측면 빈틈을 덮음
    private let overlap: CGFloat = -60   // advance(=높이+겹침)=110 — 이름 안전 구간은 기본~xxxLarge 한정(AX는 `showsCompactList`)
    private let cardInset: CGFloat = 18   // 페이지 마진 위 추가 인셋 — 영수증 폭 좁힘(가운데)

    /// 스택 보기에 한 번에 세우는 카드 수 — 첫 화면에도, "더 보기" 한 번에도 같은 값.
    ///
    /// 이 스택은 `LazyVStack`으로 못 바꾼다: 음수 spacing으로 겹치고, `zIndex`로 앞뒤를 정하고,
    /// `matchedGeometryEffect`로 펼침과 이어지는데 셋 다 **형제가 다 서 있는 것**을 전제한다.
    /// 그래서 지연 생성 대신 **세우는 장수**에 상한을 둔다 — 재고엔 상한이 없어서, 200개를 담은
    /// 사람은 냉장고를 열 때마다 영수증 200장(각각 종이 셰입 + 실루엣 Canvas)을 한 프레임에
    /// 실체화했다. 30장은 기본 글자 크기 뷰포트의 세 배 남짓이라 스크롤로 도달할 여유가 있다.
    private static let stackPage = 30

    /// 지금 스택에 세운 카드 수 — "더 보기"가 한 페이지씩 늘린다(History 타임라인과 같은 문법).
    @State private var stackShown = FridgeView.stackPage

    private var sort: FridgeSort { FridgeSort(rawValue: sortRaw) ?? .expiry }

    /// 접힌 스택 대신 간편 행으로 가야 하는가 — 사용자 토글 **또는** 접근성 글자 크기.
    ///
    /// 스택은 카드 한 장의 전진량이 110pt(높이 170 + 겹침 -60)로 **고정**인데, 그 안의 두 줄
    /// (D-day 도장 행 + 이름 행)은 글자 크기를 따라 자란다. 기본 크기에서 이름 행은 y≈60~106에
    /// 앉아 4pt 여유로 안전하지만 AX1부터 110을 넘겨 **이름이 다음 카드 밑으로 들어간다**.
    /// 전진량을 글자에 맞춰 키우면 카드 한 장이 화면을 다 먹어 "쌓인 더미"라는 메타포 자체가 없어지므로,
    /// 접근성 크기에서는 겹침을 포기하고 겹치지 않는 간편 행(§7.3 잘림 금지)으로 간다.
    private var showsCompactList: Bool { compact || typeSize.isAccessibilitySize }

    /// 이 프레임의 목록 — **body 진입부에서 한 번만** 만들어 아래로 흘린다.
    ///
    /// `sortedItems`는 호출마다 전체 재고를 다시 정렬하고 `items`는 그 위에 필터를 다시 태우는데,
    /// 예전엔 배경 어컨트·펼침 선택·컨트롤 한 줄·카테고리 드롭다운·목록·두 개의 `onChange`가
    /// 각자 그것을 불러 한 body에 정렬이 예닐곱 번 돌았다(재고가 늘수록 그대로 비례한다).
    private struct ListDigest {
        /// 필터 **이전**의 전체 표시 목록(정렬 완료) — 카테고리 개수·필터 자동 해제 판정의 모수.
        let sorted: [Ingredient]
        /// 실제로 화면에 세우는 목록(정렬 + 카테고리 필터).
        let items: [Ingredient]
        /// 재고에 실제로 있는 카테고리 + 개수(캐논 순서).
        let categories: [FridgeCategoryFilter.Bucket]

        init(sorted: [Ingredient], category: String?) {
            self.sorted = sorted
            items = FridgeCategoryFilter.apply(category, to: sorted)
            categories = FridgeCategoryFilter.buckets(of: sorted)
        }
    }

    /// 표시 순서 — 기본은 임박순(§8.1). 동률은 이름순으로 결정적. 필터 이전의 전체 재고다
    /// (칩 카운트·"in stock" 숫자는 항상 이 목록 기준 — 필터를 켜도 재고 총량은 변하지 않는다).
    ///
    /// **body는 이 프로퍼티를 직접 부르지 않는다**(위 `ListDigest`가 한 번 받아 간다) — 여기 남은
    /// 것은 지연 클로저·액션처럼 **이벤트 시점의 재고**를 봐야 하는 경로를 위해서다.
    private var sortedItems: [Ingredient] {
        switch sort {
        case .expiry:   store.sorted
        case .freshest: store.sorted.reversed()
        case .recent:   store.ingredients.sorted {
            $0.boughtDaysAgo != $1.boughtDaysAgo
                ? $0.boughtDaysAgo < $1.boughtDaysAgo : $0.daysLeft < $1.daysLeft
        }
        }
    }
    /// 실제 표시 목록 — 정렬 후 카테고리 필터 적용(위 `sortedItems`와 같은 이유로 **이벤트 시점** 전용).
    private var items: [Ingredient] {
        FridgeCategoryFilter.apply(activeCategory, to: sortedItems)
    }
    /// 드롭다운 옵션 — `nil`(전체) + 재고에 있는 카테고리. `String?`을 그대로 값 타입으로 쓴다:
    /// 필터 상태(`activeCategory`)가 이미 `String?`이라 별도 래퍼를 만들면 변환이 한 겹 더 생긴다.
    private func categoryOptions(_ list: ListDigest) -> [String?] { [nil] + list.categories.map(\.category) }
    /// 배경 accent — 패인마다 다르다. 옛 커버 둘이 각자 갖고 있던 색을 탭에서도 그대로 유지한다
    /// (To buy = blue · History = 낭비율 색). 표면이 바뀌면 배경도 함께 바뀌어야 탭 전환이 읽힌다.
    private func accent(_ list: ListDigest) -> Color {
        switch tab {
        case .stock:   list.items.first?.freshness.main ?? ReffiColor.fresh
        case .toBuy:   ReffiColor.blue.opacity(0.5)
        case .history: HistoryContent.rateColor(store.wasteRate).opacity(0.6)
        }
    }
    private func selected(in list: ListDigest) -> Ingredient? { list.items.first { $0.id == selectedID } }
    private var motion: Animation? { ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion) }

    /// 영수증 틸트 — 평면(Z) 회전 ±4° 랜덤(결정적 의사난수). 위아래로 제각각 기울어 더미 느낌.
    private func tilt(_ i: Int) -> Double {
        [4, -3, 2, -4, 3, -2, 1][i % 7]
    }
    /// 가로 삐져나옴 — 좌우로 제각각 비져나옴(틸트와 위상 달라 상관 없음).
    private func slip(_ i: Int) -> CGFloat {
        [14, -12, 16, -10, 12, -16, 10][i % 7]
    }

    var body: some View {
        // 이 프레임의 목록을 여기서 **한 번만** 만든다(위 `ListDigest` 주석) — 아래 조각들은 전부
        // 이 한 장을 받아 쓴다. 훅(`onChange`)까지 같은 장을 보므로 판정 기준도 화면과 어긋나지 않는다.
        let list = ListDigest(sorted: sortedItems, category: activeCategory)
        let sel = selected(in: list)
        return ZStack {
            // 가려진 동안은 **아무것도 세우지 않는다**(위 `isActive` 주석) — 상태는 그대로 살아 있고,
            // 활성화되는 프레임에 이 서브트리가 통째로 다시 선다.
            if isActive {
                LiquidGlassBackground(accent: accent(list))
                if let sel {
                    // 펼친 영수증은 **화면을 통째로** 가져간다(탭 행까지 덮는다) — 상세는 이 화면의 유일한
                    // 1차 표면이고, 판정(Ate/Tossed)까지 한 화면에서 끝나야 한다(§7.3 잘림 금지).
                    expanded(sel, in: list)
                } else {
                    VStack(spacing: 0) {
                        fridgeHeader
                        pane(list)
                    }
                }
                // 하단 마스크 — 화면 끝(홈 인디케이터 포함)까지 크림으로 덮어, 떠 있는 네비 밑으로
                // 카드가 새지 않게. VStack이 화면을 꽉 채우고 safe area를 무시 → 바닥 정렬이 물리적 끝에 닿음.
                // **그냥 스크롤하는 패인(In stock·History)에만** 건다: 실측으로 History 타임라인 행이 캡슐 네비
                // 유리 뒤에서 반쯤 읽히는 잔상이 그대로 보였다(스크린샷 03-history 최초 캡처). To buy는 도킹
                // CTA가 이미 같은 자리에 불투명 면을 깔기 때문에, 여기서 또 덮으면 그 버튼이 마스크 밑에 깔린다.
                if sel == nil, tab != .toBuy {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        LinearGradient(colors: [ReffiColor.canvas.opacity(0), ReffiColor.canvas],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 72)             // 위쪽: 카드가 부드럽게 사라짐
                        ReffiColor.canvas.frame(height: 70) // 아래쪽: 네비 밑은 완전한 크림(잔상 제거)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
        }
        // 바깥에서 온 착지 요청 — 펼친 영수증과 열린 드롭다운을 먼저 정리한다. 상세는 탭 행까지
        // 덮는 전체 화면이라(§13.5), 그대로 두면 탭만 바뀌고 화면은 영수증에 머문다.
        .onChange(of: pendingPane) { _, requested in
            guard let requested else { return }
            pendingPane = nil
            selectedID = nil
            closeMenus()
            tab = requested
        }
        // 드롭다운이 열린 동안 뒤 화면은 보조기술에서 사라진다 — 바깥을 건드리면 어차피 닫히는 면이라
        // (아래 투명 탭 캐처), 소리로만 배경을 훑을 수 있는 상태는 모델이 어긋난 것이다.
        // **오버레이보다 먼저** 걸어야 팝업 자신이 함께 가려지지 않는다.
        .accessibilityHidden(openMenu != .none)
        // 종이 드롭다운(카테고리·정렬) — 트리거 칩 앵커 아래에 떠서(ScrollView 클리핑 밖, zIndex dropdown)
        // 전체 콘텐츠 위를 덮는다. 딤 없는 투명 탭 캐처가 바깥 탭을 받아 닫는다(가벼운 드롭다운, 모달 아님 — scrim 금지).
        // **열린 트리거만 앵커를 올리므로**(각 트리거의 `anchorPreference`가 조건부) 여기 도착하는 앵커는
        // 항상 지금 열린 그 칩의 것이다 — 두 칩이 상시 발행하면 마지막 것이 이겨 팝업이 엉뚱한 자리에 뜬다.
        .overlayPreferenceValue(DropdownAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if openMenu != .none, let anchor {
                    let rect = proxy[anchor]
                    let width: CGFloat = 220
                    // 정렬 칩은 행 오른쪽 끝, 카테고리 칩은 왼쪽 끝에 산다 — 팝업도 그 변에 맞춰 붙인다
                    // (반대편에 붙이면 트리거에서 먼 쪽으로 열려 어느 칩이 열었는지가 흐려진다).
                    let leading = openMenu == .category
                    let rawX = leading ? rect.minX : rect.maxX - width
                    let x = min(max(ReffiGrid.margin, rawX),
                                max(ReffiGrid.margin, proxy.size.width - width - ReffiGrid.margin))
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { closeMenus() }
                            // 이름 없는 투명 면 — 커서에 걸리면 정체불명의 요소가 하나 는다.
                            // 바깥 탭의 접근성 대응은 팝업의 escape 액션(`onDismiss`)이 맡는다.
                            .accessibilityHidden(true)
                        Group {
                            switch openMenu {
                            case .category:
                                PaperDropdown(options: categoryOptions(list),
                                              selected: activeCategory,
                                              label: { categoryOptionLabel($0, in: list) },
                                              seed: 9,
                                              onDismiss: { closeMenus() }) { category in
                                    selectCategory(category)
                                    closeMenus()
                                }
                            case .sort:
                                PaperDropdown(options: FridgeSort.allCases,
                                              selected: sort,
                                              label: { $0.label },
                                              seed: 5,
                                              onDismiss: { closeMenus() }) { newSort in
                                    sortRaw = newSort.rawValue
                                    closeMenus()
                                }
                            case .none:
                                EmptyView()
                            }
                        }
                        .frame(width: width)
                        .offset(x: x, y: rect.maxY + ReffiSpace.s1)
                        .transition(.scale(scale: 0.92, anchor: leading ? .topLeading : .topTrailing)
                            .combined(with: .opacity))
                    }
                    .zIndex(ReffiZ.dropdown)
                }
            }
        }
        .reffiFeedback(.impact(weight: .light), trigger: decisionHaptic)
        // 필터 안전장치 — 판정은 전부 `FridgeCategoryFilter.resolved`(순수 함수, 유닛 테스트 대상)가 하고
        // 여기선 상태만 옮긴다. 카테고리가 비었을 때뿐 아니라 **필터 밖 재료가 새로 들어왔을 때**도
        // 전체로 풀어, 추가한 결과가 화면에서 사라지는 일이 없게 한다.
        // 감지 키는 id가 아니라 `changeKey`(id + 카테고리)다 — 이름을 고치면 글리프·카테고리가 다시
        // 파생되는데 id는 그대로라, id만 보면 "필터 켠 카테고리가 비었는데 훅이 안 도는" 갇힘이 생긴다.
        // `initial: true`로 첫 표시에서 knownIDs를 채운다(그 시점 activeCategory는 nil이라 부작용 없음).
        .onChange(of: list.sorted.map(FridgeCategoryFilter.changeKey(of:)), initial: true) { _, _ in
            let current = Set(list.sorted.map(\.id))
            let added = current.subtracting(knownIDs)
            knownIDs = current
            let next = FridgeCategoryFilter.resolved(activeCategory, in: list.sorted, added: added)
            if next != activeCategory {
                withAnimation(motion) { activeCategory = next }   // 값이 실제로 바뀔 때만 — 재진입 안전
            }
        }
        // 펼쳐 둔 카드가 표시 목록 밖으로 밀려나면 선택을 접는다(유령 상세 방지).
        // 위 훅이 필터를 풀면 목록이 넓어지므로, 그 결과까지 반영된 최종 목록을 기준으로 판단한다.
        .onChange(of: list.items.map(\.id)) { _, ids in
            if let id = selectedID, !ids.contains(id) {
                withAnimation(motion) { selectedID = nil }
            }
        }
        // 탭이 갈리면 In stock 전용 상태를 정리한다 — 펼친 영수증이 다른 패인을 보고 온 뒤에도
        // 남아 있으면 돌아오는 순간 유령 상세가 뜨고, 열린 정렬 드롭다운은 앵커를 잃은 채 상태만 남는다.
        .onChange(of: tab) { _, _ in
            selectedID = nil
            if openMenu != .none { closeMenus() }
        }
        .sheet(item: $editing) { IngredientEditView(ingredient: $0) }
        // 자정 경과 — 탭을 띄워둔 채 날이 바뀌어도 D-day 도장·정렬이 갱신되게(메인과 동일 패턴).
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayTick += 1
        }
        #if DEBUG
        // 스크린샷·QA용 런치 인자. 탭 착지(`-toBuy`·`-toBuy.search`·`-showHistory`)는 `tab` 상태의
        // 초기값(`FridgeTab.initial(from:)`)이 이미 정했다 — 여기선 패인 안쪽 상태만 다룬다.
        .onAppear {
            // `-fridgeExpand` — 첫 재료를 바로 펼침(Ate/Tossed 버튼 QA용). 샘플 시드가 늦을 수 있어 지연 재시도.
            if ProcessInfo.processInfo.arguments.contains("-fridgeExpand") {
                selectedID = items.first?.id
                if selectedID == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { selectedID = items.first?.id }
                }
            }
            // `-fridgeExpandSolo` — 재료 1개만 남기고 펼침(하단 스택 없는 레이아웃 QA용).
            if ProcessInfo.processInfo.arguments.contains("-fridgeExpandSolo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    items.dropFirst().forEach { store.toss($0) }
                    selectedID = items.first?.id
                }
            }
            // `-fridge.sortOpen` — 정렬 드롭다운 자동 오픈(스크린샷용).
            if ProcessInfo.processInfo.arguments.contains("-fridge.sortOpen") {
                openMenu = .sort
            }
            // `-fridge.categoryOpen` — 카테고리 드롭다운 자동 오픈(스크린샷용). 둘 다 주면 정렬이 이긴다
            // (한 번에 하나만 열린다 — 아래 대입이 위를 덮지 않도록 순서가 아니라 조건으로 가른다).
            if ProcessInfo.processInfo.arguments.contains("-fridge.categoryOpen"),
               openMenu == .none {
                openMenu = .category
            }
            // `-fridgeEdit` — 첫 재료의 편집 시트 자동 표시(-loadSample과 함께). 시드가 늦으면 지연 재시도.
            if ProcessInfo.processInfo.arguments.contains("-fridgeEdit") {
                editing = items.first
                if editing == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { editing = items.first }
                }
            }
        }
        #endif
    }

    @State private var dayTick = 0   // 자정 리렌더 트리거

    // MARK: 고정 헤더 — 타이틀 + 탭 행. 스크롤 밖이다: 세 패인을 오가는 조작이라 항상 같은 자리에
    // 있어야 하고, 스크롤과 함께 사라지면 "지금 어느 탭인가"라는 유일한 표시를 잃는다.
    private var fridgeHeader: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {   // s3 = 제목-본문 간격
            titleRow
            FridgeTabBar(selection: $tab)
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s5)
        // **탭 행 ↔ 패인의 유일한 경계**다 — 세 패인 모두 자체 상단 패딩이 없으므로(실측 확인)
        // 이 한 값이 셋에 그대로 간다. s4(16)에서 s5(24)로 넓혀 탭이 콘텐츠에서 숨을 쉬게 한다:
        // 탭은 화면의 IA라 아래 목록에 붙어 있으면 목록의 머리처럼 읽힌다.
        .padding(.bottom, ReffiSpace.s5)
    }

    /// 선택된 탭의 본문. To buy·History는 커버에서 쓰던 **같은 콘텐츠 뷰**를 크롬 없이 얹는다 —
    /// 두 표면이 같은 화면을 각자 그리면 규칙이 갈린다. 다른 건 바닥 여백뿐이다(떠 있는 캡슐 네비 몫).
    @ViewBuilder private func pane(_ list: ListDigest) -> some View {
        switch tab {
        case .stock:   stockPane(list)
        case .toBuy:   ShoppingListContent(ctaBottomInset: ReffiChrome.navReserve)
        case .history: HistoryContent(bottomPadding: ReffiChrome.navClearance)
        }
    }

    // MARK: In stock — 접힌 영수증 스택
    private func stockPane(_ list: ListDigest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                let _ = dayTick   // 자정 틱 의존 — 날이 바뀌면 이 서브트리를 재계산
                // 목록 조작 컨트롤은 **한 줄**이다(2026-08 declutter): 재고 수는 타이틀 옆 캡션으로 올라갔고
                // 카테고리 칩 행은 이 줄 왼쪽의 드롭다운 하나로 접혔다. 남은 s5는 "컨트롤 블록 ↔ 콘텐츠"
                // 경계 값 그대로다 — 블록이 두 줄에서 한 줄로 준 것이지 경계의 성격이 바뀐 건 아니다.
                controlRow(list)
                if list.items.isEmpty {
                    emptyState
                } else if showsCompactList {
                    compactList(list)
                } else {
                    stackList(list)
                }
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.bottom, ReffiChrome.navClearance)   // 끝까지 스크롤해도 마지막 카드가 네비 위로 올라오게
        }
    }

    /// 스택 보기 — 겹쳐 쌓인 영수증. **앞 `stackShown`장만** 세우고 나머지는 아래 한 줄이 부른다
    /// (상한을 두는 이유는 위 `stackPage` 주석).
    private func stackList(_ list: ListDigest) -> some View {
        let shown = min(stackShown, list.items.count)
        let remaining = list.items.count - shown
        return VStack(alignment: .leading, spacing: ReffiSpace.s5) {
            VStack(spacing: overlap) {
                ForEach(Array(list.items.prefix(shown).enumerated()), id: \.element.id) { i, ing in
                    // 카드는 **버튼**이다 — 탭 제스처만 얹으면 보조기술에 버튼 트레잇이 서지 않고
                    // (VoiceOver가 "누를 수 있다"고 말할 근거가 없다) 눌림 피드백도 없다.
                    // 겹침·틸트를 만드는 modifier는 버튼 밖에 남긴다: zIndex는 형제 순서를
                    // 정하는 값이라 라벨 안에서는 뜻이 없고, 회전·오프셋은 히트 영역까지 함께 돈다.
                    Button { select(ing) } label: {
                        FridgeCard(ingredient: ing, depth: i, seed: i, height: cardHeight)
                            .matchedGeometryEffect(id: ing.id, in: ns)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.paperPress)
                    .accessibilityHint(Text("Opens details"))
                    .zIndex(Double(i))
                    .padding(.horizontal, cardInset)
                    .rotationEffect(.degrees(tilt(i)))
                    .offset(x: slip(i))
                }
            }
            if remaining > 0 { stackMoreButton(remaining) }
        }
    }

    /// 더 보기 — History 타임라인과 **같은 줄**이다("Show N more"): 다음에 몇 장이 오는지를 문구가
    /// 말해, 누르기 전에 이 아래가 끝인지 아닌지가 읽힌다. 겹친 더미 밖(스택 아래)에 평범한 한 줄로 앉는다.
    private func stackMoreButton(_ remaining: Int) -> some View {
        let step = min(remaining, Self.stackPage)
        // 애니메이션 없이 늘린다(History의 같은 버튼과 동일) — 스프링을 태우면 영수증 서른 장이
        // 한꺼번에 스케일·페이드하며 들어와, 아래로 이어 붙는 목록이 아니라 새 화면처럼 읽힌다.
        return Button { stackShown += Self.stackPage } label: {
            Text("Show \(step) more")
                .reffiType(.checklistItem)
                .foregroundStyle(ReffiColor.blueDark)   // §2.6 종이 위 파랑 잉크는 blueDark
                .frame(maxWidth: .infinity, minHeight: ReffiChrome.tapMin)   // §7.3 최소 터치 타깃
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }

    /// 간편보기 — 틸트·겹침 없는 납작한 영수증 행. 훑어보기(스캔)에 최적화.
    private func compactList(_ list: ListDigest) -> some View {
        LazyVStack(spacing: ReffiSpace.s2) {
            ForEach(list.items) { ing in
                Button { select(ing) } label: {
                    FridgeCompactRow(ingredient: ing)
                        .matchedGeometryEffect(id: ing.id, in: ns)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
                .accessibilityHint(Text("Opens details"))
            }
        }
        .padding(.horizontal, cardInset)
    }

    // MARK: 펼친(Wallet) 레이아웃
    private func expanded(_ sel: Ingredient, in list: ListDigest) -> some View {
        let others = list.items.filter { $0.id != sel.id }
        return VStack(spacing: 0) {
            doneBar
            // 영수증만 스크롤하고 판정 버튼(Ate/Tossed)은 스크롤 **밖**에 둔다 — 이 화면의 유일한 1차 액션이라
            // 어떤 글자 크기·재고 수에서도 잘리면 안 된다(§7.3). 버튼을 스크롤 콘텐츠 안에 넣으면 하단 스택(≤132)과
            // 네비 자리 예약(`ReffiChrome.navReserve`)이 먹은 만큼 뷰포트가 좁아져 기본 글자 크기에서도 라벨이 잘렸다.
            //
            // "영수증 끝에서 20 아래 부착"이라는 의도는 그대로 유지한다:
            //   ① 스크롤 밖 하단 s3(12) + ② 버튼 상단 s2(8) = 20 — 간격을 스크롤 밖에 둬서
            //      영수증이 넘쳐 스크롤돼도 시각 간격 20이 변하지 않는다.
            //   ③ 스크롤 높이를 콘텐츠 높이(receiptHeight)로 묶어, 영수증이 뷰포트보다 짧아도
            //      스크롤 뷰가 남는 높이를 먹고 늘어나지 않게 한다(= 영수증과 버튼 사이가 벌어지지 않음).
            ScrollView {
                ExpandedFridgeCard(ingredient: sel, onEdit: { editing = sel })
                    .matchedGeometryEffect(id: sel.id, in: ns)
                    .contentShape(Rectangle())
                    .onTapGesture { deselect() }
                    .padding(.top, ReffiSpace.s2)
                    .padding(.horizontal, ReffiGrid.margin + cardInset)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { receiptHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)   // 콘텐츠가 다 들어가면 바운스 없음(영수증이 버튼 위로 튀지 않게)
            .frame(maxHeight: receiptHeight > 0 ? receiptHeight : CGFloat.infinity)
            .layoutPriority(1)   // 남는 높이를 아래 Spacer와 반씩 나눠 갖지 않게 — 캡 안에서 먼저 배분
            .padding(.bottom, ReffiSpace.s3)
            outcomeButtons(sel)
                .padding(.top, ReffiSpace.s2)
            Spacer(minLength: ReffiSpace.s2)
            if !others.isEmpty {
                bottomStack(others)
            } else {
                // 마지막 재료 — 하단 스택이 없으면 그 몫의 네비 자리 예약도 사라져
                // Ate/Tossed 버튼이 떠 있는 네비 밑에 깔린다. 스택 자리만큼 바닥을 비워둔다.
                Color.clear.frame(height: ReffiChrome.navReserve)
            }
        }
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            PaperCloseButton(action: deselect)   // 룰① — 종이 X의 단일 공급원(시각40/히트44/paper)
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    /// 처리 — 먹음/버림. store에서 제거 + 카운트 후 복귀.
    /// 스크롤 밖에 도킹되는 1차 액션 — 높이를 고정하지 마라(큰 글자에서 라벨이 잘린다). 블롭 88 ≥ 44(§7.3).
    private func outcomeButtons(_ sel: Ingredient) -> some View {
        // Main의 결정 오버레이와 동일한 종이컷 아이콘 버튼(기본 88 + s6 간격).
        HStack(spacing: ReffiSpace.s6) {
            PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) {
                remove(sel, ate: false)
            }
            PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) {
                remove(sel, ate: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 하단 collapse 스택 — 나머지 영수증을 띠로 겹침. 탭 시 그 카드로 전환.
    private func bottomStack(_ others: [Ingredient]) -> some View {
        // 세우는 장수는 위 스택과 **같은 상한**을 쓴다(`stackPage`). 여기선 잘라 내도 보이는 것이
        // 달라지지 않는다: 띠 높이(아래 112)가 고정이라 장수가 늘수록 한 장이 드러내는 폭(peek)이
        // 그만큼 얇아져, 재고 200이면 0.3pt짜리 조각 199장을 세운 뒤 전부 클립으로 잘라 냈다.
        // 30장이면 peek 2.2pt로 띠 높이는 그대로고(29 × 2.2 + 48 = 112) 겹의 결은 오히려 살아난다.
        let stack = Array(others.prefix(Self.stackPage))
        // 112 = 종전 132에서 20 양보 — 펼침 화면의 주인공은 영수증이라, 기본 글자 크기에서
        // 하단 톱니(ReceiptShape 절취선)까지 온전히 보이도록 배경 스택의 몫을 줄였다.
        let maxVisible: CGFloat = 112
        let count = max(1, stack.count)
        let peek = min(26, (maxVisible - 48) / CGFloat(max(1, count - 1)))
        let visible = CGFloat(count - 1) * peek + 48
        return VStack(spacing: -(cardHeight - peek)) {
            ForEach(Array(stack.enumerated()), id: \.element.id) { i, ing in
                // 위로 밀어 닫은 손은 카드를 고르려는 손이 아니다. 같은 터치가 **버튼 탭으로도**
                // 도착한다 — SwiftUI 버튼은 이동 거리가 아니라 프레임 이탈로 탭을 취소하는데,
                // 카드가 170pt라 90pt를 밀어 올려도 손끝은 여전히 같은 버튼 안이다. 그대로 두면
                // 닫기(deselect) 직후 그 버튼이 다른 카드를 열어, 스와이프가 "닫힘"이 아니라
                // "옆 카드로 갈아탐"으로 끝난다(실측). 닫은 제스처가 남긴 표를 여기서 한 번 삼킨다.
                Button { if !consumeStackDismiss() { select(ing) } } label: {
                    FridgeCard(ingredient: ing, depth: i, seed: ing.daysLeft, height: cardHeight)
                        .matchedGeometryEffect(id: ing.id, in: ns)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
                .accessibilityHint(Text("Opens details"))
                .zIndex(Double(i))
            }
        }
        .frame(height: visible, alignment: .top)
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        // 미는 동안 스택이 **손을 따라 올라온다** — 0.6 감쇠라 종이 더미가 살짝 저항하며 끌려온다.
        // Reduce Motion이면 따라오지 않고 제자리에 있다(판정은 그대로 되므로 기능은 남는다, §7.4).
        .offset(y: reduceMotion ? 0 : stackLift)
        .padding(.horizontal, ReffiGrid.margin + cardInset)
        .padding(.bottom, ReffiChrome.navReserve)
        // 위로 스와이프(또는 탭) → 냉장고 스택으로 촤라락 복귀.
        // `simultaneousGesture`인 이유는 To buy 행(`ShoppingListView.row`)과 같다 — 안쪽이 버튼이 되면
        // `gesture`는 안쪽 제스처에 밀려 한 번도 잡히지 않는다. 동시로 두면 탭은 버튼이, 위로 미는 손은
        // 이 제스처가 가져간다(스와이프는 카드 위쪽 띠에서 시작해 카드 밖으로 나가므로 둘이 겹치지 않는다).
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .updating($stackLift) { v, lift, _ in
                    // 위(음수)로만 끌린다 — 아래로 미는 손엔 여기서 할 일이 없다(스크롤 몫).
                    lift = min(0, v.translation.height) * Self.stackLiftDamping
                }
                .onEnded { v in
                    // 변위 단독 판정(옛 -36)은 **짧고 빠른 튕김**을 놓쳤다 — 손가락이 36pt를 긋기
                    // 전에 떠도 사람은 이미 "밀어 올렸다"고 느낀다. 덱·To buy 행과 같은 규약으로
                    // 던진 속도(`predictedEndTranslation`)를 함께 본다: 끝까지 끌었거나(변위),
                    // 짧아도 세게 튕겼으면(예측) 닫는다.
                    if v.translation.height < -Self.stackDismissDistance
                        || v.predictedEndTranslation.height < -Self.stackDismissPredicted {
                        markStackDismissed()
                        deselect()
                    }
                }
        )
    }

    /// 방금 스와이프로 닫았다는 표. 같은 터치의 버튼 탭이 **바로 다음 런루프**에 도착하므로
    /// 창을 아주 짧게 잡고 스스로 지운다 — 버튼이 어떤 이유로든 오지 않아도 다음 진짜 탭을
    /// 삼키지 않는다(표를 무기한 들고 있으면 그 다음 카드가 안 열리는 유령 버그가 된다).
    private func markStackDismissed() {
        stackDismissedAt = Date()
    }

    private func consumeStackDismiss() -> Bool {
        guard let at = stackDismissedAt, Date().timeIntervalSince(at) < Self.stackDismissSwallow else { return false }
        stackDismissedAt = nil
        return true
    }

    /// 닫기 제스처가 버튼 탭을 삼키는 창(초).
    private static let stackDismissSwallow: TimeInterval = 0.2

    /// 손을 따라 올라오는 비율 — 1이면 종이가 손에 붙어 날아가고, 낮으면 무겁다. 0.6은
    /// "끌려오지만 더미의 무게가 남는" 지점(덱 카드는 1:1로 따라간다 — 그건 한 장이라 가볍다).
    private static let stackLiftDamping: CGFloat = 0.6
    /// 끝까지 끌어 닫는 변위 — 옛 판정값 그대로다(이미 손에 익은 거리).
    private static let stackDismissDistance: CGFloat = 36
    /// 튕겨 닫는 예측 변위 — 감속까지 더한 예측이라 실제 변위보다 크게 잡는다.
    private static let stackDismissPredicted: CGFloat = 120

    // MARK: 헤더 — "여기가 어디인가(Fridge · N) → 무엇을 보는가(탭) → 목록 조작(컨트롤 한 줄)"의 순서.

    /// 타이틀. **재고 총량은 이 화면에 두지 않는다**(2026-08 owner decision) — 옛 "N in stock" 라벨도,
    /// 그것을 이어받았던 타이틀 옆 "· N" 캡션도 함께 걷었다. 다른 자리로 옮기지 않았다:
    /// 냉장고에 몇 개가 들었는지는 목록 자체가 보여 주고, 지금 급한 것(D-day)이 이 화면의 payload다.
    private var titleRow: some View {
        // 번역되는 Display 타이틀이라 스크립트 폴백을 경유한다 — ko "냉장고"는 Story Script에 글리프가 없다(§3.1).
        let title = String(localized: "Fridge")
        return Text(verbatim: title)
            .reffiType(.display, for: title)
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 목록 조작 한 줄 — 좌: 카테고리 필터 드롭다운 / 우: 정렬 + 보기 토글.
    /// 좌우로 가르는 이유는 성격이 다르기 때문이다: 왼쪽은 **무엇을 보이는가**(범위를 좁힌다),
    /// 오른쪽은 **어떻게 보이는가**(순서·밀도). 셋 다 같은 44pt 종이 칩이라 한 줄로 읽힌다.
    private func controlRow(_ list: ListDigest) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            // 카테고리가 한 종류뿐이면 필터가 무의미하다 — 칩 행 시절과 같은 규칙(동작 없는 UI 금지).
            if list.categories.count > 1 { categoryMenu }
            Spacer(minLength: ReffiSpace.s2)
            sortMenu
            // 접근성 글자 크기에서는 목록이 항상 간편 행이라(`showsCompactList`) 이 토글이 아무것도
            // 바꾸지 못한다 — 눌러도 화면이 그대로인 컨트롤은 두지 않는다(동작 없는 UI 금지).
            // 저장된 `compact` 값은 손대지 않으므로, 글자 크기를 되돌리면 사용자의 선택이 그대로 돌아온다.
            if !typeSize.isAccessibilitySize { viewToggle }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 카테고리 필터 칩 — 현재 선택을 상시 노출하는 드롭다운 트리거(§13.5 "탭 → 옵션 목록"의 단일 문법).
    /// 가로 스크롤 칩 행을 이 하나로 접었다: 칩은 한 줄을 통째로 먹으면서도 오른쪽 칩이 잘려 나가
    /// "몇 종이 더 있는지"를 스크롤해야만 알 수 있었는데, 드롭다운은 전 카테고리를 개수와 함께 한 번에 편다.
    /// 접근성 라벨은 칩 시절의 `Filter: <이름>` 문법을 그대로 잇는다(UI 테스트 셀렉터도 같은 축).
    private var categoryMenu: some View {
        PaperDropdownTrigger(label: categoryTriggerLabel,
                             isOpen: openMenu == .category,
                             seed: 9) { toggleMenu(.category) }
            .accessibilityLabel(String(localized: "Filter: \(categoryTriggerLabel)"))
    }

    /// 트리거에 적는 현재 선택 — 개수는 붙이지 않는다(카테고리별 수는 펼친 드롭다운 행이 말하고,
    /// 재고 총량은 이 화면에 두지 않는다는 결정은 `titleRow` 주석 참고. 칩 시절처럼 트리거에도
    /// 수를 달면 같은 숫자가 펼침 전후로 두 번 선다).
    private var categoryTriggerLabel: String {
        activeCategory.map(FridgeCategoryFilter.displayName) ?? String(localized: "All")
    }

    /// 드롭다운 행 라벨 — 이름 + 개수(칩이 보여 주던 그 수). 조각은 로컬라이즈돼 있지만 **조합
    /// 순서도 언어의 것**이라 포맷 자체를 카탈로그(`%1$@ %2$lld`)에 태운다 — 코드 접합으로 굳히면
    /// 어순이 다른 언어가 손댈 자리가 없다.
    private func categoryOptionLabel(_ category: String?, in list: ListDigest) -> String {
        let name = category.map(FridgeCategoryFilter.displayName) ?? String(localized: "All")
        let count = category.map { c in list.categories.first { $0.category == c }?.count ?? 0 }
            ?? list.sorted.count
        return String(localized: "\(name) \(count)")
    }

    /// 정렬 칩 — 현재 정렬 라벨을 상시 노출하는 종이컷 칩(§13.5). 비주얼은 그대로, 탭하면 스톡 Menu 대신
    /// 앱 커스텀 `PaperDropdown`을 토글한다. 칩 바운드를 앵커로 올려 드롭다운을 바로 아래에 띄운다.
    ///
    /// **앵커는 열려 있을 때만 올린다** — 같은 줄에 카테고리 트리거가 생기면서 이 화면의 드롭다운
    /// 트리거가 둘이 됐다. `DropdownAnchorKey`는 마지막 non-nil이 이기므로, 상시 발행하면 뒤에 오는
    /// 이 칩이 항상 이겨 **카테고리 팝업이 정렬 칩 아래에 뜬다**(`PaperDropdownTrigger`가 같은 이유로
    /// 조건부 발행을 한다). 시각·히트 영역은 종전 그대로다.
    private var sortMenu: some View {
        Button { toggleMenu(.sort) } label: {
            HStack(spacing: ReffiSpace.s1) {
                ReffiIcon.sort.reffi(12, .bold)
                Text(sort.label)
                    .font(ReffiTextRole.caption.font)
                    .tracking(ReffiTextRole.caption.tracking)
            }
            .foregroundStyle(ReffiColor.ink)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let s = PaperRect(cornerRadius: ReffiRadius.sm, seed: 5)
                s.fill(ReffiColor.paper).paperEdge(s)
            }
            .frame(minHeight: ReffiChrome.tapMin)   // §7.3 터치 타깃
            .contentShape(Rectangle())
            .anchorPreference(key: DropdownAnchorKey.self, value: .bounds) {
                openMenu == .sort ? $0 : nil
            }
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel("Sort: \(sort.label)")
    }

    /// 카테고리 선택 — 고른 값을 **그대로** 넣는다. 칩 시절의 "같은 칩 재탭 = 해제"는 칩 문법이었고,
    /// 드롭다운에서는 이미 체크가 붙은 행을 다시 눌렀다고 필터가 풀리면 체크 표시와 모순된다.
    /// 해제 경로는 목록 맨 위의 "All"이 맡는다(칩 행에도 있던 그 경로라 닿을 수 있는 상태는 같다).
    /// 목록이 통째로 갈리므로 선택된 상세는 접는다.
    private func selectCategory(_ category: String?) {
        withAnimation(motion) {
            activeCategory = category
            selectedID = nil
        }
    }

    /// 보기 전환 — 메뉴에 숨기지 않는 원탭 토글(사진·파일 앱 문법). 아이콘은 "누르면 바뀔 모습".
    private var viewToggle: some View {
        Button {
            withAnimation(motion) { compact.toggle() }
        } label: {
            (compact ? ReffiIcon.stackView : ReffiIcon.compactView).reffi(14, .bold)
                .foregroundStyle(ReffiColor.ink)
                .padding(ReffiSpace.s2 + 2)
                .background {
                    let s = PaperRect(cornerRadius: ReffiRadius.sm, seed: 6)
                    s.fill(ReffiColor.paper).paperEdge(s)
                }
                .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)   // §7.3
                .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(compact ? "Switch to stack view" : "Switch to simple view")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("Nothing here yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Add ingredients and they’ll stack up here.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.lg, seed: 3)
            s.fill(ReffiColor.sub).paperEdge(s)
        }
    }

    // MARK: 종이 드롭다운 — 진입 .enter / 이탈 .exit(§7.1), reduced-motion 존중.
    //
    // 메뉴는 **읽으러 여는 것**이라 예산이 짧다(150~250ms). `pop`(response 0.34 + 오버슈트)은
    // 종이컷 표면이 튀어 오르는 문법(§7.5)이라 340ms를 넘겨 그 예산을 깬다 — 정렬 하나 바꾸려고
    // 손이 두 번 멈춘다. 드롭다운 면 자체는 종이지만 **성격이 메뉴**라 §7.1 진입을 쓴다.

    /// 이 화면에서 열릴 수 있는 드롭다운. 값이 하나뿐이라 **둘이 동시에 열리는 상태가 존재하지 않는다**
    /// (`DropdownAnchorKey`의 "화면당 하나" 전제를 상태 모양으로 강제한다).
    enum OpenMenu { case none, category, sort }

    /// 트리거 탭 — 열려 있던 그 메뉴면 닫고, 아니면 그쪽으로 **갈아탄다**(다른 메뉴가 열려 있어도
    /// 한 번의 탭으로 옮겨진다 — 먼저 닫으라고 요구하면 칩 두 개가 서로를 막는다).
    private func toggleMenu(_ menu: OpenMenu) {
        if openMenu == menu {
            closeMenus()
        } else {
            withAnimation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)) { openMenu = menu }
        }
    }
    private func closeMenus() {
        withAnimation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion)) { openMenu = .none }
    }

    // MARK: 액션
    private func select(_ ing: Ingredient) { withAnimation(motion) { selectedID = ing.id } }
    private func deselect() { withAnimation(motion) { selectedID = nil } }
    private func remove(_ ing: Ingredient, ate: Bool) {
        decisionHaptic += 1
        withAnimation(motion) {
            selectedID = nil
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }
}

/// 냉장고 카테고리 필터의 순수 로직 — 뷰 상태 없이 목록만 다룬다(유닛 테스트 가능).
///
/// 그룹 키는 저장된 `ingredient.category`가 아니라 **글리프 파생 라벨**(`FoodGlyph.categoryLabel`)이다.
/// 저장 카테고리는 레거시·스캔 경로에서 "Meat · Beef" 같은 자유 문자열이 섞여 들어와 칩이 파편화되고
/// 로컬라이즈 키도 없다. 글리프 라벨은 항상 캐논 10종이라 칩 집합이 안정적이고 전부 번역돼 있다
/// (History 정산서 그룹핑도 같은 키를 쓴다 — 한 화면 두 기준을 만들지 않는다).
enum FridgeCategoryFilter {
    /// 칩 고정 순서 — 사용 빈도(신선식품 → 저장식품 → 기타). 재고에 있는 것만 이 순서로 노출된다.
    /// 정본은 `FoodGlyph.categoryOrder` 하나 — To buy 검색 시트의 픽커 섹션도 같은 상수를 본다.
    static let order = FoodGlyph.categoryOrder

    /// 칩 한 개분 — 캐논 카테고리 키 + 재고 개수.
    struct Bucket: Equatable {
        let category: String
        let count: Int
    }

    /// 재료의 필터 키(캐논 영문).
    static func key(of ingredient: Ingredient) -> String { ingredient.glyph.categoryLabel }

    /// 뷰의 자동 해제 훅이 쓰는 **변화 감지 키** — id만으로는 부족하다. 이름을 고치면
    /// `FridgeStore.update`가 글리프와 카테고리를 다시 파생시키는데 id는 그대로라, id 배열만 보는
    /// 훅은 아예 돌지 않는다. 그러면 필터가 방금 비워진 카테고리를 계속 가리켜 재고가 가득한데도
    /// 빈 상태 화면에 갇힌다(칩 행도 그 카테고리를 잃어 선택 표시가 사라진다). 카테고리를 키에 섞어
    /// 재료의 **소속이 바뀌는 것도 변화로** 잡는다.
    static func changeKey(of ingredient: Ingredient) -> String {
        "\(ingredient.id.uuidString)|\(key(of: ingredient))"
    }

    /// 재고에 실제로 존재하는 카테고리만, 고정 순서로 + 개수. 목록에 없는 카테고리 칩은 만들지 않는다.
    static func buckets(of items: [Ingredient]) -> [Bucket] {
        var counts: [String: Int] = [:]
        for item in items { counts[key(of: item), default: 0] += 1 }
        return order.compactMap { c in counts[c].map { Bucket(category: c, count: $0) } }
    }

    /// 필터 적용 — nil(전체)이면 입력 순서 그대로. 정렬은 호출부에서 이미 끝난 상태를 전제.
    static func apply(_ category: String?, to items: [Ingredient]) -> [Ingredient] {
        guard let category else { return items }
        return items.filter { key(of: $0) == category }
    }

    /// 재고 변화 후 필터가 어떤 값이어야 하는지 — **뷰의 자동 해제가 그대로 호출하는 유일한 규칙**이다
    /// (뷰에 같은 판단을 다시 적으면 테스트가 실물과 어긋난다). 전체(nil)로 풀어야 하는 경우 둘:
    ///   ① 해당 카테고리 재고가 하나도 안 남음 — 마지막 한 개를 먹거나 버렸을 때 빈 화면에 가두지 않는다.
    ///   ② **새로 들어온 재료가 전부 필터 밖** — 필터를 켠 채 재료를 추가하면 화면에 아무 변화가 없어
    ///      "추가가 안 됐다"로 읽힌다. 추가 결과는 언제나 눈에 보여야 한다.
    /// - Parameters:
    ///   - category: 현재 활성 필터(nil = 전체).
    ///   - items: 필터 **이전**의 전체 표시 목록.
    ///   - added: 이번 변화에서 새로 나타난 재료 id. 비어 있으면 ②는 판정하지 않는다.
    static func resolved(_ category: String?, in items: [Ingredient],
                         added: Set<Ingredient.ID> = []) -> String? {
        guard let category, items.contains(where: { key(of: $0) == category }) else { return nil }
        guard added.isEmpty
                || items.contains(where: { added.contains($0.id) && key(of: $0) == category })
        else { return nil }
        return category
    }

    /// 표시명 — 저장·비교는 영문 캐논, 표시만 로컬라이즈(카테고리 키는 이미 카탈로그에 등록돼 있다).
    static func displayName(_ category: String) -> String {
        String(localized: String.LocalizationValue(category))
    }
}

/// 냉장고 정렬 기준 — rawValue는 AppStorage 영속화용 안정 키.
enum FridgeSort: String, CaseIterable, Identifiable {
    case expiry    // 임박순(기본) — 위에서부터 먹어야 할 순서(§8.1)
    case freshest  // 신선한 순 — 여유 있는 재료부터
    case recent    // 최근 등록순 — 방금 사 온 것부터

    var id: String { rawValue }
    /// 표시 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
    var label: String {
        switch self {
        case .expiry:   String(localized: "Expiring first")
        case .freshest: String(localized: "Freshest first")
        case .recent:   String(localized: "Recently added")
        }
    }
}

/// 간편보기 행 — 겹침 없는 납작한 흰 영수증 조각. 실루엣 + 이름 + 수량 + D-day.
///
/// **큰 글자에선 한 줄을 두 단으로 접는다.** AX 크기에서는 냉장고가 이 행으로 자동 전환되는데
/// (`FridgeView.showsCompactList`), 같은 줄에 이름·수량·D-day가 나란히 서면 이름 몫으로 남는 폭이
/// 없어 'Spinach'가 'Spi…'로 잘렸다 — 재료 이름은 이 행이 존재하는 이유라 가장 먼저 온전해야 한다.
struct FridgeCompactRow: View {
    let ingredient: Ingredient

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let f = ingredient.freshness
        return HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                .frame(width: ReffiFoodIcon.row, height: ReffiFoodIcon.row)
            if typeSize.isAccessibilitySize {
                // 이름은 위층에 통째로(2줄까지), 나머지 메타는 아래층 한 줄로. 세로로 자라는 대신
                // 이름이 잘리지 않는다 — 이 행은 어차피 세로 리스트라 높이엔 여유가 있다.
                VStack(alignment: .leading, spacing: ReffiSpace.s1) {
                    nameText.lineLimit(2)
                    // 아래층엔 **빈 자리를 두지 않는다**(기본 크기 행의 `Spacer`와 다른 점): AX 크기에선
                    // 수량과 D-day가 남는 폭을 거의 다 쓰는데, 그 사이에 `Spacer`를 끼우면 빈 자리가 먼저
                    // 폭을 집어가 '300 g'이 '30…'으로 잘렸다(실측 — `layoutPriority`를 내려도 같았다).
                    // 오른쪽 끝 정렬보다 두 값이 온전한 쪽이 크다. 색이 이미 둘을 갈라 준다(§2.6 dark).
                    HStack(spacing: ReffiSpace.s2) {
                        quantityText
                        frozenStamp
                        dDayText
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    nameText.lineLimit(1)
                    quantityText
                }
                Spacer(minLength: ReffiSpace.s2)
                frozenStamp
                dDayText
            }
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: ingredient.daysLeft &+ 3)
            s.fill(ReffiColor.receipt).paperEdge(s)
        }
        .reffiShadowCardCompact()   // 한 화면에 여러 장 반복되는 납작한 행
        .accessibilityElement(children: .combine)
    }

    // 두 배치가 **같은 조각**을 다르게 앉힐 뿐이라, 글자 역할·잉크는 한 곳에서만 정한다.
    private var nameText: some View {
        Text(verbatim: ingredient.displayName)
            .reffiType(.checklistItem)
            .foregroundStyle(ReffiColor.ink)
    }

    private var quantityText: some View {
        Text(verbatim: ingredient.quantityText)
            .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
    }

    @ViewBuilder
    private var frozenStamp: some View {
        if ingredient.isFrozen {
            DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 10)
        }
    }

    private var dDayText: some View {
        Text(ingredient.dDayText)
            .font(.reffiNum(.body))
            .foregroundStyle(ingredient.freshness.dark)   // §2.6 캔버스/종이 위 색-텍스트는 dark
            .accessibilityLabel(ingredient.dDayAccessibilityText)
    }
}

/// 흰 영수증 카드 한 장 — ReceiptShape + 종이질감 + 음식 실루엣 + 이름. 색은 Due date에만(임박 신호).
struct FridgeCard: View {
    let ingredient: Ingredient
    var depth: Int = 0
    var seed: Int = 0
    var height: CGFloat = 128

    private let toothH: CGFloat = ReffiTooth.card

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.receipt   // 흰 영수증

        return VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            // 상단 행 — 카테고리(좌) / [FROZEN] + D-day 도장(우 상단 코너).
            // 냉동은 스택을 쪼개지 않고(영수증 더미 메타포 유지) 도장 하나로 구분한다(§13).
            HStack(alignment: .top, spacing: ReffiSpace.s2) {
                Text(LocalizedStringKey(ingredient.category))   // 카테고리는 영문 캐논 저장 — 표시만 로컬라이즈
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
                Spacer(minLength: ReffiSpace.s3)
                if ingredient.isFrozen {
                    DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 12)
                }
                DDayStamp(text: ingredient.dDayText, color: f.dark, size: 17,
                          caps: false, accessibilityLabel: ingredient.dDayAccessibilityText)
            }
            HStack(spacing: ReffiSpace.s3) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: ReffiFoodIcon.card, height: ReffiFoodIcon.card)
                Text(verbatim: ingredient.displayName)
                    .reffiType(.subhead).foregroundStyle(ReffiColor.ink).lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s4 + toothH)
        .padding(.bottom, toothH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background(paper, in: shape)
        .paperEdge(shape)
        .reffiShadowCardCompact()   // 겹쳐 쌓이는 카드라 얕은 단
    }
}

/// 펼친 상세 — 흰 영수증 한 장에 큰 일러스트 + 구매 정보(영수증 명세). 색은 Due date에만.
struct ExpandedFridgeCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}
    private let toothH: CGFloat = ReffiTooth.card

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.receipt   // 흰 영수증

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더 — 큰 일러스트 + (카테고리·편집) / (이름·Due date)
            HStack(spacing: ReffiSpace.s4) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: ReffiFoodIcon.hero, height: ReffiFoodIcon.hero)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(LocalizedStringKey(ingredient.category))
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        Spacer()
                        Button(action: onEdit) {
                            ReffiIcon.manual.reffi(16, .bold)
                                .foregroundStyle(ReffiColor.ink2)
                                .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)   // §7.3 최소 터치 타깃
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.paperPress)
                        .accessibilityLabel("Edit")
                    }
                    HStack(alignment: .center, spacing: ReffiSpace.s2) {
                        Text(verbatim: ingredient.displayName).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                        Spacer()
                        if ingredient.isFrozen {
                            DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 11)
                        }
                        DDayStamp(text: ingredient.dDayText, color: f.dark, size: 14,
                                  caps: false, accessibilityLabel: ingredient.dDayAccessibilityText)
                    }
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s4 + toothH)
            .padding(.bottom, ReffiSpace.s3)

            dashRule
            VStack(spacing: 0) {
                row("Purchased", ingredient.purchasedText)
                row("Where", ingredient.placeText)
                row("Quantity", ingredient.quantityText)
                // 값에 축약(· 3d)이 섞인 유일한 행이라 소리로 읽을 말을 따로 준다(§3.4 D-day 한 쌍).
                row("Expires", "\(ingredient.expiresText) · \(ingredient.dDayText)", valueColor: f.dark,
                    spokenValue: "\(ingredient.expiresText), \(ingredient.dDayAccessibilityText)")
                row("Storage", ingredient.storage.label)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s2)

        }
        .padding(.bottom, ReffiSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, toothH)
        .background(paper, in: shape)
        .paperEdge(shape)
        .reffiShadowCard()
    }

    /// 명세 한 줄 — 라벨(좌) + 값(우).
    ///
    /// **라벨과 값은 한 요소로 읽는다**(`FridgeCompactRow`·History와 같은 문법): 나누면 다섯 줄이
    /// 열 개 요소가 되고, "Expires" 다음 스와이프에서야 날짜가 나온다. `spokenValue`는 화면 표기가
    /// 축약일 때 그 자리에 대신 읽을 말이다(축약은 눈에만 통한다).
    private func row(_ label: LocalizedStringKey, _ value: String,
                     valueColor: Color = ReffiColor.ink,
                     spokenValue: String? = nil) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer(minLength: ReffiSpace.s4)
                Text(value)
                    .font(.reffiNum(.body))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text(verbatim: spokenValue ?? value))
            }
            .padding(.vertical, ReffiSpace.s2 + 2)
        }
        .accessibilityElement(children: .combine)
    }

    private var dashRule: some View {
        ReffiRule(.receipt).padding(.horizontal, ReffiSpace.s5)
    }
}

