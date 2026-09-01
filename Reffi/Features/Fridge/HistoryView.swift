import SwiftUI
import PhosphorSwift

/// History 본문 — 소비/버림 이력을 종이컷 카드로(§13).
/// ① 이번 주 히어로(숫자 헤드라인 + 추세 화살표 + 종이 칩 일곱) ② 정산서(먹음·버림·요리 세 행 +
/// 낭비율 도장 + 자주 버린 재료 TOP 3) ③ 타임라인.
///
/// **커버 크롬(헤더·닫기)을 갖지 않는 임베더블 본문**이다 — 지금 호출부는 냉장고 History 탭
/// (`FridgeView.pane`) 하나뿐이고, 그 자리는 헤더 대신 `bottomPadding`만 넘긴다. 커버가 다시
/// 필요해지면 **이 본문을 감싸는 래퍼**를 세운다(옛 `HistoryView` 커버가 그 형태였다) — 본문 안에
/// 헤더를 들이면 탭 패인에서 제목이 두 번 서고, 그때부터 두 표면이 같은 규칙을 각자 적게 된다.
struct HistoryContent: View {
    /// 스크롤 꼬리 여백 — 커버는 기본값(`s6`), 떠 있는 캡슐 네비가 있는 탭 패인은 `navClearance`.
    var bottomPadding: CGFloat = ReffiSpace.s6

    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 추세 화살표의 실제 크기(35차) — 기준 20pt에 **히어로 숫자와 같은 램프**를 건다.
    /// `relativeTo:`가 `.largeTitle`인 것은 우연이 아니라 짝 맞추기다: 숫자가
    /// `reffiNum(.hero)` = `.custom(size: 32, relativeTo: .largeTitle)`이라, 같은 텍스트
    /// 스타일을 기준으로 잡아야 둘이 **같은 비율로** 커진다(다른 스타일을 잡으면 접근성
    /// 크기 어디선가 화살표만 앞서거나 뒤처진다). 이 앱에서 아이콘이 타입을 따라 커지는
    /// 것은 여기가 처음이다 — `ReffiIcon.reffi(_:)`는 고정 프레임이고 그대로 둔다:
    /// 다른 아이콘은 **글자 곁이 아니라 자기 자리**에 서는 크롬·장식이라 같은 근거가 없다.
    /// 이 화살표만 다른 이유는 33차에 추세 문장을 걷어내며 **화면상 유일한 추세 전달자**가
    /// 됐다는 것이다 — 큰 글자를 쓰는 사용자에게서 정보가 사라지면 안 된다.
    @ScaledMetric(relativeTo: .largeTitle) private var trendArrowSize: CGFloat = 20

    /// 정산서에 세우는 자주 버린 재료 줄 수 — 영수증 한 장이 삼키는 상한.
    private static let topTossedLimit = 3

    /// 타임라인 한 번에 세우는 행 수 — 첫 화면에도, "더 보기" 한 번에도 같은 값.
    /// 이력은 2000건까지 쌓이는데(`FridgeStore.historyCap`) 행마다 실루엣 Canvas가 한 장이라,
    /// 상한 없이 세우면 History를 여는 **첫 프레임의 비용이 쌓인 이력 수에 비례**한다.
    private static let timelinePage = 60

    /// 지금 타임라인에 세운 행 수 — "더 보기"가 한 페이지씩 늘린다.
    @State private var timelineShown = HistoryContent.timelinePage

    // MARK: - 칩 캡션 힌트 닫기(28차 칩 히어로의 캡션을 31차에 닫을 수 있게)

    /// 칩 문법(면색=먹었는가·배지=버림 개수) 설명 캡션을 사용자가 닫았는가 — 설치당 한 번이라
    /// `@AppStorage`다(`toBuy.swipeHintSeen`과 같은 점 구분 네임스페이스 규약). 한 번 닫으면 다시
    /// 뜨지 않는다 — 문법을 한 번 읽고 나면 또 볼 필요가 없다(owner 판단).
    @AppStorage("history.chipHintDismissed") private var chipHintDismissed = false

    #if DEBUG
    /// `-history.chipHintForce` 파싱 — 유닛 테스트가 인자 배열을 직접 넣어 검증한다(`swipeHintConfig`와
    /// 같은 결 — 뷰에서 분기를 늘리는 대신 순수 함수로 뗀다).
    static func chipHintForced(in arguments: [String]) -> Bool {
        arguments.contains("-history.chipHintForce")
    }
    /// 프로세스당 한 번만 파싱(`swipeHint` 선례).
    private static let forcesChipHint = chipHintForced(in: ProcessInfo.processInfo.arguments)
    #endif

    /// 힌트 강제 표시(QA, DEBUG 전용) — 이미 닫힌 뒤에도 플래그와 무관하게 다시 보이게 한다
    /// (`-toBuy.swipeHint` 강제 인자와 같은 결). 반대로 "닫힌 채로 재현"은 UserDefaults 인자
    /// `-history.chipHintDismissed YES`를 쓴다 — `-toBuy.swipeHintSeen YES` 선례 그대로,
    /// NSUserDefaults가 커맨드라인 인자를 자동으로 도메인에 얹어 주므로 이쪽은 커스텀 파싱이 필요 없다.
    /// 강제 표시 세션에서도 **이번 세션의 X는 이긴다** — `-toBuy.swipeHint`에서 사용자의 실제
    /// 스와이프가 재생을 취소하는 규약과 같다. 이게 없으면 강제 세션에선 X가 죽은 버튼이 된다.
    @State private var chipHintDismissedNow = false

    private var showsChipHint: Bool {
        if chipHintDismissedNow { return false }
        #if DEBUG
        if Self.forcesChipHint { return true }
        #endif
        return !chipHintDismissed
    }

    /// 닫은 뒤 VoiceOver 포커스가 사라진 요소에 뜬 채로 남지 않게 칩 행으로 옮긴다.
    @AccessibilityFocusState private var chipRowFocused: Bool

    private var logs: [RemovalLog] { store.history }

    /// 정산서 파생값의 **단일 계산 지점**(42차·F88 잔여) — `MainView.CounterDigest`·`FridgeView.ListDigest`가
    /// 세운 "파생은 body 진입부에서 한 번" 규율을 이 화면에도 편다. 옛 computed 9종은 body 한 번에
    /// `store.recentHistory`(전량 filter+복사)를 11번 돌렸다 — 장식용 영수증 번호 하나에만 3번.
    /// History는 이제 커버가 아니라 패인이라 store 변이마다 body가 다시 돈다(이력 상한 2000건).
    @MainActor
    private struct Ledger {
        let recentEmpty: Bool
        let eaten: Int
        let tossed: Int
        let cooked: Int
        let rate: Int
        let topTossed: [(key: String, name: String, glyph: FoodGlyph, count: Int)]
        let streakDays: Int
        let pileGlyphs: [FoodGlyph]

