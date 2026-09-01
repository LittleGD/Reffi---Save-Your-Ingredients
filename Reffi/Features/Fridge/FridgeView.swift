import SwiftUI
import PhosphorSwift

/// 냉장고 — 전체 재고를 임박순으로 쌓은 "흰 영수증" 스택(§13).
/// 영수증 냉장고의 IA(스택 + 탭→상세 + 히스토리)를 그대로, 비주얼은 Main의 종이컷 언어로.
/// 카드 탭 → Wallet식으로 펼쳐져 상세(구매정보 + Ate/Tossed), 나머지는 하단에 **덱**으로 쌓인다
/// (다음 한 장이 온전한 종이로 서고 뒤는 노출 띠 둘 — 위로 밀면 다음 재료로 넘어간다).
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
    /// 펼친 영수증이 실제로 스크롤되는가 — 넘칠 때만 하단을 흐린다(잘림 ↔ 이어짐 구분).
    /// 넘김 제스처의 양보 판정(`claimedByReceiptScroll`)도 **이 한 값**을 본다 — 같은 사실에 두 번째
    /// 측정 상태를 만들면 둘이 어긋나는 프레임이 생긴다.
    @State private var receiptScrolls = false
    /// 상세 좌표계(`DetailSpace`)에서 영수증 스크롤 뷰의 바닥선 — 넘김 제스처가 "여기부터는 내 몫"을
    /// 가르는 경계. 손을 대기 전 값만 받는다(측정 지점 주석).
    @State private var receiptBottomY: CGFloat = 0
    /// 상세 좌표계에서 하단 더미(덱, 없으면 그 자리의 네비 예약 띠)의 윗선 — 큰 위쪽 스와이프가
    /// "더미 위에서 시작했다"고 판정하는 경계(57차-a, `advanceDrag`의 닫기 분기). 기본값 `.infinity`는
    /// 첫 레이아웃 전에는 어떤 시작점도 이 경계를 넘지 못하게 하는 안전값이다(측정 전 오발동 방지).
    @State private var deckTopY: CGFloat = .infinity
    /// 직전 넘김의 방향 — 펼침 전환의 앵커만 정한다(아래 `AdvanceDirection`).
    @State private var advanceDir: AdvanceDirection = .tap

    /// 정렬·보기 선택 — 세션을 넘어 유지(리서치: 정렬 선택은 기억되어야 재방문 비용이 준다).
    @AppStorage("fridge.sort") private var sortRaw: String = FridgeSort.expiry.rawValue
    @AppStorage("fridge.compact") private var compact = false
    /// 카테고리 필터(nil = 전체) — **영속화하지 않는다**. 정렬은 재방문 비용을 줄이지만 필터는
    /// "지금 이 순간 좁혀 보기"라, 다음 실행에 살아 있으면 재고가 사라진 것처럼 보인다(세션 한정).
    @State private var activeCategory: String?
    /// 직전에 본 전체 재고 id — 이번 변화에서 **새로 나타난** 재료를 가려내는 기준(필터 자동 해제).
    @State private var knownIDs: Set<Ingredient.ID> = []

    /// 상세를 위아래로 미는 동안의 실시간 변위(음수 = 위) — 손을 따라가는 **직접 조작**이라 상태가
    /// 아니라 제스처에 매달아 둔다. 영수증과 덱 앞장이 이 한 값을 서로 다른 비율로 나눠 쓴다.
    /// `@State`로 두면 스크롤이 제스처를 가로채 `onEnded`가 오지 않는 경로에서
    /// 값이 그대로 굳는다(`simultaneousGesture`라 그 경로가 실제로 있다) — `@GestureState`는
    /// 손을 떼든 취소되든 스스로 0으로 돌아온다. 되돌아가는 길만 안착 스프링을 태운다(§7.5 settle).
    @GestureState(resetTransaction: Transaction(animation: ReffiMotion.settle))
    private var deckLift: CGFloat = 0
    /// 밀어 다음/이전 재료로 넘긴 시각 — 같은 터치가 이어서 던지는 버튼 탭을 한 번 삼키는 데 쓴다
    /// (아래 `consumeAdvanceTap` — 덱 머리와 판정 버튼 둘 다 소비한다).
    @State private var advancedAt: Date?

    private let cardHeight: CGFloat = 170   // 길게 늘려 슬립·틸트로 생기는 측면 빈틈을 덮음
    private let overlap: CGFloat = -60   // advance(=높이+겹침)=110 — 이름 안전 구간은 기본~xxxLarge 한정(AX는 `showsCompactList`)

    /// **회전·삐져나옴이 있는 표면 전용**(= `stackList` 하나) — 페이지 마진(16) 위에 얹는 slip·tilt 예산이다.
    ///
    /// 이 값은 미감이 아니라 기하에서 역산됐다: slip ±16 · tilt ±4°에서 최악 인덱스(i=5, slip −16 ·
    /// tilt −2°)의 카드 좌측 코너가 16 + 18 − 16 − (170/2)·sin2° = 15.0pt로 페이지 마진에 거의 닿는다.
    /// 줄이면 그 코너가 베젤을 문다(18→8 안이 그래서 기각됐다).
    ///
    /// **회전이 없는 표면에 상속시키지 마라 — 예산은 상속되지만 근거는 상속되지 않는다.**
    /// 이 화면이 실제로 쓰는 좌우 인셋은 세 값뿐이고, 갈리는 축은 "그 종이가 흔들리는가"다:
    ///
    ///   · `ReffiGrid.margin` (16) — 페이지에 붙어 사는 표면. 타이틀·탭 행·컨트롤 한 줄·빈 상태·
    ///     간편보기 행·닫기 X 바. 형제 패인(To buy·History)도 전부 16이라 탭을 오가도 좌측선이 안 튄다.
    ///   · `ReffiGrid.margin + ReffiSpace.s2` (24) — **캔버스 위에 좁게 뜨는 종이**(§9.2 카드 인셋 관례,
    ///     오더·조리 티켓과 같은 자리). 펼친 상세 영수증과 그 아래 덱이 여기다. 둘은 세로로 이어 붙는
    ///     한 장면이라 **반드시 같은 값**이어야 한다(갈리면 이음매에 8pt 계단이 생긴다).
    ///   · `ReffiGrid.margin + cardInset` (34) — 아래 이 값. 스택 보기 **하나뿐**이다.
    ///
    /// 간편보기 행이 34였던 시절, 같은 화면에서 탭 행은 16인데 목록만 18pt 안으로 들어가 있었다.
    private let cardInset: CGFloat = 18

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
        // digest는 body 진입부에서 한 번(F88 규율). isActive 게이트 안으로 옮기는 최적화(42차 시도)는
        // 기각됐다 — 드롭다운 오버레이와 카테고리 onChange 훅이 게이트 밖에서 같은 장을 읽는다.
        let list = ListDigest(sorted: sortedItems, category: activeCategory)
        let sel = selected(in: list)
        return ZStack {
            // 가려진 동안은 **아무것도 세우지 않는다**(위 `isActive` 주석) — 상태는 그대로 살아 있고,
            // 활성화되는 프레임에 이 서브트리가 통째로 다시 선다.
            if isActive {
                // 바탕은 앱 공통 크림 한 장이다 — 패인마다 다른 accent 블롭을 깔던 시절, 탭을 옮길
                // 때마다 화면 전체를 덮은 색이 한 프레임에 갈아탔고(루트의 패인 전환에 애니메이션이
                // 없다) 하단 마스크·To buy CTA 페이드가 수렴하는 색과 톤이 갈렸다. 신선도는 배경이
                // 아니라 도장·Due date 잉크·실루엣 시듦이 말한다(§2.5) — 배경으로 한 번 더 말하면
                // 같은 사실의 네 번째 사본이 화면에서 가장 큰 면적을 먹는다.
                PaperCanvasBackground()
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
                // 하단 마스크 — 스크롤해 올라온 카드가 떠 있는 캡슐 네비의 반투명 유리 뒤에서 반쯤
                // 읽히는 것을 막는 **가림막**이다. VStack이 화면을 꽉 채우고 safe area를 무시 →
                // 바닥 정렬이 물리적 끝에 닿는다.
                //
                // 배경이 크림 단색이 된 지금도 이 층은 남는다 — 하는 일이 "톤 메우기"가 아니라
                // "콘텐츠 가리기"이기 때문이다(옛 배경에서는 세 번째 블롭을 지워 화면 아래 142pt를
                // 다른 배경으로 만드는 부작용이 있었고, 그 이음매는 배경이 같은 canvas가 되면서
                // 사라졌다 — 없어진 것은 결함이지 이 층의 존재 이유가 아니다).
                // **그냥 스크롤하는 패인(In stock·History)에만** 건다: To buy는 도킹 CTA가 이미
                // 같은 자리에 불투명 면을 깔기 때문에, 여기서 또 덮으면 그 버튼이 마스크 밑에 깔린다.
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
                    // 팝업은 트리거와 **가까운 변**에 붙는다(반대편에 붙이면 트리거에서 먼 쪽으로 열려
                    // 어느 칩이 열었는지가 흐려진다). 판정은 컨트롤 정체성이 아니라 **기하**로 한다 —
                    // 49차에 두 트리거가 모두 좌측으로 묶이면서, `openMenu == .category`로 판정하던
                    // 옛 코드는 정렬 팝업만 오른쪽 변에 붙여 트리거에서 떨어뜨렸다. 기하로 유도하면
                    // 다음에 배치가 또 바뀌어도 따라온다.
                    let leading = rect.midX < proxy.size.width / 2
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
                        FridgeCard(ingredient: ing, height: cardHeight)
                            .matchedGeometryEffect(id: ing.id, in: ns)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.paperPress)
                    .accessibilityHint(Text("Opens details"))
                    .zIndex(Double(i))
                    // 34(= 16 + 18) — 이 화면에서 **여기만** 쓰는 값이다. 바로 아래 두 줄이 그 이유다:
                    // 회전과 slip이 카드를 좌우로 흔들기 때문에, 포락선의 최외곽이 페이지 마진에
                    // 닿도록 인셋을 역산해 둔 것이다(위 `cardInset` 선언 주석의 기하).
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
    ///
    /// **자체 가로 인셋이 없다 = 페이지 마진(16)에 앉는다**(위 `cardInset` 주석의 세 값 중 첫째).
    /// 이 행에는 회전도 slip도 없으므로 스택의 인셋 예산을 물려받을 근거가 없고, 물려받던 시절엔
    /// 바로 위 탭 행(16)보다 18pt 안쪽에서 시작해 같은 화면의 좌측선이 두 줄로 갈렸다.
    ///
    /// 대가는 하나 있다: 스택↔간편 토글이 `matchedGeometryEffect`로 이어져 있어(같은 `ns`·같은 id)
    /// 이제 토글 한 번에 카드 폭이 좌우 18pt씩 함께 모핑한다. 높이가 170↔66으로 바뀌는 전환이라
    /// 폭 변화는 그 안에 묻히고, **정지 화면의 정렬이 전환 한 순간보다 크다**는 판단이다.
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
    }

    // MARK: 펼친(Wallet) 레이아웃
    private func expanded(_ sel: Ingredient, in list: ListDigest) -> some View {
        let following = Self.following(sel, in: list.items)
        let previous = Self.preceding(sel, in: list.items)
        return VStack(spacing: 0) {
            doneBar
            // 영수증만 스크롤하고 판정 버튼(Ate/Tossed)은 스크롤 **밖**에 둔다 — 이 화면의 유일한 1차 액션이라
            // 어떤 글자 크기·재고 수에서도 잘리면 안 된다(§7.3). 버튼을 스크롤 콘텐츠 안에 넣으면 하단 덱(≈90)과
            // 네비 자리 예약(`ReffiChrome.navReserve`)이 먹은 만큼 뷰포트가 좁아져 기본 글자 크기에서도 라벨이 잘렸다.
            //
            // **판정 버튼은 위(영수증)에 속한다** — 그 소속을 레이아웃으로 선언한다(오너 5-a: "Tossed,
            // Ate은 윗쪽과 그룹핑되는 게 UI적으로 옳아"):
            //   ① 영수증 아래 s3(12)만 남기고 버튼 자체의 상단 패딩(옛 s2)은 걷는다. 간격은 여전히
            //      스크롤 **밖**이라 영수증이 넘쳐 스크롤돼도 시각 간격이 변하지 않는다(46차 계약 유지).
            //   ② 아래 Spacer에 **바닥**(s7 = 32)을 준다. 옛 minLength는 8이라 아래 간격이 "값"이 아니라
            //      VStack에 남은 잔여였고, 그 잔여는 기기 높이·재료·언어·글자 크기마다 달라져 어떤
            //      화면에서는 위 20 : 아래 11로 **그룹이 뒤집혔다**(버튼이 덱에 붙어 보인다). 12 : ≥32면
            //      소속이 화면마다 흔들리지 않는다.
            //   ③ 대가를 알고 치른다: 예약 높이가 28(20+8) → 44(12+32)로 16pt 늘어 영수증 뷰포트가
            //      그만큼 줄고, 기본 글자 크기 대형 아이폰 기준 이름이 **두 줄이 되는 재료부터** 하단
            //      페이드 마스크가 켜진다(설계된 동작). 잘림을 페이드가 말해 주는 쪽이, 1차 액션의
            //      소속이 매 화면 달라지는 쪽보다 싸다.
            //   ④ 스크롤 높이를 콘텐츠 높이(receiptHeight)로 묶어, 영수증이 뷰포트보다 짧아도
            //      스크롤 뷰가 남는 높이를 먹고 늘어나지 않게 한다(= 영수증과 버튼 사이가 벌어지지 않음).
            ScrollView {
                // 전환 중 두 종이를 **겹쳐** 세운다. 세로로 쌓이면 컨테이너 높이가 잠깐 두 배가 되어
                // `receiptScrolls`가 잘못 켜지고 하단 마스크가 번쩍인다.
                ZStack(alignment: .top) {
                    ExpandedFridgeCard(ingredient: sel, onEdit: { editing = sel })
                        // **이 한 줄이 전환의 전제다.** 없으면 재료를 넘겨도 뷰 구조가 동일해
                        // (`ExpandedFridgeCard` 인스턴스는 그대로고 `ingredient` 프로퍼티만 갈린다)
                        // SwiftUI가 삽입/제거로 보지 않는다 = 전환이 **애초에 발생하지 않는다**.
                        // 오너의 "그냥 안쪽 내용만 바뀌어서 어색하다"는 은유가 아니라 코드의 문자적 서술이었다.
                        .id(sel.id)
                        // **크기는 매칭하지 않는다 — 위치만 잇는다.**
                        //
                        // 나가는 접힌 카드와 들어오는 이 카드가 둘 다 소스인 것은 애플이 문서화한 히어로
                        // 전환 문법이라 그대로 둔다(런타임 경고가 뜨는 "삽입 소스 둘"이 아니다). 문제는
                        // 기본값 `.frame` 매칭이 **전환 프레임마다 이 카드에 남의 크기를 제안한다**는 것이다:
                        // 상세 본문이 접힌 카드의 325×170 상자에 한 번 배치됐다가 자기 상자에 다시 배치되고,
                        // 그 중간 프레임에서 24pt 이름이 잘렸다 풀리고(오너: "mushro…로 떴다가 돌아온다")
                        // 아래 절취 톱니가 잘렸다 복원된다. `.position`이면 종이가 접힌 카드가 있던 자리에서
                        // 열리는 인상은 그대로고, 측정은 **자기 크기로 단 한 번**만 일어난다.
                        //
                        // 반대 방향(이 카드에 `isSource: false`)으로 고치지 마라 — 하단 덱은 지금 보는
                        // 재료를 애초에 담지 않으므로(아래 `following`) 정착 상태에서 이 그룹의 소스가
                        // 0개가 되고, 소스가 있는 전환 구간에는 이 상세가 접힌 카드의 170pt로 눌린다.
                        //
                        // 짝인 덱 머리(`bottomDeck`)도 같은 규약을 쓴다 — 펼친 상세가 관여하는 전환에서는
                        // **어느 쪽도 상대의 크기를 받지 않는다**. 목록 안에서만 도는 짝(스택 카드 ↔ 간편
                        // 행)은 종전대로 크기까지 매칭한다: 그쪽은 같은 성격의 행끼리라 서로의 상자에
                        // 배치돼도 잘릴 것이 없고, 보기 토글의 밀도 변화가 그 모핑으로 읽힌다.
                        .matchedGeometryEffect(id: sel.id, in: ns, properties: .position, anchor: .top)
                        // 펼침은 **레이아웃이 아니라 렌더 변환**으로 낸다(아래 `unfold`) — 그래서 위
                        // `.position` 계약을 한 글자도 건드리지 않고도 "종이가 펴지며 올라온다"가 된다.
                        //
                        // 나가는 종이는 방향과 무관하게 자기 윗변으로 말려 사라진다(`removal` 고정):
                        // 제거 전환은 **직전 렌더에 붙어 있던 것**이 쓰이므로, 방향 상태를 읽게 두면
                        // 스택에서 막 들어온 카드가 넘김 방향을 모른 채 제거되는 창이 생긴다. 삽입만
                        // 방향을 읽으면 그 값은 항상 이번 넘김의 것이다.
                        //
                        // 이 전환은 **덱 넘김에서만** 발화한다 — 목록에서 상세로 들어올 때는 `expanded`
                        // 서브트리가 통째로 삽입되고, 삽입되는 서브트리 **안쪽**의 전환은 따로 돌지 않는다.
                        .transition(.asymmetric(insertion: Self.unfold(anchor: advanceDir.anchor),
                                                removal: Self.unfold(anchor: .top)))
                        .contentShape(Rectangle())
                        .onTapGesture { deselect() }
                }
                .padding(.top, ReffiSpace.s2)
                .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)   // 24 — 위 `cardInset` 주석의 둘째 값
                // 측정은 **카드가 아니라 컨테이너**에서 받는다: 전환 중에는 max(나가는 것, 들어오는 것)이,
                // 정착하면 새 재료의 참 높이가 보고된다. 그래서 `select()`가 캡을 0으로 떨궈 한 프레임
                // 무제한으로 만들 필요가 없어졌다(그 대입은 삭제됐다 — 아래 `select` 주석).
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                    // 측정값은 **애니메이션 없이** 반영한다. 이 캡이 바깥 트랜잭션(settle =
                    // damping 0.74 언더댐프드)을 물려받으면 오버슈트 구간에서 스크롤 뷰가 콘텐츠보다
                    // 잠깐 짧아지고, 그때 영수증 하단 톱니가 잘렸다 복원된다.
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { receiptHeight = h }
                }
            }
            .scrollBounceBehavior(.basedOnSize)   // 콘텐츠가 다 들어가면 바운스 없음(영수증이 버튼 위로 튀지 않게)
            .frame(maxHeight: receiptHeight > 0 ? receiptHeight : CGFloat.infinity)
            // 접근성 글자 크기·긴 이름으로 영수증이 뷰포트를 넘기면 스크롤 뷰가 종이를 **사각으로**
            // 자른다 — 하단 톱니가 통째로 사라져 "가위로 자른 그림"이 된다(오너 지적). 넘칠 때만
            // 마지막 한 뼘을 흐려 잘린 게 아니라 이어진다고 말한다(`OrderMemoCard`의 같은 문법).
            .mask {
                if receiptScrolls {
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black, location: 0.90),
                                           .init(color: .black.opacity(0.06), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                } else {
                    Rectangle()
                }
            }
            .onScrollGeometryChange(for: Bool.self) { g in
                g.contentSize.height > g.containerSize.height + 1
            } action: { _, scrolls in
                receiptScrolls = scrolls
            }
            .layoutPriority(1)   // 남는 높이를 아래 Spacer와 반씩 나눠 갖지 않게 — 캡 안에서 먼저 배분
            // 넘김 제스처의 양보 경계선(아래 `claimedByReceiptScroll`). **손을 대기 전의** 바닥선을
            // 봐야 한다 — 바로 아래 추종 오프셋이 걸린 동안의 값을 받아들이면 기준선이 손을 따라
            // 움직여, 같은 자리에서 시작한 다음 드래그의 판정이 달라진다.
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(DetailSpace.name)).maxY } action: { y in
                if deckLift == 0 { receiptBottomY = y }
            }
            // 손을 따라 화면이 **실제로 움직인다** — 이것이 "이 화면은 넘길 수 있다"를 말하는 유일한
            // 정직한 신호다(위약 힌트 배지를 만들지 않는다). 46차엔 덱 앞장 하나만 따라와서, 화면의
            // 90%에서 미는 손은 아무 반응도 받지 못했다. 덱보다 반만 움직여 앞뒤 관계를 남긴다.
            .offset(y: reduceMotion ? 0 : deckLift * Self.receiptFollow)
            .padding(.bottom, ReffiSpace.s3)
            outcomeButtons(sel)
            Spacer(minLength: ReffiSpace.s7)   // 32 — 판정 버튼은 위(영수증)에 속한다는 구조적 선언
            Group {
                if !following.isEmpty {
                    bottomDeck(following, previous: previous)
                } else {
                    // 마지막 재료 — 하단 덱이 없으면 그 몫의 네비 자리 예약도 사라져
                    // Ate/Tossed 버튼이 떠 있는 네비 밑에 깔린다. 덱 자리만큼 바닥을 비워둔다.
                    Color.clear.frame(height: ReffiChrome.navReserve)
                }
            }
            // 두 분기 중 어느 쪽이 서 있든 **같은 자리**에서 윗선을 잰다(57차-a) — 마지막 재료라
            // 덱이 없어도 그 자리의 네비 예약 띠가 대신 경계를 낸다(스택된 값이 이전 재료의 덱
            // 윗선으로 굳어 있는 채로 남는 사고를 막는다). 덱 카드 자체는 `.offset`으로만 움직이므로
            // 드래그 중에도 이 프레임은 흔들리지 않는다(`receiptBottomY`처럼 `deckLift == 0` 가드가
            // 필요 없다).
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(DetailSpace.name)).minY } action: { y in
                deckTopY = y
            }
        }
        // 넘김 제스처의 면은 **화면 전체**다(아래 `advanceDrag`). `contentShape`로 빈 캔버스까지
        // 히트 영역에 넣어야 영수증 옆·버튼 아래 여백에서 시작한 손도 잡힌다.
        .contentShape(Rectangle())
        .simultaneousGesture(advanceDrag(next: following.first, previous: previous))
        // 좌표계는 **가장 바깥**에 선언한다 — 제스처와 위 측정이 둘 다 이 공간을 조상에서 찾는다.
        .coordinateSpace(.named(DetailSpace.name))
    }

    /// 펼친 상세의 좌표계 이름 — 제스처 시작점과 영수증 바닥선을 **같은 자에 대고 잰다**.
    /// 둘 중 하나라도 지역(local) 좌표를 쓰면 비교가 성립하지 않는다.
    private enum DetailSpace { static let name = "fridge.detail" }

    /// 이번 넘김이 어느 쪽이었는가 — 펼침 전환의 앵커만 정한다(레이아웃에는 관여하지 않는다).
    private enum AdvanceDirection {
        /// 목록·덱에서 직접 골라 들어온 길. 펼침 전환이 발화하지 않는 경로라 값은 기본 앵커로만 쓰인다.
        case tap
        /// 위로 밀어 다음 재료 — 새 종이가 덱(아래)에서 올라오며 윗변 기준으로 아래로 펴진다.
        case forward
        /// 아래로 밀어 이전 재료 — 위에서 내려오는 인상이라 아랫변 기준으로 위로 펴진다.
        case back

        var anchor: UnitPoint { self == .back ? .bottom : .top }
    }

    /// 상세 화면 전체를 덮는 세로 넘김 — 위 = 다음 재료, 아래 = 이전 재료.
    ///
    /// **면적이 곧 어포던스다.** 46차엔 이 제스처가 하단 덱 띠 하나(폭 화면−48 × 높이 74 = 화면의
    /// 9.5%)에만 붙어 있었다. 오너는 화면 대부분을 차지하는 영수증 위에서 밀었고 아무 일도 일어나지
    /// 않아 "탭해야만 바뀐다"고 읽었다(50차 시뮬 실측: 카드 위 드래그 무반응 100% 재현, 덱 띠 위에서만 동작).
    ///
    /// 제스처는 **하나만** 둔다 — 덱에 따로 또 붙이면 덱 위에서 두 번 발화한다. 대신 영수증이
    /// **실제로 넘칠 때만** 그 구역을 스크롤 뷰에 넘긴다(`claimedByReceiptScroll`): 넘치지 않으면
    /// 스크롤할 것이 없으니 영수증 위에서도 넘김이 먹는 것이 옳다.
    ///
    /// 축 잠금 배율 1.4는 `RecipeMemoCarousel.frontDrag`와 **같은 값**이다 — 같은 문법(플릭으로
    /// 목록을 넘긴다)에 두 값을 두지 않는다. 커밋 거리(36/120 vs 저쪽 160)는 갈라 둔다: 저쪽은
    /// 카드를 날려 보내는 커밋이고 이쪽은 목록 넘김이다.
    private func advanceDrag(next: Ingredient?, previous: Ingredient?) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named(DetailSpace.name))
            .updating($deckLift) { v, lift, _ in
                guard Self.claimsAdvance(v.translation), !claimedByReceiptScroll(v.startLocation) else { return }
                // **양방향 추종.** 옛 `min(0,…)` 클램프는 아래로 미는 손에게 변위 0을 돌려줬고,
                // 화면이 손을 전혀 따라오지 않으면 사용자는 "이쪽은 반대 의미"가 아니라
                // "이 화면엔 제스처가 없다"로 읽는다.
                lift = v.translation.height * Self.deckLiftDamping
            }
            .onEnded { v in
                guard Self.claimsAdvance(v.translation), !claimedByReceiptScroll(v.startLocation) else { return }
                // 변위 단독 판정은 **짧고 빠른 튕김**을 놓친다 — 손가락이 36pt를 긋기 전에 떠도
                // 사람은 이미 "밀어 올렸다"고 느낀다. 던진 속도(`predictedEndTranslation`)를 함께
                // 본다: 끝까지 끌었거나(변위), 짧아도 세게 튕겼으면(예측) 넘긴다.
                let d = v.translation.height, p = v.predictedEndTranslation.height
                // 하단 더미 위에서 시작한 **큰** 위쪽 스와이프 — 커버를 닫고 리스트로 복귀한다(57차-a,
                // "아래 티켓들을 위로 올리면 이전 리스트로 돌아가게"). 아래 "다음 카드로 한 장 넘기기"
                // 분기보다 **먼저** 검사해야 한다 — 같은 제스처 하나(`DragGesture` 인스턴스 하나)를
                // 재사용하므로 새 인식기를 얹어 생기는 이중 발화가 구조적으로 없다: 더미 위에서
                // 시작했고(`deckTopY` 밖에서는 절대 참이 되지 않는다) 이 값을 넘겨야만 닫히고,
                // 못 넘기면 그대로 아래 분기로 떨어져 **종전처럼** 다음 카드로 넘긴다 — 히트 영역이
                // 더미로 한정되면서도 "살짝 밀면 한 장, 세게 치우면 전부"라는 자연스러운 힘의 위계가 된다.
                // 닫기는 X와 **같은 경로**(`deselect`)를 그대로 불러 상태 정리 로직을 중복하지 않는다.
                // 햅틱은 새로 추가하지 않는다 — `PaperCloseButton`(X)도 의미 햅틱이 없어(§7.6 표는
                // 판정·성공·파괴만 다루고 닫기는 순수 정보성 전환이다), "기존 닫기와 같은 결"은 여기서
                // 무음이 곧 그 결이다. 모션은 `deselect()`가 이미 쓰는 `motion`(reduceMotion이면 nil)이
                // 그대로 처리하고, 더미가 손을 따라 오르는 페이퍼 모션·미달 시 원위치 스프링도 위
                // `.updating`의 `deckLift`(reduceMotion 게이트 포함)와 `@GestureState`의 자동 리셋
                // 스프링(`.settle`)을 그대로 물려받는다 — 새 모션 코드가 필요 없다.
                if v.startLocation.y >= deckTopY,
                   d < -Self.deckDismissDistance || p < -Self.deckDismissPredicted {
                    deselect()
                    return
                }
                if d < -Self.deckAdvanceDistance || p < -Self.deckAdvancePredicted {
                    if let next { markAdvanced(); select(next, direction: .forward) }
                } else if d > Self.deckAdvanceDistance || p > Self.deckAdvancePredicted {
                    if let previous { markAdvanced(); select(previous, direction: .back) }
                }
            }
    }

    /// 세로 넘김으로 볼 것인가 — 한 제스처에서 우세 축이 갈렸을 때만 참.
    /// 애매한 구간(대략 35.5°~54.5°)은 끝까지 거짓이라 **아무 것도 커밋하지 않는다**.
    private static func claimsAdvance(_ t: CGSize) -> Bool {
        abs(t.height) > abs(t.width) * 1.4
    }

    /// 이 시작점은 영수증 스크롤 몫인가 — **넘칠 때만** 참이다.
    /// `receiptScrolls`는 이미 "콘텐츠가 뷰포트를 넘는가"를 실측해 들고 있다(새 상태를 만들지 않는다).
    /// 넘치지 않는 대다수 화면에서는 영수증 위에서도 넘김 제스처가 그대로 먹는다.
    private func claimedByReceiptScroll(_ p: CGPoint) -> Bool {
        receiptScrolls && p.y < receiptBottomY
    }

    /// 펼친 상세가 손을 따라오는 비율 — 덱 앞장(`deckLiftDamping`)의 절반.
    /// 같이 움직이되 덱보다 덜 움직여야 "덱이 따라 올라온다"는 앞뒤 관계가 남는다.
    private static let receiptFollow: CGFloat = 0.5

    /// 종이 펼침 — 접힌 종이가 세로로 펴진다.
    ///
    /// `scaleEffect`는 **렌더 변환**이라 레이아웃에 크기를 제안하지 않는다. 46차가 측정으로 세운
    /// 결함("전환 프레임마다 남의 상자에 배치돼 이름이 `mushro…`로 잘렸다 돌아온다")은 이 축에
    /// **구조적으로 존재할 수 없다** — 텍스트가 다시 배치되지 않기 때문이다. 그래서 크기 표현을
    /// 여기서 내고 `matchedGeometryEffect`는 46차 계약(`.position`, `anchor: .top`) 그대로 둔다.
    ///
    /// **어떤 형태의 클립도 쓰지 마라.** 사각 클립(`clipShape`/`frame(height:)`)으로 접으면
    /// `ReceiptShape`의 위·아래 절취 톱니가 전환 중에 잘려 46차·`FridgeCardHead`가 금지한
    /// "가위로 직선 절단된 그림"이 그대로 재현된다. 스케일은 톱니를 살린 채로 눌렀다 편다.
    private static func unfold(anchor: UnitPoint) -> AnyTransition {
        .modifier(active: UnfoldModifier(scaleY: unfoldFrom, opacity: 0, anchor: anchor),
                  identity: UnfoldModifier(scaleY: 1, opacity: 1, anchor: anchor))
    }

    /// 접힌 상태의 세로 비율 — 덱 머리 74 ÷ 전형적 상세 높이(≈354, 기본 크기·이름 1줄).
    /// 매 전환마다 정확한 비율을 계산하지 않는 이유: 전환이 시작되는 시점의 `receiptHeight`는 아직
    /// 새 재료의 것이 아니고, 0.2~0.3 구간은 어차피 "접힌 종이"로 읽힌다.
    private static let unfoldFrom: CGFloat = 0.21

    /// 펼침 전환의 한 프레임. `opacity`를 함께 태우는 이유는 미감이 아니다 — 전환 중 두 종이가
    /// 같은 ZStack에 겹쳐 서므로, 페이드가 없으면 두 장의 잉크가 포개져 글자가 뭉개진다.
    private struct UnfoldModifier: ViewModifier {
        let scaleY: CGFloat
        let opacity: Double
        let anchor: UnitPoint
        func body(content: Content) -> some View {
            content
                .scaleEffect(x: 1, y: scaleY, anchor: anchor)
                .opacity(opacity)
        }
    }

    /// 펼친 재료 **다음**부터 목록 순서대로, 끝에 닿으면 처음으로 돌아 한 바퀴 — 덱의 커서다.
    ///
    /// 옛 하단 스택은 `items.filter { $0.id != sel.id }`로 만들어졌는데, 그건 커서가 아니라 필터라
    /// 덱 문법과 결합하는 순간 **두 재료를 무한 왕복**한다: [A,B,C,D]에서 A를 보다 넘기면 머리가 B,
    /// B를 보면 머리가 다시 A라 C·D에 영원히 닿지 못한다. 순서를 회전시키면 "다음"이 실제로 다음이다.
    ///
    /// 별도 상태(회전 배열)를 두지 않고 표시 목록에서 **매번 파생**한다 — 재료를 먹거나 버리면
    /// 목록이 곧바로 줄어드는 화면이라, 커서를 따로 들고 있으면 그쪽만 스테일이 된다.
    private static func following(_ sel: Ingredient, in items: [Ingredient]) -> [Ingredient] {
        guard let i = items.firstIndex(where: { $0.id == sel.id }) else {
            return items.filter { $0.id != sel.id }
        }
        return Array(items[(i + 1)...]) + Array(items[..<i])
    }

    /// 펼친 재료의 **직전** 한 장 — 아래로 미는 손이 도착하는 곳. 위 `following`의 거울이라
    /// 같은 규율을 그대로 잇는다(별도 상태를 두지 않고 표시 목록에서 매번 파생한다).
    ///
    /// **끝에서 순환한다** — `following`이 이미 순환이기 때문이다. 한쪽만 끊으면 위로 다섯 번 밀면
    /// 처음으로 돌아오는데 아래로는 못 돌아오는 비대칭이 생기고, 덱의 "+N more" 낭독도 두 방향에
    /// 대해 서로 다른 뜻이 된다. 대가는 "끝이 없다"는 감각이고, 전량 탐색의 정식 경로는 닫기(X)
    /// 뒤의 목록이다(46차 오너 판정).
    private static func preceding(_ sel: Ingredient, in items: [Ingredient]) -> Ingredient? {
        guard items.count > 1, let i = items.firstIndex(where: { $0.id == sel.id }) else { return nil }
        return items[(i - 1 + items.count) % items.count]
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            PaperCloseButton(action: deselect)   // 룰① — 닫기 X의 단일 공급원(글리프 18/ink2/히트 44, 면 없음 — 50차)
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    /// 처리 — 먹음/버림. store에서 제거 + 카운트 후 복귀.
    /// 스크롤 밖에 도킹되는 1차 액션 — 높이를 고정하지 마라(큰 글자에서 라벨이 잘린다). 블롭 88 ≥ 44(§7.3).
    private func outcomeButtons(_ sel: Ingredient) -> some View {
        // Main의 결정 오버레이와 동일한 종이컷 아이콘 버튼(기본 88 + s6 간격).
        //
        // **넘김 표를 여기서도 삼킨다.** 제스처 면이 화면 전체가 된 뒤로는 이 88pt 블롭 위에서 시작한
        // 스와이프가 같은 터치로 버튼 탭까지 던진다 — SwiftUI 버튼은 이동 거리가 아니라 프레임
        // 이탈로 탭을 취소하는데, 88pt 블롭 안에서 36pt는 이탈이 아니다. 삼키지 않으면 재료를 넘기려던
        // 손이 그 재료를 **먹거나 버린다**(되돌리기가 있어도 파괴적 오발동이다).
        HStack(spacing: ReffiSpace.s6) {
            PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) {
                if !consumeAdvanceTap() { remove(sel, ate: false) }
            }
            PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) {
                if !consumeAdvanceTap() { remove(sel, ate: true) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 덱에 실제로 세우는 장수 — 다음 한 장 + 뒤 머리 둘.
    ///
    /// 옛 하단 스택은 **30장을 세워 놓고 전부 사각 클립으로 잘라 냈다**. 띠 높이가 112로 고정이라
    /// 장수가 늘수록 한 장이 드러내는 폭이 반비례로 얇아졌고(재고 30이면 2.2pt), 그 2.2pt가 곧 그
    /// 카드의 유일한 탭 영역이었다 — §7.3 하한 44의 1/20이다. 장수를 줄이는 것이 "재료를 볼 수도
    /// 탭할 수도 없다"에 대한 답이다: 세 장이면 앞 한 장이 온전한 종이로 서고 히트 영역이 74pt다.
    private static let deckDepth = 3
    /// 뒤 장이 위로 내미는 머리 — 티켓 덱(14pt)을 이 작은 머리 카드에 맞춘 값.
    private static let deckPeek: CGFloat = 8

    /// 하단 덱 — **다음 재료 한 장이 온전한 종이로 서고**, 뒤는 글자 없는 노출 띠 둘이다.
    /// 위로 밀면 이 장이 상세 자리로 올라온다(§13.6 티켓 덱과 같은 문법).
    ///
    /// **보던 재료는 이 더미로 들어가지 않는다.** 46차 주석은 그렇게 적혀 있었지만 참인 적이 없다 —
    /// `following`은 보던 재료를 배열 **끝**으로 보내므로 재고가 4개 이상이면 그 카드는 `deckDepth`
    /// 밖이다. 나가는 종이는 제자리에서 접혀 사라진다(위 `unfold`의 removal). 넣으려면 덱을
    /// `[다음, 다음+1, 직전]`으로 바꿔야 하는데, 그러면 뒤 머리 둘의 뜻이 "앞으로 올 것"에서
    /// "앞뒤 혼합"으로 갈려 46차가 정한 "다음 한 장 + 뒤 머리 둘" 문법 자체가 깨진다(50차 오너 확정).
    ///
    /// **사각 클립으로 카드를 잘라 만들지 않는다.** `ReceiptShape`는 주어진 rect의 위·아래 **양변**에
    /// 절취선을 그리므로, 170pt 카드를 112pt 상자로 오려 내면 아래 톱니가 통째로 사라져 종이가
    /// "뜯긴" 게 아니라 "가위로 직선 절단된 그림"이 된다(오너: "아랫부분이 어색하게 잘려 있다").
    /// 짧게 **그린** 종이(`FridgeCardHead`)는 위·아래 절취선을 다 갖는다.
    private func bottomDeck(_ following: [Ingredient], previous: Ingredient?) -> some View {
        let deck = Array(following.prefix(Self.deckDepth))
        let next = deck.first
        return ZStack(alignment: .top) {
            ForEach(Array(deck.enumerated()), id: \.element.id) { depth, ing in
                let isFront = depth == 0
                // 민 손은 카드를 고르려는 손이 아니다. 같은 터치가 **버튼 탭으로도** 도착한다 —
                // SwiftUI 버튼은 이동 거리가 아니라 프레임 이탈로 탭을 취소하는데, 밀어 올린 손끝은
                // 여전히 같은 버튼 안이다. 그대로 두면 넘김 직후 그 버튼이 한 번 더 발동해 두 칸이
                // 건너뛰어진다. 넘긴 제스처가 남긴 표를 여기서 한 번 삼킨다.
                Button { if !consumeAdvanceTap() { select(ing) } } label: {
                    // 펼친 상세와 **같은 규약**으로 위치만 잇는다(그쪽 주석). 이 둘은 서로의 짝이라
                    // 한쪽만 크기를 매칭하면 나머지 한쪽이 상대의 상자로 눌린다 — 기본값이면 이 74pt
                    // 머리 카드가 상세가 빠지는 프레임마다 430pt로 늘어났다 줄어든다.
                    FridgeCardHead(ingredient: ing, blank: !isFront)
                        .matchedGeometryEffect(id: ing.id, in: ns, properties: .position, anchor: .top)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
                .accessibilityHint(Text("Opens details"))
                // 덱은 앞 장 하나만 보조기술에 낸다 — 그러면 "뒤에 몇 개가 더 있는가"가 조용히
                // 사라진다(옛 하단 스택은 29장을 전부 냈지만, 그 장들은 2.2pt 띠라 눈으로도 손으로도
                // 닿지 않는 유령이었다). 남은 수를 값으로 말해 목록이 여기서 끝나지 않음을 알린다 —
                // 전량 탐색의 정식 경로는 닫기(X) 뒤의 목록이다(오너 판정, 46차).
                .accessibilityValue(Text("+\(following.count) more"))
                // 티켓 덱과 같은 겹침 문법 — 뒤로 갈수록 조금 작고, 조금 비뚤고, 위로 머리를 내민다.
                // 앵커가 `.top`인 이유: 머리만 보이는 장이라 아래쪽이 아니라 **드러난 변**을 기준으로
                // 줄고 돌아야 노출 띠의 두께가 장마다 같게 읽힌다.
                .scaleEffect(isFront ? 1 : 1 - CGFloat(depth) * 0.035, anchor: .top)
                .rotationEffect(.degrees(isFront ? 0 : (depth % 2 == 0 ? -2.2 : 2.4)), anchor: .top)
                // 미는 동안 앞 장이 **손을 따라 올라온다**(뒤 장은 더미라 제자리다).
                // Reduce Motion이면 따라오지 않는다 — 넘김 자체는 그대로 되므로 기능은 남는다(§7.4).
                .offset(y: CGFloat(depth) * -Self.deckPeek
                        + (isFront && !reduceMotion ? deckLift : 0))
                .zIndex(Double(deck.count - depth))
                // 뒤 장은 글자 없는 띠다 — 탭 대상도, 보조기술이 읽을 것도 아니다.
                .allowsHitTesting(isFront)
                .accessibilityHidden(!isFront)
            }
        }
        .padding(.top, CGFloat(max(0, deck.count - 1)) * Self.deckPeek)   // 뒤 머리 몫을 위에 비운다
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)   // 24 — 위 영수증과 **같은 좌측선**
        .padding(.bottom, ReffiChrome.navReserve)
        // **넘김 제스처는 여기 없다 — 상세 화면 전체가 받는다**(위 `advanceDrag`).
        //
        // 46차엔 이 자리에만 붙어 있었고(옛 "위로 밀어 닫기"의 자리를 그대로 물려받았다) 그 결과
        // 유효 면적이 화면의 9.5%였다. 덱에 하나 더 붙이면 덱 위에서 두 번 발화하므로 **다시 붙이지 마라.**
        //
        // 닫는 길은 원래 둘이었다: ① 오른쪽 위 종이 X(`doneBar`) ② 영수증 본문 탭
        // (`onTapGesture { deselect() }`). 아래로 미는 손이 "이전 재료"인 이유가 이것이다 —
        // 46차 시점엔 닫기 경로가 이미 둘인데 세 번째를 만드는 것보다, 넘김을 양방향으로
        // 완성하는 편이 나았다(그래서 아래로 밀어 닫는 세 번째 경로는 만들지 않았다).
        //
        // **57차-a가 세 번째 닫기 경로를 더한다** — 단 방향도 자리도 다르다: 이 더미 **위에서
        // 시작한, 위로 미는, 세게 던진** 스와이프만 닫는다(위 `advanceDrag`의 `deckDismissDistance`
        // 분기). 아래로 미는 손은 여전히 "이전 재료"고, 위 46차 결론(도달 범위가 넓은 제스처 면
        // 전체에 세 번째 닫기를 얹지 않는다)도 그대로다 — 새 경로는 히트 영역을 이 더미로,
        // 힘의 크기를 "카드 한 장 넘기기"보다 뚜렷이 크게 좁혀서, 아래로 미는 손과도 넘기려는
        // 손과도 부딪히지 않는 오너 요청의 새 지점이다.
        //
        // 미는 제스처는 보조기술에 없다 — 넘김을 **양방향 액션**으로 낸다. 제스처가 두 방향이 된
        // 순간 액션이 한 방향뿐이면 보조기술 사용자만 도달하지 못하는 재료가 생긴다.
        // 라벨이 덱 위에서 읽히므로 무엇의 다음/이전인지는 문맥이 말한다.
        //
        // **닫기는 여기에 같은 방식(전용 액션)을 얹지 않는다(57차-a 판단).** 위 Next/Previous가
        // 액션으로 존재하는 이유는 "제스처 말고는 도달할 방법이 아예 없어서"다 — 덱엔 이전 재료로
        // 가는 버튼이 없다. 닫기는 다르다: `PaperCloseButton`(X)이 이미 상시 노출된, 전량 접근
        // 가능한 경로라 보조기술 사용자가 못 닿는 상태 자체가 없다. 이 저장소 전체에
        // `accessibilityAction(.escape)` 선례도 없다(그렙 확인) — 없는 관례를 이 화면 하나에
        // 처음 만드는 근거가 없고, 만들어도 X와 완전히 같은 동작을 한 번 더 노출할 뿐이다.
        .accessibilityAction(named: Text("Next")) {
            if let next { select(next, direction: .forward) }
        }
        .accessibilityAction(named: Text("Previous")) {
            if let previous { select(previous, direction: .back) }
        }
    }

    /// 방금 밀어 넘겼다는 표. 같은 터치의 버튼 탭이 **바로 다음 런루프**에 도착하므로
    /// 창을 아주 짧게 잡고 스스로 지운다 — 버튼이 어떤 이유로든 오지 않아도 다음 진짜 탭을
    /// 삼키지 않는다(표를 무기한 들고 있으면 그 다음 카드가 안 열리는 유령 버그가 된다).
    ///
    /// **덱 전용이 아니다.** 제스처 면이 화면 전체가 된 뒤로는 판정 버튼(Ate/Tossed)도 같은 표를
    /// 소비한다 — 그쪽은 오발동의 대가가 재료 소비/폐기라 훨씬 비싸다.
    private func markAdvanced() {
        advancedAt = Date()
    }

    private func consumeAdvanceTap() -> Bool {
        guard let at = advancedAt,
              Date().timeIntervalSince(at) < Self.advanceSwallow else { return false }
        advancedAt = nil
        return true
    }

    /// 넘김 제스처가 버튼 탭을 삼키는 창(초).
    private static let advanceSwallow: TimeInterval = 0.2

    /// 손을 따라 움직이는 비율 — 1이면 종이가 손에 붙어 날아가고, 낮으면 무겁다.
    private static let deckLiftDamping: CGFloat = 0.6
    /// 끝까지 끌어 넘기는 변위 — 옛 닫기 판정값 그대로다(이미 손에 익은 거리).
    private static let deckAdvanceDistance: CGFloat = 36
    /// 튕겨 넘기는 예측 변위 — 감속까지 더한 예측이라 실제 변위보다 크게 잡는다.
    private static let deckAdvancePredicted: CGFloat = 120

    /// 하단 더미를 밀어 커버를 닫는 변위(57차-a) — `deckAdvanceDistance`(36)를 그대로 쓰면 "다음
    /// 카드를 보려던" 손이 커버 전체를 닫아 버린다. 덱 한 장의 히트 영역(74, `FridgeCardHead` 주석)을
    /// 웃도는 값으로 잡아 "카드 한 장을 넘긴다"가 아니라 "더미 전체를 밀어 치운다"는 힘이 실렸을
    /// 때만 반응한다.
    private static let deckDismissDistance: CGFloat = 100
    /// 닫기의 예측 변위 — `deckAdvancePredicted`가 `deckAdvanceDistance`의 ≈3.3배였던 기존 비율을
    /// 그대로 유지해, 짧고 강한 플릭도 "다음 카드"보다 세게 던져야 닫기로 커밋되게 한다.
    private static let deckDismissPredicted: CGFloat = 330

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

    /// 목록 조작 한 줄 — 좌: **질의**(카테고리 필터 + 정렬) / 우: **렌더러**(보기 토글).
    ///
    /// **49차에 관절을 다시 잡았다.** 옛 분기는 "좌=무엇을 보이는가 / 우=어떻게 보이는가(순서·밀도)"로
    /// 정렬을 토글 쪽에 붙였다. 실재하는 구분이긴 하나 관절이 틀렸다 — 판별은 한 문장으로 끝난다:
    /// **"이 컨트롤을 만지면 목록 맨 위 항목이 바뀌는가?"** 필터는 바뀌고(집합이 달라진다),
    /// 정렬도 바뀌고(같은 집합, 다른 1번), 보기 토글은 **안 바뀐다**(같은 집합·같은 순서, 셀 템플릿만).
    /// 즉 필터와 정렬은 둘 다 *목록을 만들어 내는 질의 파라미터*고 토글만 *결과를 그리는 설정*이다.
    /// 정렬의 "어떻게"는 데이터의 순서, 토글의 "어떻게"는 픽셀의 밀도 — 두 "어떻게"는 다른 층이다.
    /// (레퍼런스 감사: 여러 앱이 정렬·필터를 아예 한 진입점 "Sort and filter"로 합치는 반면,
    /// 보기 모드는 예외 없이 별도 구역·별도 줄로 떼어 놓는다.)
    ///
    /// 참고로 이 변경은 **빈 폭을 줄이지 않는다**(실측 163 → 168pt). 근거는 여백이 아니라
    /// 그 여백이 **어느 쌍을 가르느냐**다 — 이제 질의 둘이 붙고, 그 사이가 아니라 질의와 렌더러 사이가 벌어진다.
    private func controlRow(_ list: ListDigest) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            // 카테고리가 한 종류뿐이면 필터가 무의미하다 — 칩 행 시절과 같은 규칙(동작 없는 UI 금지).
            if list.categories.count > 1 { categoryMenu }
            sortMenu
            Spacer(minLength: ReffiSpace.s2)
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
                    // 좌측 묶음 후 카테고리 칩과 폭을 나눠 쓴다(49차) — 큰 글자·긴 라벨에서 줄바꿈 방지.
                    .lineLimit(1)
            }
            .foregroundStyle(ReffiColor.ink)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                // 소형 **행동** 면의 정본은 8각 종이컷이다(§13.1). `PaperRect(.sm)`이던 시절 이 칩은
                // 둥근 사각으로 그려졌다 — 반지름 8은 면 높이(≈32)의 절반에 한참 못 미쳐 캡슐 퇴화
                // 라우팅이 돌지 않기 때문이다. 셰이프는 **역할로 고른다**: 크기가 비슷해도 읽는 면
                // (뱃지·카드)은 `PaperRect`, 손이 누르는 면은 여기다. 되돌리면 바로 위 탭 알약(각짐)과
                // 같은 줄에서 혼자 둥근 컨트롤이 되고, 오너가 지적한 "각진 것과 둥근 것이 규칙 없이
                // 섞임"이 한 줄 안에서 재현된다.
                let s = PaperCutRect(seed: 5)
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
                .padding(ReffiSpace.s2)
                .background {
                    // 위 정렬 칩과 **같은 계층인데 프리미티브가 다르다** — 이 면은 30×30 정사각이고
                    // `PaperCutRect`의 잘림은 `min(높이 32%, 폭 12%)`라 폭 쪽이 3.6pt로 눌려 8각이
                    // 아니라 그냥 사각으로 읽힌다. 잘림을 **짧은 변**에 매단 형제가 `PaperChipCut`이다
                    // (30pt에서 7.8pt). 정사각에 가까운 칩에 `PaperCutRect`를 쓰지 마라.
                    let s = PaperChipCut(seed: 6)
                    s.fill(ReffiColor.paper).paperEdge(s)
                }
                .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)   // §7.3
                .contentShape(Rectangle())
                // 히트 44가 시각 30을 우측선 안쪽으로 밀었다 — 마진 라인으로 되민다(§7.3·42차).
                .edgeAligned(.trailing, visual: 30)
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(compact ? "Switch to stack view" : "Switch to simple view")
    }

    /// 빈 상태 — **그림 · 제목 · 문장**(49차). 텍스트 두 줄뿐이던 자리에 글리프를 세워 To buy 빈
    /// 카드와 같은 3요소 골격으로 맞춘다(두 빈 상태가 같은 탭 안에서 다른 완성도로 서 있었다).
    /// 여기 행동 행을 넣지 않는 것은 이 화면의 추가 경로가 **전역 ＋ 탭**이라, 카드 안에 또 하나
    /// 만들면 같은 목적지가 한 화면에 둘이 되기 때문이다(To buy는 자기 검색 시트를 갖고 있어 다르다).
    private var emptyState: some View {
        HStack(spacing: ReffiSpace.s3) {
            FoodMotif(glyph: .root)
                .frame(width: ReffiFoodIcon.row, height: ReffiFoodIcon.row)
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                Text("Nothing here yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                Text("Add ingredients and they’ll stack up here.")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        // 톱니는 면 안쪽으로 파고들어 그만큼 여백을 먹는다 — 세로만 보정한다(`receiptSurface`와 같은 식).
        // 옛 `.padding(ReffiSpace.s5)` 한 줄에 보정을 더하면 가로까지 24→31로 함께 밀린다.
        .padding(.vertical, ReffiSpace.s5 + ReffiTooth.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // 이 자리에 서는 것은 컨트롤이 아니라 **콘텐츠 종이**다 — 재고가 있으면 영수증 카드가
            // 설 자리라, 같은 자리를 둥근 사각이 채우면 목록의 셰이프 언어가 빈 상태에서만 갈린다.
            //
            // `.receiptSurface(elevated: .flat)`로 접지 않는 이유: 그 모디파이어의 면색은
            // `ReffiColor.receipt` 하드코딩이라 빈 상태의 `sub`(조용한 안내 면)가 조용히 흰 영수증으로
            // 갈아탄다. 셰이프 라운드에서 곁다리로 옮길 토큰이 아니다.
            let s = ReceiptShape(tooth: ReffiTooth.card, seed: 3)
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

    /// 상세 열기 — 목록에서 들어오는 길도, 밀어 다음/이전으로 넘어오는 길도 여기다.
    ///
    /// **캡(`receiptHeight`)은 여기서 건드리지 않는다.** 재료마다 다시 재야 하는 것은 맞지만
    /// (이름이 두 줄이 되거나 값이 줄바꿈되면 두 재료의 영수증 높이가 실제로 갈린다), 그 일은 이제
    /// 컨테이너 측정이 한다 — 겹쳐 세운 ZStack이 전환 중에는 max(나가는 것, 들어오는 것)을,
    /// 정착하면 새 재료의 참 높이를 보고한다. 옛 `receiptHeight = 0` 대입은 그 한 프레임 동안 캡을
    /// `.infinity`로 열어, `layoutPriority(1)` 스크롤 뷰가 남는 높이를 다 먹고 **판정 버튼과 덱이
    /// 한 프레임 아래로 튀었다가 돌아오게** 만들었다. 전환이 보이기 시작한 지금은 그 튐도 보인다.
    ///
    /// `direction`은 펼침 전환의 앵커만 정한다 — 레이아웃에는 아무 영향이 없다.
    private func select(_ ing: Ingredient, direction: AdvanceDirection = .tap) {
        advanceDir = direction
        withAnimation(motion) { selectedID = ing.id }
    }
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

fileprivate extension Ingredient {
    /// 이 재료의 종이 시드 — 절취선 위상과 종이 결이 **재료마다** 갈리게 한다.
    ///
    /// 냉장고의 종이는 전부 이 한 값을 쓴다(스택 카드·간편 행·덱 머리·펼친 상세). 같은 재료를
    /// 보여 주는 네 표면이 같은 시드를 공유해야 보기를 토글하거나 상세를 펼쳐도 **가위 자국이
    /// 제자리에 있다** — 표면마다 다른 식으로 시드를 만들면 모핑 도중 절취선이 갈아탄다.
    ///
    /// 하필 UUID 바이트인 이유: 목록은 임박순으로 정렬돼 있어 이웃한 카드들의 `daysLeft`가
    /// 실제로 같은 값인 구간이 흔하다. 남은 일수로 시드를 만들면 그 구간이 통째로 같은 절취선이
    /// 되어 "오려 낸 종이"가 "찍어 낸 패턴"으로 읽힌다(§13.1). 그리고 UUID는 날이 바뀌어도
    /// 그대로라, 자정에 D-day가 갱신돼도 종이 모양은 흔들리지 않는다.
    var receiptSeed: Int {
        let u = id.uuid
        return Int(u.0) | (Int(u.1) << 8) | (Int(u.2) << 16)
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
        let shape = ReceiptShape(tooth: ReffiTooth.card, seed: ingredient.receiptSeed)
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
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                    nameText.lineLimit(1)
                    quantityText
                }
                Spacer(minLength: ReffiSpace.s2)
                frozenStamp
                dDayText
            }
        }
        .padding(.horizontal, ReffiSpace.s4)
        // 톱니가 위아래로 파고든 만큼을 세로 여백에 되돌려 준다(`receiptSurface`와 같은 식).
        // 행 높이 60 → 66. 간편보기의 존재 이유가 스캔 밀도라 카드류의 s5가 아니라 s2에서 시작한다.
        .padding(.vertical, ReffiSpace.s2 + ReffiTooth.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // **스택 카드와 같은 종이여야 한다.** 이 행과 스택 카드는 같은 데이터의 다른 밀도인데
            // (보기 토글 한 번으로 서로 갈아탄다) 한쪽만 둥근 사각이면 토글이 밀도가 아니라
            // 셰이프 언어를 바꾸는 조작이 된다. 목록 행·카드 면의 정본은 `ReceiptShape`다(§13.1).
            shape.fill(ReffiColor.receipt)
                .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(ingredient.receiptSeed)) &+ 23,
                                    strength: 0.4)
                    .clipShape(shape))
        }
        .paperEdge(shape)
        // **그림자 앞에 반드시 합성 그룹.** `.shadow`는 붙인 뷰를 합쳐서 드리우는 게 아니라 자식
        // 프리미티브마다 따로 드리운다 — 묶지 않으면 그레인 반점 하나하나가 자기 그림자를 얻고,
        // `.overlay` 블렌드가 아래에 깔린 다른 카드로 새어 나간다(`receiptSurface`가 세운 규약).
        .compositingGroup()
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
            .font(.reffiNum(.body, for: ingredient.dDayText))   // ko "오늘"·"3일" 폴백(§3.4·42차)
            .foregroundStyle(ingredient.freshness.dark)   // §2.6 캔버스/종이 위 색-텍스트는 dark
            .accessibilityLabel(ingredient.dDayAccessibilityText)
    }
}

/// 흰 영수증 카드 한 장 — ReceiptShape + 종이질감 + 음식 실루엣 + 이름. 색은 Due date에만(임박 신호).
///
/// **스택 보기 전용이다**(하단 덱은 `FridgeCardHead`).
///
/// 종이 시드는 인자로 받지 않는다 — 재료가 직접 낸다(`receiptSeed`). 받는 형태로 두면 호출부가
/// 표면마다 다른 식으로 시드를 만들고(인덱스·남은 일수…), 같은 재료의 스택 카드와 간편 행이
/// 서로 다른 절취선을 갖게 되어 보기 토글이 종이를 갈아치우는 조작으로 읽힌다. 실제로 예전
/// 인자(`depth`·`seed`)는 두 호출부가 서로 다른 값을 성실히 넘기는 동안 본문이 한 번도 읽지 않았다.
struct FridgeCard: View {
    let ingredient: Ingredient
    var height: CGFloat = 128

    private let toothH: CGFloat = ReffiTooth.card

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH, seed: ingredient.receiptSeed)

        // **재단(49차)** — 좌측 정렬선을 둘로 줄인다. 옛 배치는 카테고리와 실루엣이 같은 좌 24선을
        // 공유했는데, 실루엣 글리프가 46pt 상자를 채우지 않아(여백 6~11pt) 카드마다 두 요소의
        // **렌더 좌변이 1.6~11.4pt씩 어긋났다**(실캡처 4장 실측). 명목상 한 선인데 눈에는 두 선이라,
        // "개별 요소는 다 맞는데 화면 전체가 자로 안 잰 느낌"의 물리적 정체가 이것이었다.
        // 카테고리를 **이름 아래로** 옮겨 좌 24선에는 실루엣만 남긴다 — 랙이 구조적으로 소멸하고,
        // 카테고리가 자기가 수식하는 이름에 붙어 정보 관계도 맞아진다(낭독도 이름이 먼저 온다).
        //
        // **도장은 이름 행에 내리지 않는다.** 46차가 `ExpandedFridgeCard`에서 같은 배치를 금지했고
        // 그 근거를 이번에 스택 카드 폭(334)으로 재측정해도 성립한다: 이름 가용폭이 228 → 최악
        // 62pt(ko "기한 지남" + "냉동")로 무너져 "닭가슴살"이 잘린다. 도장은 자기 코너에 남는다.
        return VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            // 상단 행 — [FROZEN] + D-day 도장(우 상단 코너). 급한 것이 코너에서 먼저 읽힌다.
            // 냉동은 스택을 쪼개지 않고(영수증 더미 메타포 유지) 도장 하나로 구분한다(§13).
            HStack(alignment: .top, spacing: ReffiSpace.s2) {
                Spacer(minLength: 0)
                if ingredient.isFrozen {
                    DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 12)
                }
                DDayStamp(text: ingredient.dDayText, color: f.dark, size: 17,
                          caps: false, accessibilityLabel: ingredient.dDayAccessibilityText)
            }
            HStack(spacing: ReffiSpace.s3) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: ReffiFoodIcon.card, height: ReffiFoodIcon.card)
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                    Text(verbatim: ingredient.displayName)
                        .reffiType(.subhead).foregroundStyle(ReffiColor.ink).lineLimit(1)
                    // 카테고리는 영문 캐논 저장 — 표시만 로컬라이즈. 이름의 종속 메타라 한 단 내린다
                    // (`caption`/ink2 → `metaText`/muted: §3.5 데이터형 메타 · SettingsRow의 라벨>값과 같은 방향).
                    Text(LocalizedStringKey(ingredient.category))
                        .reffiType(.metaText).foregroundStyle(ReffiColor.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s4 + toothH)
        .padding(.bottom, toothH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background {
            shape.fill(ReffiColor.receipt)
                .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(ingredient.receiptSeed)) &+ 23,
                                    strength: 0.4)
                    .clipShape(shape))
        }
        .paperEdge(shape)
        // **여기서 반드시 묶는다.** 이 카드는 음수 spacing으로 서로 겹쳐 쌓이므로, 합성 그룹이 없으면
        // ① 그레인의 `.overlay` 블렌드가 밑에 깔린 카드로 관통하고 ② `.shadow`가 자식 프리미티브마다
        // 따로 걸려 그레인 Canvas가 자기 그림자를 얻는다(`receiptSurface`가 실측으로 세운 규약).
        .compositingGroup()
        .reffiShadowCardCompact()   // 겹쳐 쌓이는 카드라 얕은 단
    }
}