        init(store: FridgeStore, logs: [RemovalLog], topLimit: Int) {
            let recent = store.recentHistory
            recentEmpty = recent.isEmpty
            eaten = recent.filter { !$0.wasted }.count
            tossed = recent.filter(\.wasted).count
            cooked = store.cookedCount
            rate = store.wasteRate

            // 자주 버린 재료 — 매칭 키(표기 무관)로 묶어 많은 순(표기로 묶으면 언어 전환 전후가 두 줄로 갈린다).
            let grouped = Dictionary(grouping: recent.filter(\.wasted)) { $0.matchKey }
            let rows: [(key: String, name: String, glyph: FoodGlyph, count: Int)] = grouped
                .compactMap { key, group in
                    group.first.map { (key: key, name: $0.displayName, glyph: $0.glyph, count: group.count) }
                }
            let ranked = rows.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            topTossed = Array(ranked.prefix(topLimit))

            // 무낭비 스트릭 — 마지막 버림 이후 경과일(버린 적 없으면 기록 시작부터). (PR #4 리포트 통합)
            if let last = logs.filter(\.wasted).map(\.daysAgo).min() { streakDays = last }
            else { streakDays = logs.map(\.daysAgo).max() ?? 0 }

            // 배경 더미 글리프 — 내 냉장고가 먼저, 그다음 이력. 같은 글리프는 한 번만.
            var seen = Set<FoodGlyph>()
            var result: [FoodGlyph] = []
            for glyph in store.ingredients.map(\.glyph) + logs.map(\.glyph) where seen.insert(glyph).inserted {
                result.append(glyph)
            }
            pileGlyphs = result
        }
    }

    /// 낭비율 색 — 임계값의 **단일 공급원**이다(색=정보, §1). 커버 배경 accent와 냉장고 History 탭의
    /// 배경 accent가 같은 함수를 읽는다: 세 곳이 각자 `switch`를 들고 있으면 한쪽만 조용히 어긋난다.
    static func rateColor(_ rate: Int) -> Color {
        switch rate {
        case ...10: ReffiColor.freshDark
        case ...30: ReffiColor.soonDark
        default:    ReffiColor.urgentDark
        }
    }


    /// 추세 화살표(33차) — 값 덩이 곁에 서는 작은 세모의 아이콘·색·UI 테스트 식별자.
    /// **`.same`이거나 지난 주 데이터가 없으면(`nil`) 화살표 자체가 없다** — `ConsumptionWeek.Trend`가
    /// 이미 "비슷한 주"인지 판정했고, 여기서는 그 결과를 그림 하나로 옮길 뿐이다(비슷한 주에 방향을
    /// 우기지 않는다). 색은 낭비율과 같은 축(나아짐 = `freshDark`, 나빠짐 = `urgentDark`) — 옛
    /// 추세 문장(26차)이 쓰던 색 그대로다. `testID`는 화면 문구가 아니라 식별자로 상태를 잡는
    /// UI 테스트 훅이다(`ticket.menuName` 선례) — 화살표가 없는 주는 식별자도 없어, "없음"이 곧
    /// 테스트가 확인하는 상태가 된다.
    static func trendArrow(_ trend: ConsumptionWeek.Trend?) -> (icon: Ph, color: Color, testID: String)? {
        switch trend {
        case .better: (ReffiIcon.trendUp, ReffiColor.freshDark, "history.hero.trendArrow.up")
        case .worse:  (ReffiIcon.trendDown, ReffiColor.urgentDark, "history.hero.trendArrow.down")
        case .same, nil: nil
        }
    }