/// 덱 한 장 — 영수증의 **머리**만 담은 온전한 종이 조각(위·아래 절취선이 다 있다).
///
/// 170pt 카드를 잘라 쓰지 않는 이유가 이 타입의 존재 이유다: `ReceiptShape`는 rect의 위·아래
/// 양변에 톱니를 그리므로 사각으로 오려 내면 아래 절취 엣지가 통째로 사라져 "뜯은 종이"가 아니라
/// "잘린 그림"이 된다. 높이는 콘텐츠로 정해지고(36 + (12 + 7)×2 = 74pt), 그 값이 곧 히트 영역이라
/// §7.3의 44를 넘긴다 — 옛 하단 스택에서 한 장이 드러내던 띠는 2.2pt였다.
struct FridgeCardHead: View {
    let ingredient: Ingredient
    /// 글자 없는 빈 종이 — 덱 뒤의 노출 띠. 앞 장 톱니 골로 반쪽 글리프가 새지 않게 한다
    /// (티켓 덱의 `peek`가 세운 규약). **높이를 유지해야** 앞 장과 겹의 두께가 같으므로
    /// 뷰를 빼지 않고 투명도로 지운다.
    var blank: Bool = false

    private let toothH: CGFloat = ReffiTooth.card

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH, seed: ingredient.receiptSeed)
        return HStack(spacing: ReffiSpace.s3) {
            PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                .frame(width: ReffiFoodIcon.row, height: ReffiFoodIcon.row)
            Text(verbatim: ingredient.displayName)
                .reffiType(.subhead).foregroundStyle(ReffiColor.ink).lineLimit(1)
            Spacer(minLength: ReffiSpace.s3)
            if ingredient.isFrozen {
                DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 11)
            }
            DDayStamp(text: ingredient.dDayText, color: f.dark, size: 14,
                      caps: false, accessibilityLabel: ingredient.dDayAccessibilityText)
        }
        .opacity(blank ? 0 : 1)
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s3 + toothH)   // 톱니 인셋 보정
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(ReffiColor.receipt)
                .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(ingredient.receiptSeed)) &+ 23,
                                    strength: 0.4)
                    .clipShape(shape))
        }
        .paperEdge(shape)
        .compositingGroup()   // 겹쳐 서는 종이 — 위 `FridgeCard` 주석의 같은 이유
        .reffiShadowCardCompact()
        .accessibilityElement(children: .combine)
    }
}