    var body: some View {
        // 집계는 **본문당 한 번**만 돈다. computed로 두면 헤드라인·칩 행·추세 화살표·접근성 라벨이
        // 각자 이력을 다시 훑고, 그 사이에 자정이 지나면 한 화면 안에서 두 값이 다른 주를 가리킬 수 있다.
        let week = ConsumptionWeek.summary(of: logs)
        let ledger = Ledger(store: store, logs: logs, topLimit: Self.topTossedLimit)
        ScrollView {
            VStack(spacing: ReffiSpace.s4) {
                // 헤드라인 ↔ 히어로는 **s4(16)**, 위의 탭 행과는 s5(24, `FridgeView.fridgeHeader`가 준다).
                // To buy는 같은 자리에 s3(12)을 쓰는데 **여기서 값이 다른 이유는 읽히는 거리를 맞추기
                // 위해서다**(3x 캡처 실측): To buy의 다음 면은 톱니(`ReceiptShape`) 영수증이라 골이
                // 프레임 윗변보다 아래에 앉아 제목 잉크 바닥에서 면까지 **18pt**로 읽히는데, 히어로는
                // 전면 블리드 밴드라 윗변이 프레임 그대로 딱 떨어진다 — 같은 s3을 주면 13pt로 5pt
                // 더 붙어 'g' 디센더가 밴드 선에 닿는다. s4면 **17pt**로 To buy와 같아진다.
                // 값이 아니라 **읽히는 거리**를 토큰으로 맞춘 것이고, 위(24) : 아래(16)의 2:1 남짓한
                // 비율도 그대로라 제목은 여전히 자기가 이름 붙이는 것 쪽에 붙는다.
                VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                    headline
                    hero(week, ledger)
                }
                settlementCard(ledger)
                if !logs.isEmpty { timelineCard }   // 기록이 없으면 제목만 남은 빈 카드를 세우지 않는다
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.bottom, bottomPadding)
        }
        // 이력이 바뀌면 타임라인 상한을 **첫 페이지로 되돌린다**. "더 보기"는 지금 이 목록을 더
        // 보겠다는 뜻이지 앞으로 쌓일 것까지 미리 세우라는 뜻이 아니다 — 판정·되돌리기가 들어올
        // 때마다 예전 상한이 그대로 살아 있으면, History를 켜 둔 채 판정을 반복한 사람만 조용히
        // 수백 행짜리 첫 프레임을 다시 세우게 된다(상한을 둔 이유가 정확히 그것이다).
        .onChange(of: logs.count) { _, _ in timelineShown = Self.timelinePage }
    }

    /// 패인 헤드라인 — To buy의 `Grocery memo`와 **같은 문법**(카드/밴드 밖, `heading` 24, leading 마진,
    /// `.isHeader`, 스크롤과 함께 걷힘)이다. 이름이 `History`가 아니라 **`Kitchen ledger`**인 것이
    /// 이 줄이 존재할 수 있는 이유다: 23차는 "History 헤드라인은 바로 위 탭 라벨과 같은 말이 두 번
    /// 서는 것"이라며 두지 않기로 했는데, 그 근거는 헤드라인 자체가 아니라 **중복된 이름**에 있었다.
    /// 탭 라벨은 목적지 이름("History")이고 헤드라인은 이 패인이 무엇을 담은 종이인가("주방 장부")라,
    /// 이름이 갈리면 두 줄이 서로 다른 일을 한다 — To buy의 탭 라벨("To buy")과 헤드라인
    /// ("Grocery memo")이 갈려 있는 것과 정확히 같은 관계다.
    ///
    /// role이 `.heading`(24)인 근거는 17차와 같다(§3.2): `display`=화면 제목("Fridge") ·
    /// `heading`=**패인 전체**를 이름 붙이는 제목 · `subhead`=**카드 이름**(아래 "Tally · past 30 days").
    /// 세 층이 한 화면에 34 → 24 → 18로 서서 위계가 그대로 읽힌다.
    private var headline: some View {
        Text("Kitchen ledger")
            .reffiType(.heading)
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: ① 이번 주 히어로 — 숫자 헤드라인 + 추세 화살표 + 종이 칩 일곱
    //
    // **창은 이번 주다**(정산서의 30일이 아니라). 바로 아래 칩 행이 이번 주 7일이므로, 헤드라인만
    // 30일이면 한 블록 안에서 서로 다른 두 책을 읽게 된다 — 옛 도넛이 링과 가운데 숫자에 다른 분모를
    // 놓아 실패한 지점이 정확히 그것이다(§13.9). 칩 일곱의 합이 곧 헤드라인의 분자라, 화면에서
    // 눈으로 검산된다. 30일 수치는 아래 정산서가 자기 라벨과 함께 계속 말한다.
    //
    // **고리가 아니라 칩인 이유**는 히어로가 두 가지 일을 동시에 해야 한다는 데 있다: 비율 하나와
    // 7일 각각. 연속 호는 앞의 하나만 담을 수 있어 뒤의 일곱을 위해 둘째 그래픽(요일 블롭 행)을
    // 붙여야 했고, 그 결과 한 밴드 안에 **문법이 둘**이었다. 낱개 사건 일곱에는 낱개 마크가 맞고,
    // 그러면 비율은 그냥 숫자로 세우면 된다 — 값 하나를 위한 가장 정확한 형태는 값 그 자체다.
    // `PaperRing`은 레포에 남는다(이 표면에서 물러날 뿐이다).
    //
    // 전면 블리드(`-ReffiGrid.margin`)는 카테고리 칩 행이 쓰던 관용구 그대로다 — 히어로는 카드가
    // 아니라 패인이 앉은 **바닥 면**이라 좌우 마진에 갇히면 카드 한 장으로 오해된다.
    //
    // **밴드 바탕은 화면 배경과 같은 `canvas`다(`paperPass`가 아니라).** "바닥 면"이라 적어 놓고
    // 실제로는 배경과 다른 토큰의 불투명 사각을 전면 블리드로 깔고 있었고, `PaperGlyphPile`은
    // `.clipped()`로 잘리므로 밴드 위·아래에 하드 가로선이 두 개 생겼다 — 스크롤하면 그 두 선이
    // 화면을 세 층으로 갈랐다. 바닥 면이라는 말이 참이 되려면 바탕이 바닥과 같은 토큰이어야 하고,
    // 그러면 경계는 고칠 대상 자체가 없어진다. 이 자리를 다시 `paperPass`로 되돌리면 그 두 선이
    // 함께 돌아온다 — 밴드를 눈에 띄게 하고 싶으면 색면이 아니라 실루엣 더미 농도를 만질 것.
    //
    // 대비는 두 스킴에서 함께 좋아진다: 라이트는 바탕이 밝아지고(L .95 → .97) 다크는 어두워져
    // (L .24 → .215) 잉크와의 거리가 양쪽 다 벌어진다. §13.10에 적힌 실측치는 `paperPass` 기준이라
    // 이제 **보수적 하한**이다(재실측 전까지 그 값을 기준선으로 읽으면 안전한 쪽으로 틀린다).
    private func hero(_ week: ConsumptionWeek.Summary, _ ledger: Ledger) -> some View {
        // 두 덩이(값 / 주) 사이는 s5, 캡션은 자기가 설명하는 칩 행에 s3으로 붙는다 —
        // 캡션이 두 덩이 한가운데에 뜨면 무엇을 설명하는 줄인지 위치가 말해 주지 않는다.
        VStack(spacing: ReffiSpace.s5) {
            headlineBlock(week)
            VStack(spacing: ReffiSpace.s3) {
                chipRow(week)
                    .accessibilityFocused($chipRowFocused)
                // 닫히면 이 행 자체가 트리에서 빠진다 — 위 VStack의 s3 간격도 함께 사라져
                // 칩 행 아래에 빈 여백이 남지 않는다(간격은 형제 쌍에 붙는 값이라 형제가 하나뿐이면
                // 저절로 없어진다).
                if showsChipHint { chipHintNotice }
            }
        }
        .frame(maxWidth: .infinity)
        // 밴드 안쪽 인셋을 페이지 마진으로 내린다(49차) — 헤드라인이 좌측으로 오면서 이 밴드의
        // 좌측선(24)이 패인 헤드라인·정산서 카드(16)와 8pt 어긋나는 게 눈에 보이게 됐다.
        // 칩 폭 검산(375pt 기준): 콘텐츠 343 = 칩 7×38(266) + 간격 6×s1(36) = 302 ≤ 343, 여유 41pt.
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.vertical, ReffiSpace.s5)
        .background {
            PaperGlyphPile(glyphs: ledger.pileGlyphs, base: ReffiColor.canvas)
                // 위·아래 끝은 자르는 선이 아니라 **사그라드는 결**이다. 바탕색을 배경과 맞춰도
                // 블러 4pt짜리 실루엣이 직선에서 뚝 끊기면 그 자리가 다시 층으로 읽힌다(문법은
                // `OrderMemoCard.middleScroll`의 오버플로 마스크와 같다). 마스크가 실제로 깎는
                // 것은 실루엣뿐이다 — 바탕은 뒤의 `PaperCanvasBackground`와 같은 토큰이라
                // 지워져도 같은 색이 그대로 남는다.
                .mask {
                    LinearGradient(stops: [.init(color: .black.opacity(0), location: 0),
                                           .init(color: .black, location: 0.10),
                                           .init(color: .black, location: 0.90),
                                           .init(color: .black.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .padding(.horizontal, -ReffiGrid.margin)
    }

    /// 칩 문법 설명 캡션 — 이제 **닫을 수 있는 조용한 힌트**다(2026-08, 31차). 문구는 그대로("A chip
    /// a day. Green is what you ate.") — 칩 문법(면색=먹었는가·배지=버림 개수)을 한 번 읽고 나면
    /// 다시 볼 필요가 없다는 것이 owner 판단이다. **알림(alert)이 아니라 힌트**라 시각은 조용하게
    /// 유지한다 — 캡션과 같은 톤(`ink2`)의 작은 X 하나, 카드 면·그림자 없음. `PaperCloseButton`은
    /// 시트·커버를 닫는 더 무거운 문법이라 여기 쓰지 않는다 — 검색 필드의 "Clear search" X와 같은 결.
    private var chipHintNotice: some View {
        HStack(spacing: ReffiSpace.s2) {
            Text("A chip a day. Green is what you ate.")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismissChipHint) {
                ReffiIcon.close.reffi(14)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(width: 30, height: 30)
                    // 시각은 30pt, 히트 영역은 44pt(§7.3) — 투명 여백으로 확보한다.
                    .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)   // §7.2 — 조용한 힌트라 종이 프레스가 아니라 스케일 프레스
            .edgeAligned(.trailing, visual: 14)   // 히트 44가 시각 14를 15pt 안으로 밀었다(42차) — 밴드 우측선 복원
            .accessibilityLabel(Text("Dismiss hint"))
        }
        .transition(.opacity)
    }

    /// 힌트 닫기 — 모션 축소 시 애니메이션 없이 **즉시** 사라지되(§7.4), 값은 똑같이 기록된다("재생을
    /// 시도했다"가 아니라 "닫았다"이므로 축소 여부와 무관하게 영구적이어야 한다). 닫힌 요소에 VoiceOver
    /// 포커스가 뜬 채로 남지 않게 칩 행으로 옮긴다.
    private func dismissChipHint() {
        withAnimation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion)) {
            chipHintDismissed = true
            chipHintDismissedNow = true
        }
        chipRowFocused = true
    }

    /// 값 덩이 — 큰 비율 + 작은 추세 화살표, 그 아래 창 이름 한 줄.
    ///
    /// **33차, 사용자 지침으로 단순화**: 옛 세 줄(숫자 헤드라인 · 분자·분모 캡션 · 추세 문장 pill)이
    /// 헤드라인을 과밀하게 만든다는 지적에 따라 화면은 **큰 비율 + 작은 화살표 + 캡션 한 줄**로 준다.
    /// 지워진 두 조각의 자리는 사라지지 않는다 — 분자·분모는 아래 요일 칩 행이(칩 각 칸이 이미
    /// 자기 날의 먹음·버림 개수를 든다, §13.10), 추세의 방향은 이 화살표가 잇는다. 분류 자체
    /// (`ConsumptionWeek.Trend` — better/worse/same)는 그대로 살아 있고, 화살표는 그 결과를
    /// 그림 하나로 옮길 뿐이다.
    /// **49차 — 좌측 정렬**(§9.4). 레퍼런스 감사에서 리포트 히어로 숫자를 가운데 놓은 화면이 46장 중
    /// 하나도 없었다: 요약 카드는 예외 없이 라벨·값·격자를 **한 좌측선**에 세운다. 우리도 이 화면의
    /// 축이 좌(패인 헤드라인) → 중(이 블록) → 좌(정산서)로 두 번 꺾여 있었다 — §9.4의 "한 표면에
    /// 축은 하나다"가 그대로 걸린다. 아래 요일 칩 행은 밴드 전폭에 균등 분배되는 **격자**라
    /// 이 블록과 중심을 맞출 대상이 아니었고(§9.4 예외 ③), 그래서 옮겨도 관계가 깨지지 않는다.
    private func headlineBlock(_ week: ConsumptionWeek.Summary) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s0) {
            if let rate = week.eatenRate {
                // `reffiNum(.hero)`(32)가 숫자 계열의 **맨 위 단**이다(§3.4). 34를 새로 만들지
                // 않는 이유: 그 절이 크기를 자유 파라미터로 두었다가 여덟 종이 유통된 사고를
                // 닫으며 세 단만 남긴 곳이라, 화면 하나를 위해 넷째 단을 여는 순간 그 규율이 풀린다.
                HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s1) {
                    Text(rate.formatted(.percent))
                        .font(.reffiNum(.hero))
                        .foregroundStyle(ReffiColor.ink)
                    if let arrow = Self.trendArrow(week.trend) {
                        // **20pt인 근거는 글리프 실측이다(34차).** 처음엔 `reffiNum(.meta)`와 같은
                        // 단인 12pt였는데(§3.4 세 단 규율을 화살표에도 적용한다는 유추), 화면에서
                        // 티끌로 읽혔다. 원인은 크기 선택이 아니라 **글리프 채움률**이다 — Phosphor
                        // 캐럿은 제 상자의 세로 **38%**만 채워서 12pt는 보이는 삼각형이 8.0 × 4.7pt고,
                        // 32pt 숫자 곁에서 그 정도면 방향이 안 읽힌다(3x 캡처 픽셀 실측: 12/14/16/18/20을
                        // 나란히 렌더해 잰 값이고 채움률은 다섯 곳 모두 37~39%로 일정하다).
                        // 20pt면 14.0 × 7.3pt다. §3.4는 **숫자 타입** 규율이라 아이콘엔 적용되지
                        // 않는다 — 이 앱의 아이콘은 10~44pt 자유 크기고 20pt는 이미 쓰던 크기다.
                        // `.fill` 무게라야 이 크기에서 얇은 선이 아니라 꽉 찬 세모로 읽힌다.
                        //
                        // **20은 이제 기준값이고 실제 크기는 `trendArrowSize`가 낸다(35차)** —
                        // 위 프로퍼티가 숫자와 같은 램프로 키운다.
                        //
                        // **밴드 위에 직접 얹고 종이 받침을 두지 않는다** — 옛 추세 문장(26차)은
                        // 텍스트라 §2.6의 본문 기준(4.5:1)을 못 넘어 종이 조각이 필요했지만
                        // (밴드 위 `freshDark` 실측 4.25:1), 이 화살표는 **그림**이라 §2.6의
                        // 비텍스트 기준(3:1)이 적용되고 같은 잉크의 4.25:1은 그 기준을 이미 넘는다.
                        arrow.icon.reffi(trendArrowSize, .fill)
                            .foregroundStyle(arrow.color)
                            // 아이콘엔 글자 베이스라인이 없어 기본 정렬 가이드가 어중간한 자리에
                            // 앉는다 — 밑변을 숫자의 베이스라인에 직접 맞춘다.
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                    }
                }
                // 캡션은 창 이름 하나만 남는다 — "N of M" 분자·분모(22차)가 이 자리에 있던 근거는
                // "비율만 있으면 판정마다 반드시 움직이는 값이 없다"는 것이었는데, 지금은 바로 아래
                // 요일 칩 행의 각 칸이 이미 그 값(그날의 먹음·버림 개수)을 들고 있어(§13.10) 한
                // 블록 안에 같은 숫자가 두 번 설 이유가 없다(33차, 사용자 피드백 — 헤드라인 과밀).
                // `muted`가 아니라 `ink2`다. 26차에 이 자리를 옮긴 근거는 당시 실측이 §2.6 미달
                // (4.03 라이트 / 4.17 다크)이었다는 것이고, 그 뒤 §2.3 잉크 램프 교정으로 `muted`가
                // 기준선을 넘긴 지금도 `ink2`를 그대로 쓴다 — 이 줄 뒤에는 **실루엣 더미가 깔려
                // 토큰 대 토큰 값이 실제 최악이 아니기 때문**이다(§13.10 실측 문단). 밴드 바탕이
                // `paperPass`에서 `canvas`로 바뀐 것도 이 판단을 흔들지 않는다 — 두 스킴 모두
                // 잉크와의 거리가 벌어지는 방향이라 여유는 늘기만 한다.
                Text("eaten this week").reffiType(.metaText).foregroundStyle(ReffiColor.ink2)
            } else {
                // 처리 0건 — 0%는 "다 버렸다"는 없는 판정이다. 숫자를 아예 세우지 않는다.
                // 자리를 비우지 않고 `subhead`(18) 한 줄로 채우는 이유: 값 덩이가 통째로
                // 사라지면 아래 칩 행이 밴드 한가운데로 올라와 히어로가 다른 화면처럼 보인다.
                // `heading`(24)을 쓰지 않는 것은 바로 위 패인 헤드라인이 그 단이라, 같은 크기가
                // 둘이면 무엇이 무엇을 이름 붙이는지가 사라지기 때문이다(§3.2 위계).
                Text("Nothing this week")
                    .reffiType(.subhead)
                    .foregroundStyle(ReffiColor.ink)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(ReffiShrink.fit)
        .multilineTextAlignment(.leading)
        // 안쪽 블록이 제 내용 폭만 잡으면 부모가 도로 가운데로 민다 — 좌측선을 실제로 세우는 건 이 프레임이다(§9.4).
        .frame(maxWidth: .infinity, alignment: .leading)
        // 값 덩이는 숫자 하나가 아니라 "무엇의 몇 퍼센트인가"다 — 화면에서 화살표 하나로 줄인 추세를
        // 소리에서는 그대로 문장으로 편다(분자·분모·추세 방향·지난 주 값까지, 아래 `headlineLabel`).
        // 화면 혼잡이 33차의 문제였지 VoiceOver 정보량이 문제가 아니었다 — 말은 공짜다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headlineLabel(week))
        // 화살표의 **UI 테스트 훅** — 화면 문구가 아니라 식별자로 방향을 잡는다(`ticket.menuName`
        // 선례). 화살표가 없는 주(`.same`·지난 주 데이터 없음)는 식별자도 빈 문자열이라, 특정
        // 방향 식별자의 부재 자체가 테스트가 확인하는 상태가 된다.
        .accessibilityIdentifier(Self.trendArrow(week.trend)?.testID ?? "")
    }

    private func headlineLabel(_ week: ConsumptionWeek.Summary) -> Text {
        guard let rate = week.eatenRate else {
            return Text("Nothing cleared out this week yet.")
        }
        // `^[...](inflect: true)` — 분모 1일 때 "1 of 1 items"로 읽히지 않게 자동 문법 일치(en 전용;
        // ko는 수 일치가 없어 번역값에 마크업이 없다).
        //
        // 추세는 **문장 전체를 케이스별로 완결한다**(조각을 이어 붙이지 않는다) — 번역이 어순을
        // 자유롭게 정할 수 있어야 한다(`dayLabel`과 같은 결). 지난 주 값을 그대로 싣는 이유는 옛
        // 추세 문장(26차)의 근거를 그대로 잇는다: "나아졌어요"만 있으면 무엇에 견줬는지가 안 들리고,
        // 숫자가 있으면 사용자가 스스로 검산할 수 있다.
        guard let trend = week.trend, let previous = week.previousEatenRate else {
            return Text("Eaten this week: \(rate) percent, \(week.eaten) of ^[\(week.removed) items](inflect: true)")
        }
        switch trend {
        case .better:
            return Text("Eaten this week: \(rate) percent, \(week.eaten) of ^[\(week.removed) items](inflect: true). Up from \(previous) percent last week.")
        case .worse:
            return Text("Eaten this week: \(rate) percent, \(week.eaten) of ^[\(week.removed) items](inflect: true). Down from \(previous) percent last week.")
        case .same:
            return Text("Eaten this week: \(rate) percent, \(week.eaten) of ^[\(week.removed) items](inflect: true). About the same as last week's \(previous) percent.")
        }
    }

    /// 칩 한 조각 — 폭은 일곱 칸이 **SE급(375pt)에서도 한 줄에 서는** 상한에서 왔다:
    /// 밴드 콘텐츠 폭 327 − 칸 사이 s1 × 6 = 291, 일곱으로 나누면 41.6pt다.
    private static let chipWidth: CGFloat = 38
    private static let chipHeight: CGFloat = 44

    private func chipRow(_ week: ConsumptionWeek.Summary) -> some View {
        HStack(spacing: ReffiSpace.s1) {
            ForEach(week.days) { dayCell($0) }
        }
        .accessibilityElement(children: .contain)
        // 칩 행은 접근성 글자에서도 **accessibility1까지만** 따라 키운다(`FridgeTabBar`와 같은 상한).
        // 칩 상자(38 × 44)는 그려지는 치수라 글자를 따라 커지지 않는데, 안의 숫자·배지만 AX5까지
        // 키우면 축소 방어(`minimumScaleFactor`)로도 못 받는다 — 실측에서 배지가 칩을 덮고 글자가
        // "…"로 잘렸다. 일곱 칸이 한 줄에 서는 배치라 칩을 키우는 길도 없고, 진짜 값은 접근성
        // 라벨(`dayLabel`)이 크기와 무관하게 온전히 읽어 준다.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// 한 칸 — 머리글자 + 칩. **오늘 표시는 머리글자가 진다**(칩이 아니라).
    ///
    /// 20차의 요일 블롭은 오늘 칸을 잉크 솔리드로 칠했다. 지금은 면색이 "먹었는가"라는 **데이터**를
    /// 지고 있어서, 오늘을 면색으로 표시하면 오늘 하루만 데이터가 지워진다. 남는 채널은 칩 위의
    /// 글자뿐이고, 거기에 얹으면 채널이 겹치지 않는다. 오늘을 어디서든 찾을 수 있다는 조건도
    /// 그대로다 — 앞으로 올 날이 점선이라 **오려 낸 마지막 칸**이 오늘이고, 주의 마지막 날이면
    /// 앞으로 올 날이 없으니 마지막 칸이 오늘이다.
    private func dayCell(_ day: ConsumptionWeek.Day) -> some View {
        VStack(spacing: ReffiSpace.s1) {
            Text(verbatim: ConsumptionWeek.initial(of: day))
                .reffiType(.metaText)
                // 지나간 날·앞으로 올 날은 `ink2`다(옛 `muted`는 밴드 위에서 4.03:1로 미달, 위 참고).
                .foregroundStyle(day.isToday ? ReffiColor.ink : ReffiColor.ink2)
                // 큰 글자에서 칩을 키우지 않고 **글자를 줄인다**(`FridgeTabBar` 알약과 같은 방어).
                // 일곱 칸이 한 줄에 서는 배치라 칸이 커지면 주가 화면 밖으로 밀려난다 — 잘리는 것보다
                // 작아지는 편이 낫고, 진짜 값은 접근성 라벨이 온전히 읽어 준다.
                .lineLimit(1)
                .minimumScaleFactor(ReffiShrink.dense)
            PaperDayChip(eaten: day.eaten, tossed: day.tossed, isFuture: day.isFuture,
                         // 시드는 요일 번호 — 일곱 조각이 서로 다른 윤곽을 갖되, 같은 요일은
                         // 다시 열어도 같은 모양이라 화면이 흔들리지 않는다.
                         seed: day.weekday,
                         width: Self.chipWidth, height: Self.chipHeight)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel(day))
    }

    /// 칩 한 칸의 소리 — 화면의 세 채널(면색·숫자·모서리 조각)을 한 문장으로 편다.
    /// 아무 일도 없던 날은 "0 eaten"이 아니라 **"nothing"**이다: 0은 "안 먹었다"는 판정처럼 들리는데
    /// 그날은 냉장고에서 나간 것 자체가 없다(화면에서 빈 종이 조각으로 두는 것과 같은 이유).
    private func dayLabel(_ day: ConsumptionWeek.Day) -> Text {
        let name = ConsumptionWeek.name(of: day)
        if day.isFuture { return Text("\(name), still to come") }
        // 오늘은 요일 이름 대신 "Today"로 읽는다 — 화면에서 머리글자로 구분해 둔 사실이 소리로도 와야 한다.
        if day.eaten > 0, day.tossed > 0 {
            return day.isToday
                ? Text("Today, \(day.eaten) eaten, \(day.tossed) tossed")
                : Text("\(name), \(day.eaten) eaten, \(day.tossed) tossed")
        }
        if day.eaten > 0 {
            return day.isToday ? Text("Today, \(day.eaten) eaten") : Text("\(name), \(day.eaten) eaten")
        }
        if day.tossed > 0 {
            return day.isToday ? Text("Today, \(day.tossed) tossed") : Text("\(name), \(day.tossed) tossed")
        }
        return day.isToday ? Text("Today, nothing") : Text("\(name), nothing")
    }


    // MARK: ② 정산서 — 영수증 한 장에 "먹음·버림 두 행 → 낭비율 도장 → 자주 버린 재료 TOP 3"
    //
    // 옛 도넛은 두 지표를 한 그래픽에 겹쳤다(링=버린 것의 카테고리 구성, 가운데 숫자=낭비율)가 서로
    // 다른 분모를 같은 원 안에 놓았고, 신선도 3색을 '식품군' 의미로 재사용해 §2.4를 정면으로 어겼다.
    // 세로로 읽히는 영수증 정산서는 지표를 한 축(건수)으로 세우고, 색은 낭비율 도장 하나만 쓴다.
    //
    // **이 카드가 쓰는 글자 층은 셋이고, 층을 고르는 기준은 크기가 아니라 "그 줄이 하는 일"이다(§3.5).**
    // ① **카드 이름** = `subhead`(18). "Tally · past 30 days"·"Timeline"은 그 줄 자체가 읽히는
    //    제목이지 아래를 여는 이름표가 아니다 — `groupLabel`로 내리면 같은 카드 안의 묶음 이름표
    //    ('Most tossed')와 크기·색이 똑같아져 카드가 제목을 **잃는다**(위계를 낮추는 게 아니라 지우는
    //    것이다). 설정 영수증처럼 카드 전체가 행 묶음뿐인 표면과 갈리는 지점이 정확히 여기다.
    // ② **묶음 이름표** = `groupLabel`(12 / `muted`). 아래 줄들을 여는 한 줄이라 자기가 읽히려 하지
    //    않는다 — 'Most tossed'가 이 층이다.
    // ③ **명세 줄** = `checklistItem`(16 / SemiBold). 정산 세 행의 라벨도, 자주 버린 재료의 품목
    //    이름도 같은 층이다. 둘 다 영수증의 명세이지 설정·폼 라벨(`body`)이 아니다. 그리고 **행
    //    안에서는 라벨이 값보다 무겁다** — 값은 `reffiNum`(Regular) 또는 `metaText`(13)다.
    //    유일한 예외가 낭비율 도장이고, 그 근거는 `rateRow`에 적었다.
    private func settlementCard(_ ledger: Ledger) -> some View {
        card(seed: 0) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                HStack(alignment: .center, spacing: ReffiSpace.s2) {
                    Text("Tally · past 30 days")
                        .reffiType(.subhead)
                        .foregroundStyle(ReffiColor.ink)
                        // 시각 위계에 의미 위계를 짝지운다 — 로터의 '제목' 탐색으로 카드에서 카드로
                        // 건너뛸 수 있어야 한다(`SheetHeader`·`CoverHeader`·패인 헤드라인 선례).
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: ReffiSpace.s2)
                    if ledger.streakDays > 0 {
                        DDayStamp(text: String(localized: "DAY \(ledger.streakDays)"), color: ReffiColor.freshDark, size: 10)
                    }
                }
                ReffiRule(.receipt)

                if ledger.recentEmpty {
                    // 빈 이력 — 0건 두 행과 0% 도장은 "잘하고 있다"는 거짓 성과가 된다. 정산할 게 없다고 말한다.
                    Text("Nothing tallied yet. What you eat and toss lands here.")
                        .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                        .padding(.vertical, ReffiSpace.s2)
                } else {
                    tallyRow("Ate", count: ledger.eaten)
                    tallyRow("Tossed", count: ledger.tossed)
                    // **"Ate"의 부분집합**이다(발주 소비도 먹은 것이므로 위 `Ate`가 이미 세고 있다).
                    // 그래서 세 행이 합해지는 것처럼 보이면 안 되는데, 이 카드에는 Ate + Tossed를
                    // 더하는 총계 행이 어디에도 없고(합은 아래 낭비율이 비율로만 쓴다) 영수증은
                    // 위에서 아래로 읽는 명세라 세 줄이 곧바로 산술로 읽히지 않는다. 그 위에서
                    // **파생 행을 맨 아래**에 두어 두 판정(Ate·Tossed)이 서로 붙어 있게 했다.
                    tallyRow("Cooked", count: ledger.cooked)
                    ReffiRule(.receipt)
                    rateRow(ledger)
                    if ledger.topTossed.isEmpty {
                        Text("No waste yet. Nicely done.")
                            .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                    } else {
                        ReffiRule(.receipt)
                        tossedSection(ledger)
                    }
                }

                // 영수증 명세 마감 — 점선 룰 + 상호. 기간은 헤더가 말한다.
                // (한때 우측에 장식용 일련번호가 있었으나 의미를 기대하게 만드는 무의미한
                //  숫자라 뺐다 — 2026-08-29 사용자 결정, 46차)
                ReffiRule(.receipt)
                Text(verbatim: "REFFI")
                    .reffiType(.monoEyebrow)
                    .foregroundStyle(ReffiColor.muted)
            }
        }
    }

    /// 정산 한 행 — 라벨 + 건수. 숫자는 `reffiNum`(§3.4 tabular)이라 두 행의 자릿수가 세로로 맞는다.
    ///
    /// **라벨을 `body`로 내리지 말 것.** `checklistItem`(SemiBold 16) ↔ `reffiNum(.body)`(Regular 15)라
    /// 굵기와 크기가 같은 방향을 가리켜 행 안의 라벨-값 관계가 한눈에 선다. `body`(Regular 16)로
    /// 내리면 두 쪽이 같은 굵기가 되어 그 관계가 사라진다 — §3.5가 `body`에 배정한 것은 **설정·폼의
    /// 라벨**이고, 이 줄은 폼 라벨이 아니라 영수증의 명세 줄이다(아래 'Most tossed' 품목 줄과 같은 급).
    private func tallyRow(_ label: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            Text(label).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
            Spacer(minLength: ReffiSpace.s2)
            Text(count.formatted()).font(.reffiNum(.body)).foregroundStyle(ReffiColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// 낭비율 행 — 값은 `DDayStamp`와 같은 도장 문법(각도 튼 종이 도장). 잉크는 낭비율 구간색(§2.4 예외).
    ///
    /// **"라벨이 값보다 무겁다"에서 의도적으로 벗어나는 유일한 행이다.** 값이 글자가 아니라 도장이고,
    /// §13.9가 "성과는 도장으로 말한다"며 이 카드의 가장 큰 무게를 여기로 몰아 준다. 균형을 맞추려고
    /// 라벨을 키우지 말 것 — 그러면 도장이 혼자 지던 일을 라벨이 나눠 갖고, 카드의 결론이 흐려진다.
    private func rateRow(_ ledger: Ledger) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            Text("Waste rate").reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
            Spacer(minLength: ReffiSpace.s2)
            DDayStamp(text: ledger.rate.formatted(.percent), color: Self.rateColor(ledger.rate), size: 15)
        }
        .padding(.vertical, ReffiSpace.s1)
        .accessibilityElement(children: .combine)
    }

    /// 자주 버린 재료 — 실루엣 + 이름 + 횟수. 3종 미만이면 있는 만큼만, 0이면 이 구역 자체가 없다.
    ///
    /// **'Most tossed'는 `groupLabel`(12 / `muted`)이다** — 카드 제목이 아니라 아래 세 줄을 여는
    /// 묶음 이름표라, 자기가 읽히는 게 아니라 아래를 읽히게 한다(§3.5). 옛 `caption`(14 / `ink2`)은
    /// 카드 제목(`subhead` 18)과 품목 줄(16) 사이에 끼어 **어느 쪽도 아닌 세 번째 급**을 만들었고,
    /// 같은 일을 하는 앱의 다른 이름표(설정 영수증 제목·담기 픽커 카테고리)와도 role이 갈렸다.
    /// `muted` on `receipt`는 §2.6 실측표에서 5.51(라이트) / 4.66(다크)이라 하한을 넘는다 — 이 색을
    /// 더 옅게 만지면 그 표의 최악값을 깨는 쪽이므로, 옅게 하고 싶으면 색이 아니라 크기를 볼 것.
    ///
    /// **품목 줄은 `checklistItem`(SemiBold 16)이다.** 라벨=값 행이라 라벨이 값(`metaText` 13/Medium)
    /// 보다 무거워야 하는데, 옛 `body`(Regular 16)는 그 관계를 뒤집어 **한 카드 안에서 정산 세 행
    /// (라벨 SemiBold)과 품목 줄(라벨 Regular)이 서로 반대 규칙을 따르고 있었다.** 재료 이름은
    /// 냉장고 카드에서도 `checklistItem`이라, 이제 같은 것이 앱 어디서나 같은 글자로 선다.
    private func tossedSection(_ ledger: Ledger) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Text("Most tossed")
                .reffiType(.groupLabel)
                .foregroundStyle(ReffiColor.muted)
                .accessibilityAddTraits(.isHeader)
            ForEach(ledger.topTossed, id: \.key) { row in
                HStack(spacing: ReffiSpace.s3) {
                    miniGlyph(row.glyph)
                    Text(verbatim: row.name).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
                    Spacer(minLength: ReffiSpace.s2)
                    Text("\(row.count) times")
                        .reffiType(.metaText).monospacedDigit()
                        .foregroundStyle(ReffiColor.ink2)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }



    // MARK: ③ 타임라인
    //
    // **최근 것부터 한 페이지씩**만 세운다. 이력 전량을 평범한 `VStack`에 펼치면 커버가 열리는
    // 첫 프레임에 행 전부가 뷰 트리로 실체화되고, 행마다 실루엣 Canvas가 한 장씩 붙어 그 비용이
    // 이력 수에 비례해 늘어난다 — 오래 쓴 사람일수록 History가 느려지는 구조다. 세운 행은
    // `LazyVStack`이 화면에 든 만큼만 그리고, 그 아래 것은 "더 보기"가 명시적으로 불러온다.
    private var timelineCard: some View {
        let shown = min(timelineShown, logs.count)
        let remaining = logs.count - shown
        return card(seed: 2) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Timeline")
                    .reffiType(.subhead)
                    .foregroundStyle(ReffiColor.ink)
                    .accessibilityAddTraits(.isHeader)   // 정산 카드 제목과 같은 층, 같은 트레잇
                LazyVStack(alignment: .leading, spacing: ReffiSpace.s3) {
                    ForEach(logs.prefix(shown)) { log in timelineRow(log) }
                }
                if remaining > 0 { moreButton(remaining) }
            }
        }
    }

    private func timelineRow(_ log: RemovalLog) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            miniGlyph(log.glyph)
            VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                // 한 행에 네 조각이 서므로 **역할이 넷 다 갈려야** 목록이 규칙 없이 섞여 보이지
                // 않는다(§3.5): 이름 = 콘텐츠(`checklistItem` 16) · 귀속 문장 = `caption`(14) ·
                // 판정과 날짜 = 훑는 값(`metaText` 13 · `reffiNum(.meta)` 12). 이름이 가장 무겁고
                // 오른쪽으로 갈수록 가벼워지는 한 방향이라, 훑는 눈이 먼저 재료를 잡는다.
                // 이름에 `body`(Regular 16)를 쓰면 안 된다 — 그건 설정·폼 라벨의 자리이고, 같은
                // 재료 이름이 냉장고 카드에서는 SemiBold, 여기서는 Regular로 갈린다.
                Text(verbatim: log.displayName).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
                // 발주로 소비된 재료는 "한 요리"로 귀속(조리 payoff의 기록면).
                if let via = log.via {
                    Text("Cooked · \(via)")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
            }
            Spacer()
            // 판정 키커는 `metaText`다(옛 `caption` 아님) — §3.5가 `caption`에 준 일은 **문장으로
            // 읽는 메타**이고, 이 한 단어는 읽는 게 아니라 훑는 값이다. 바로 왼쪽의 "Cooked · …"이
            // 실제 caption이라, 둘이 같은 role이면 문장과 값이 같은 글자로 서서 행의 구조가 사라진다.
            // 크기가 14 → 13으로 내려가도 대비 요건은 그대로 4.5:1이다(둘 다 §2.6의 '큰 글자'가 아니다).
            Text(log.wasted ? "Tossed" : "Ate")
                .reffiType(.metaText)
                .foregroundStyle(log.wasted ? ReffiColor.urgentDark : ReffiColor.freshDark)
            Text(verbatim: log.dateText)
                .font(.reffiNum(.meta, for: log.dateText))   // ko 날짜 표기 폴백(§3.4·42차)
                .foregroundStyle(ReffiColor.muted)
        }
    }

    /// 더 보기 — **다음에 몇 줄이 오는지**를 문구가 말한다. 남은 게 한 페이지보다 적으면 그 수 그대로라,
    /// 누르기 전에 이 아래가 끝인지 아닌지가 읽힌다. 영수증 명세를 잇는 자리라 점선 룰 아래 한 줄로 앉힌다.
    private func moreButton(_ remaining: Int) -> some View {
        let step = min(remaining, Self.timelinePage)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            ReffiRule(.receipt)
            Button { timelineShown += Self.timelinePage } label: {
                // 버튼 라벨은 `pillLabel`이다(§3.5) — 1차 CTA(`PaperButton`, `subhead`)만 예외고
                // 그 밖의 모든 버튼 글자가 이 한 role로 모인다. 옛 `checklistItem`(SemiBold 16)은
                // 바로 위 타임라인 **행의 재료 이름과 완전히 같은 글자**여서, 목록의 마지막 줄인지
                // 누를 수 있는 것인지가 색 하나로만 갈렸다.
                Text("Show \(step) more")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.blueDark)   // §2.6 종이 위 파랑 잉크는 blueDark
                    .frame(maxWidth: .infinity, minHeight: ReffiChrome.tapMin)   // §7.3 최소 터치 타깃
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
        }
    }

    /// 작은 일러스트 — 키운 실루엣(테두리 없음).
    ///
    /// 행마다 외곽 그림자 필터가 한 장씩 붙지만 **`shadowed: false`로 내리지 않는다**(A/B 실측):
    /// 이 카드의 면은 흰 영수증이라, 헤일로를 빼면 흰 계열 글리프(달걀·우유·요거트·밥)의 왼쪽·위
    /// 윤곽이 면에 묻혀 형태가 안쪽 음영으로만 읽힌다 — 그림자가 애초에 그 자리를 위해 있는 것이다.
    /// 비용 쪽은 위 페이지 상한 + `LazyVStack`이 이미 화면에 든 행 수로 묶어 두었다.
    private func miniGlyph(_ glyph: FoodGlyph) -> some View {
        PaperSilhouette(glyph: glyph, fresh: .fresh)
            .frame(width: ReffiFoodIcon.row, height: ReffiFoodIcon.row)
    }

    // MARK: 영수증 카드 래퍼 — Fridge 스택과 같은 흰 영수증(톱니)
    /// `seed`는 톱니의 **난수 스트림**을 카드마다 갈라 놓는다 — 두 장이 세로로 이어지는 화면이라
    /// 절취선이 자로 잰 듯 같은 그림이면 오려 낸 종이가 아니라 찍어 낸 패턴으로 읽힌다.
    ///
    /// **"위상을 어긋낸다"가 아니다.** `ReceiptShape`의 톱니는 칸마다 봉우리 위치·깊이가 흔들리는
    /// 불규칙 절취선이고 시드는 그 흔들림 전체를 정한다. 옛 구현은 4원소 위상 표라 `seed % 4`가
    /// 같으면 두 장이 픽셀 단위로 같은 그림이었다 — 그 시절 규칙을 기억하고 시드를 4씩 띄우는
    /// 사람이 없게 적어 둔다. 지금은 **서로 다른 값이기만 하면 다른 절취선**이다.
    private func card<Content: View>(seed: Int, @ViewBuilder _ content: () -> Content) -> some View {
        content().receiptSurface(seed: seed)
    }
}