/// 펼친 상세 — 흰 영수증 한 장에 큰 일러스트 + 구매 정보(영수증 명세). 색은 Due date에만.
///
/// **컴포지션은 위에서 아래로 네 층이다: 크라운(카테고리·편집) / 히어로(실루엣 + 겹쳐 찍은 도장) /
/// 이름 / 절취선 + 명세.** 옛 배치는 실루엣 오른쪽 한 칸에 그 넷을 다 욱여넣어, 이름과 D-day 도장이
/// **같은 한 줄에서 폭을 다퉜다**. 그 줄의 가용폭은 197pt인데 'Overdue' 도장 한 개가 83pt를 먹고
/// 24pt Bold 이름은 100pt대라, 한 단어짜리 재료명(mushroom)은 줄바꿈이 불가능해 tail로 잘렸다.
/// **이름에 자기 줄을 통째로 주면 그 경합이 구조적으로 사라진다** — 폭을 다툴 상대가 없다.
/// 도장을 다시 이름 옆으로 되돌리지 마라: 도장 폭은 라벨 길이(언어마다 다르다)를 따르고 이름 폭도
/// 재료마다 다르므로, 둘을 한 줄에 두는 배치에는 "잘리지 않는" 폭이 존재하지 않는다.
struct ExpandedFridgeCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}
    private let toothH: CGFloat = ReffiTooth.card

    /// 히어로 실루엣 한 변 — 상태 도장을 **위에 겹쳐 찍는** 크기(`ReffiFoodIcon.detail`).
    ///
    /// 옛 `hero`(64)로는 안 된다: 도장 한 개의 폭이 'Overdue'에서 83pt라 실루엣보다 넓어 그림을
    /// 덮어 버린다. 반대로 더 키우면 카드가 뷰포트를 넘겨 영수증이 잘린 채 선다(기본 글자 크기
    /// iPhone 17에서 실측: 120이면 55pt 초과). 도장 폭과 카드 높이 예산 사이의 값이다.
    private static let heroSide: CGFloat = ReffiFoodIcon.detail

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH, seed: ingredient.receiptSeed)

        return VStack(alignment: .leading, spacing: 0) {
            // ① 크라운 — 카테고리 한 줄. 편집은 **행의 자식이 아니라 카드 오버레이**다(아래 body 끝):
            //    44pt 히트 타깃이 행 안에 있으면 그 행이 44pt로 자라 카드 높이를 그만큼 먹는데,
            //    이 화면은 판정 버튼·덱이 스크롤 밖에 도킹돼 영수증 몫이 고정이라 그 24pt가 곧
            //    마지막 명세 행의 자리다(실측: 편집을 행에서 빼야 Storage 행까지 들어온다).
            //    히트 영역은 오버레이에서 그대로 44를 지킨다 — 줄이는 게 아니라 겹치는 것이다.
            Text(LocalizedStringKey(ingredient.category))   // 카테고리는 영문 캐논 저장 — 표시만 로컬라이즈
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, ReffiChrome.tapMin)   // 오버레이 편집 버튼이 앉을 자리를 비워 둔다
                .padding(.horizontal, ReffiSpace.s5)
                .padding(.top, ReffiSpace.s3 + toothH)
            // 도장이 시각적으로 이름 위에 오면서 보조기술의 기본 순서가 뒤집힌다 — 종전 순서
            // (카테고리·편집 → 이름 → 상태)를 명시적으로 고정한다. 큰 값이 먼저 읽힌다.
            .accessibilitySortPriority(3)

            // ② 히어로 — 일러스트 한 장 **위에** 상태 도장을 겹쳐 찍는다(온보딩 접시 도장의 선례).
            //    도장이 여기로 오면서 이름 줄에서 폭을 빼앗지 않는다. 도장 묶음은 실루엣 상자의
            //    오른쪽 위로 조금 넘어가 앉는다 — 그림 위에 눌러 찍은 인상은 그 걸침에서 나온다.
            //    냉동은 D-day와 **함께** 선다(스택을 쪼개지 않고 도장 하나로 구분한다는 §13 규약).
            //    `ZStack`이 아니라 `overlay`인 이유: ZStack은 자식 중 가장 큰 것으로 커지므로,
            //    접근성 글자 크기에서 도장이 실루엣보다 넓어지는 순간 상자가 도장 폭으로 자라고
            //    그림이 top-trailing 정렬을 따라 오른쪽으로 밀린다. 오버레이면 레이아웃 크기는
            //    언제나 실루엣의 것이고 도장은 그 위로 **넘쳐도 된다**(양옆에 88pt 여유가 있다).
            PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                .frame(width: Self.heroSide, height: Self.heroSide)
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: ReffiSpace.s1) {
                        if ingredient.isFrozen {
                            DDayStamp(text: String(localized: "FROZEN"), color: ReffiColor.blueDark, size: 12)
                        }
                        DDayStamp(text: ingredient.dDayText, color: f.dark, size: 17,
                                  caps: false, accessibilityLabel: ingredient.dDayAccessibilityText)
                    }
                    // 오버레이는 실루엣 상자를 제안폭으로 받는다 — 고정하지 않으면 ko "기한 지남"이
                    // 120pt에 눌려 도장 안에서 줄바꿈된다(각인은 한 줄이어야 도장으로 읽힌다).
                    .fixedSize()
                    .offset(x: ReffiSpace.s3, y: -ReffiSpace.s2)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilitySortPriority(1)

            // ③ 이름 — 한 줄을 통째로 쓴다. 폭 경합이 없으므로 트런케이트가 성립하지 않고,
            //    긴 이름·큰 글자는 잘리는 대신 두 줄로 흐른다(§7.3 잘림 금지).
            Text(verbatim: ingredient.displayName)
                .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ReffiSpace.s5)
                // 그림과 이름은 **한 덩어리**다(무엇인가를 함께 말한다) — 위는 좁게 붙이고,
                // 아래 절취선까지는 그대로 둬 이름이 명세 표가 아니라 히어로에 속하게 한다.
                .padding(.top, ReffiSpace.s1)
                .padding(.bottom, ReffiSpace.s2)
                .accessibilitySortPriority(2)

            dashRule
            VStack(spacing: 0) {
                row("Purchased", ingredient.purchasedText)
                // 가게 이름·보관 위치는 숫자가 아니다 — §3.4의 GSF tabular 의무는 데이터 숫자에만
                // 걸리므로 이 두 행은 `metaText`로 내린다(`SettingsRow.numeric`과 같은 갈림, 42차).
                row("Where", ingredient.placeText, numeric: false)
                row("Quantity", ingredient.quantityText)
                // D-day는 카드 상단 스탬프가 이미 말한다 — 같은 값을 '· 3d'로 되풀이하지 않는다
                // (오너 승인·43차 이관: 한 카드에서 같은 사실은 한 번만).
                row("Use by", ingredient.expiresText, valueColor: f.dark)
                row("Storage", ingredient.storage.label, numeric: false)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s2)

        }
        .padding(.bottom, ReffiSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, toothH)
        // 편집 — 크라운 줄과 **겹쳐** 앉는다(위 ① 주석). 시각은 카드 정렬선에, 히트는 44pt.
        .overlay(alignment: .topTrailing) {
            Button(action: onEdit) {
                ReffiIcon.manual.reffi(16, .bold)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(width: ReffiChrome.tapMin, height: ReffiChrome.tapMin)   // §7.3 최소 터치 타깃
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Edit")
            .accessibilitySortPriority(3)
            // 히트 상자(44)의 중심을 카테고리 글줄에 맞추고, 시각 아이콘을 카드 정렬선(s5)에 세운다.
            .padding(.trailing, ReffiSpace.s5 - (ReffiChrome.tapMin - 16) / 2)
            .padding(.top, ReffiSpace.s3 + toothH - (ReffiChrome.tapMin - 16) / 2)
        }
        .background {
            shape.fill(ReffiColor.receipt)
                .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(ingredient.receiptSeed)) &+ 23,
                                    strength: 0.4)
                    .clipShape(shape))
        }
        .paperEdge(shape)
        .compositingGroup()   // 그레인 블렌드·그림자를 종이 한 장 몫으로 묶는다(위 `FridgeCard` 주석)
        .reffiShadowCard()
    }

    /// 명세 한 줄 — 라벨(좌) + 값(우).
    ///
    /// **라벨과 값은 한 요소로 읽는다**(`FridgeCompactRow`·History와 같은 문법): 나누면 다섯 줄이
    /// 열 개 요소가 되고, "Use by" 다음 스와이프에서야 날짜가 나온다. `spokenValue`는 화면 표기가
    /// 축약일 때 그 자리에 대신 읽을 말이다(축약은 눈에만 통한다).
    private func row(_ label: LocalizedStringKey, _ value: String,
                     valueColor: Color = ReffiColor.ink,
                     spokenValue: String? = nil,
                     numeric: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer(minLength: ReffiSpace.s4)
                Text(value)
                    .font(numeric ? .reffiNum(.body, for: value) : ReffiActionRole.metaText.font)
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text(verbatim: spokenValue ?? value))
            }
            // s1 — 다섯 줄이 한 표로 읽히는 밀도. s2로 벌리면 표가 카드 밖으로 밀려
            // 마지막 행(Storage)이 스크롤 뒤로 숨는다(실측). 히트 타깃이 아니라 읽는 표라
            // 44pt 하한이 걸리지 않는다.
            .padding(.vertical, ReffiSpace.s1)
        }
        .accessibilityElement(children: .combine)
    }

    private var dashRule: some View {
        ReffiRule(.receipt).padding(.horizontal, ReffiSpace.s5)
    }
}

