import SwiftUI

/// History 본문 — 소비/버림 이력을 종이컷 카드로(§13).
/// ① 이번 주 히어로(숫자 헤드라인 + 추세 문장 + 종이 칩 일곱) ② 정산서(먹음·버림·요리 세 행 +
/// 낭비율 도장 + 자주 버린 재료 TOP 3) ③ 타임라인.
///
/// **커버 크롬(헤더·닫기)을 갖지 않는 임베더블 본문**이다 — 냉장고 History 탭이 이 뷰를 그대로 얹고,
/// 풀스크린 커버가 필요한 자리는 아래 `HistoryView`가 헤더만 씌운다.
struct HistoryContent: View {
    /// 스크롤 꼬리 여백 — 커버는 기본값(`s6`), 떠 있는 캡슐 네비가 있는 탭 패인은 `navClearance`.
    var bottomPadding: CGFloat = ReffiSpace.s6

    @Environment(FridgeStore.self) private var store

    /// 정산서에 세우는 자주 버린 재료 줄 수 — 영수증 한 장이 삼키는 상한.
    private static let topTossedLimit = 3

    /// 타임라인 한 번에 세우는 행 수 — 첫 화면에도, "더 보기" 한 번에도 같은 값.
    /// 이력은 2000건까지 쌓이는데(`FridgeStore.historyCap`) 행마다 실루엣 Canvas가 한 장이라,
    /// 상한 없이 세우면 History를 여는 **첫 프레임의 비용이 쌓인 이력 수에 비례**한다.
    private static let timelinePage = 60

    /// 지금 타임라인에 세운 행 수 — "더 보기"가 한 페이지씩 늘린다.
    @State private var timelineShown = HistoryContent.timelinePage

    private var logs: [RemovalLog] { store.history }
    /// 정산서(수치·비율)는 라벨 그대로 **최근 30일** 기준. 타임라인은 전체.
    private var recent: [RemovalLog] { store.recentHistory }
    private var eaten: Int { recent.filter { !$0.wasted }.count }
    private var tossed: Int { recent.filter(\.wasted).count }
    /// 발주(레시피)로 소비된 건수 — 정의는 **스토어 한 곳**에 둔다(`Ate`·`Tossed`와 달리 조건이
    /// 둘이라, 뷰가 자기 필터를 들고 있으면 테스트가 보는 규칙과 화면이 보는 규칙이 갈릴 수 있다).
    private var cooked: Int { store.cookedCount }
    private var rate: Int { store.wasteRate }

    /// 낭비율 색 — 임계값의 **단일 공급원**이다(색=정보, §1). 커버 배경 accent와 냉장고 History 탭의
    /// 배경 accent가 같은 함수를 읽는다: 세 곳이 각자 `switch`를 들고 있으면 한쪽만 조용히 어긋난다.
    static func rateColor(_ rate: Int) -> Color {
        switch rate {
        case ...10: ReffiColor.freshDark
        case ...30: ReffiColor.soonDark
        default:    ReffiColor.urgentDark
        }
    }

    private var rateColor: Color { Self.rateColor(rate) }

    /// 자주 버린 재료 — 버림 이력을 **매칭 키**(표기 무관)로 묶어 많은 순, 정산 기간(30일)과 같은 모수.
    /// 표기로 묶으면 언어를 바꾸기 전후에 담은 같은 재료가 두 줄로 갈린다.
    /// 3종 미만이면 **있는 만큼만** 세운다(빈 줄을 채우지 않는다).
    private var topTossed: [(key: String, name: String, glyph: FoodGlyph, count: Int)] {
        let grouped = Dictionary(grouping: recent.filter(\.wasted)) { $0.matchKey }
        let rows: [(key: String, name: String, glyph: FoodGlyph, count: Int)] = grouped
            .compactMap { key, group in
                group.first.map { (key: key, name: $0.displayName, glyph: $0.glyph, count: group.count) }
            }
        let ranked = rows.sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        return Array(ranked.prefix(Self.topTossedLimit))
    }

    var body: some View {
        // 집계는 **본문당 한 번**만 돈다. computed로 두면 헤드라인·칩 행·추세 문장·접근성 라벨이
        // 각자 이력을 다시 훑고, 그 사이에 자정이 지나면 한 화면 안에서 두 값이 다른 주를 가리킬 수 있다.
        let week = ConsumptionWeek.summary(of: logs)
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
                    hero(week)
                }
                settlementCard
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

    // MARK: ① 이번 주 히어로 — 숫자 헤드라인 + 추세 한 문장 + 종이 칩 일곱
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
    private func hero(_ week: ConsumptionWeek.Summary) -> some View {
        // 두 덩이(값 / 주) 사이는 s5, 캡션은 자기가 설명하는 칩 행에 s3으로 붙는다 —
        // 캡션이 두 덩이 한가운데에 뜨면 무엇을 설명하는 줄인지 위치가 말해 주지 않는다.
        VStack(spacing: ReffiSpace.s5) {
            headlineBlock(week)
            VStack(spacing: ReffiSpace.s3) {
                chipRow(week)
                Text("A chip a day. Green is what you ate.")
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
        .padding(.vertical, ReffiSpace.s5)
        .background { PaperGlyphPile(glyphs: pileGlyphs) }
        .padding(.horizontal, -ReffiGrid.margin)
    }

    /// 값 덩이 — 큰 비율 + 창 이름·표본 한 줄, 그 아래 추세 한 문장.
    private func headlineBlock(_ week: ConsumptionWeek.Summary) -> some View {
        VStack(spacing: ReffiSpace.s2) {
            VStack(spacing: 2) {
                if let rate = week.eatenRate {
                    // `reffiNum(.hero)`(32)가 숫자 계열의 **맨 위 단**이다(§3.4). 34를 새로 만들지
                    // 않는 이유: 그 절이 크기를 자유 파라미터로 두었다가 여덟 종이 유통된 사고를
                    // 닫으며 세 단만 남긴 곳이라, 화면 하나를 위해 넷째 단을 여는 순간 그 규율이 풀린다.
                    Text(rate.formatted(.percent))
                        .font(.reffiNum(.hero))
                        .foregroundStyle(ReffiColor.ink)
                    // **창 이름과 분자·분모를 한 줄에 둔다**(22차 근거 유지). 비율만 세우면 히어로의
                    // 가장 큰 숫자가 사용자의 행동에 반응하지 않는 구간이 생긴다 — 이번 주에 버린 게
                    // 없으면 뭘 더 먹어도 100%에 고정된다(실측: 먹음 판정 후 요일 칸은 0→1, 정산서는
                    // 7→8로 움직였는데 링의 100%만 그대로였고, 그것이 "안 바뀐다"는 제보의 정체였다).
                    // 이 줄은 판정마다 반드시 움직이고, 동시에 **표본 크기**를 드러내 아래 30일
                    // 정산서의 낭비율과 나란히 놓였을 때의 모순감도 함께 푼다(2개 중 2개 vs 13개 중 5개).
                    HStack(spacing: ReffiSpace.s1) {
                        Text("eaten this week").reffiType(.metaText)
                        Text(verbatim: "·").reffiType(.metaText)
                        Text("\(week.eaten) of \(week.removed)").font(.reffiNum(.meta))
                    }
                    // `muted`가 아니라 `ink2`다 — `muted`는 히어로 밴드(`paperPass`) 위에서 4.03:1
                    // (라이트) / 4.17:1(다크)로 4.5:1을 못 넘고, 밴드에는 실루엣 더미까지 깔린다.
                    // `ink2`는 같은 면에서 7.02 / 7.66이다(§2.6).
                    .foregroundStyle(ReffiColor.ink2)
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
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            // 값 덩이는 숫자 하나가 아니라 "무엇의 몇 퍼센트인가"다 — 분자·분모까지 한 문장으로 읽는다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headlineLabel(week))

            if let trend = week.trend, let previous = week.previousEatenRate {
                trendSentence(trend, previous: previous)
            }
        }
    }

    private func headlineLabel(_ week: ConsumptionWeek.Summary) -> Text {
        guard let rate = week.eatenRate else {
            return Text("Nothing cleared out this week yet.")
        }
        // `^[...](inflect: true)` — 분모 1일 때 "1 of 1 items"로 읽히지 않게 자동 문법 일치(en 전용;
        // ko는 수 일치가 없어 번역값에 마크업이 없다).
        return Text("Eaten this week: \(rate) percent, \(week.eaten) of ^[\(week.removed) items](inflect: true)")
    }

    /// 추세 한 문장 — 이번 주 먹은 비율을 **지난 주** 같은 비율과 견준다.
    ///
    /// 문장이 지난 주 값을 그대로 싣는 이유: "나아졌어요"만 있으면 무엇에 견줬는지가 화면 밖에 있고,
    /// 숫자가 있으면 사용자가 다음 주에 스스로 검산할 수 있다. 색은 낭비율 축과 같은 방향이다
    /// (초록 = 덜 버렸다). **두 창 중 하나라도 비면 이 줄 자체가 서지 않는다** — 비교할 것이 없는데
    /// 문장을 세우면 없는 지난 주를 지어내는 셈이 된다(`Summary.trend`가 그때 `nil`이다).
    ///
    /// **문장이 종이 조각 위에 앉는 이유는 실측이다.** 밴드 위에 그냥 놓았더니 라이트 모드 최악
    /// 대비가 `freshDark` **4.25:1**이었다(캡처 픽셀 실측, 배경은 밴드 좌우 띠의 2백분위 = 밝은
    /// 실루엣 위). 같은 자리의 `ink2` 캡션은 5.78로 통과하므로 원인은 배경이 아니라 **잉크**다 —
    /// 색이 곧 정보인 문장이라 잉크를 어둡게 바꿀 수는 없다. 더미 농도를 조이는 길도 재 봤는데
    /// 4.5를 넘기려면 실루엣 이탈 폭을 0.162 → 0.12로(≈30%) 깎아야 해서, 문장 하나 때문에 배경
    /// 전체를 약하게 만드는 거래가 된다. 대신 **불투명한 바닥을 문장에만 준다**: `paper` 면 위에서
    /// 세 변형의 최악이 5.04:1이고(라이트/다크 전부), 그 면은 조용한 날 칩이 이미 쓰는 바로 그
    /// 종이라 밴드에 문법이 늘지 않는다. 셰이프도 기존 와이드 종이컷(`PaperCutRect`)을 쓴다.
    @ViewBuilder
    private func trendSentence(_ trend: ConsumptionWeek.Trend, previous: Int) -> some View {
        let last = previous.formatted(.percent)
        let shape = PaperCutRect(seed: 6)
        Group {
            switch trend {
            case .better:
                Text("Up from \(last) last week.").foregroundStyle(ReffiColor.freshDark)
            case .worse:
                Text("Down from \(last) last week.").foregroundStyle(ReffiColor.urgentDark)
            case .same:
                Text("About the same as last week.").foregroundStyle(ReffiColor.ink2)
            }
        }
        .reffiType(.caption)
        .multilineTextAlignment(.center)
        .padding(.horizontal, ReffiSpace.s3)
        .padding(.vertical, ReffiSpace.s1)
        .background(shape.fill(ReffiColor.paper))
        .paperEdge(shape)
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
                .minimumScaleFactor(0.6)
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

    /// 배경 더미에 세울 글리프 — **내 냉장고가 먼저, 그다음 내 이력**. 같은 글리프는 한 번만 쓴다
    /// (한 종류가 스무 칸을 다 채우면 더미가 아니라 무늬가 된다). 둘 다 비면 컴포넌트의 고정 세트가 선다.
    private var pileGlyphs: [FoodGlyph] {
        var seen = Set<FoodGlyph>()
        var result: [FoodGlyph] = []
        for glyph in store.ingredients.map(\.glyph) + logs.map(\.glyph) where seen.insert(glyph).inserted {
            result.append(glyph)
        }
        return result
    }

    // MARK: ② 정산서 — 영수증 한 장에 "먹음·버림 두 행 → 낭비율 도장 → 자주 버린 재료 TOP 3"
    //
    // 옛 도넛은 두 지표를 한 그래픽에 겹쳤다(링=버린 것의 카테고리 구성, 가운데 숫자=낭비율)가 서로
    // 다른 분모를 같은 원 안에 놓았고, 신선도 3색을 '식품군' 의미로 재사용해 §2.4를 정면으로 어겼다.
    // 세로로 읽히는 영수증 정산서는 지표를 한 축(건수)으로 세우고, 색은 낭비율 도장 하나만 쓴다.
    private var settlementCard: some View {
        card(seed: 0) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                HStack(alignment: .center, spacing: ReffiSpace.s2) {
                    Text("Tally · past 30 days").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Spacer(minLength: ReffiSpace.s2)
                    if streakDays > 0 {
                        DDayStamp(text: String(localized: "DAY \(streakDays)"), color: ReffiColor.freshDark, size: 10)
                    }
                }
                ReffiRule(.receipt)

                if recent.isEmpty {
                    // 빈 이력 — 0건 두 행과 0% 도장은 "잘하고 있다"는 거짓 성과가 된다. 정산할 게 없다고 말한다.
                    Text("Nothing tallied yet. What you eat and toss lands here.")
                        .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                        .padding(.vertical, ReffiSpace.s2)
                } else {
                    tallyRow("Ate", count: eaten)
                    tallyRow("Tossed", count: tossed)
                    // **"Ate"의 부분집합**이다(발주 소비도 먹은 것이므로 위 `Ate`가 이미 세고 있다).
                    // 그래서 세 행이 합해지는 것처럼 보이면 안 되는데, 이 카드에는 Ate + Tossed를
                    // 더하는 총계 행이 어디에도 없고(합은 아래 낭비율이 비율로만 쓴다) 영수증은
                    // 위에서 아래로 읽는 명세라 세 줄이 곧바로 산술로 읽히지 않는다. 그 위에서
                    // **파생 행을 맨 아래**에 두어 두 판정(Ate·Tossed)이 서로 붙어 있게 했다.
                    tallyRow("Cooked into recipes", count: cooked)
                    ReffiRule(.receipt)
                    rateRow
                    if topTossed.isEmpty {
                        Text("No waste yet. Nicely done.")
                            .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                    } else {
                        ReffiRule(.receipt)
                        tossedSection
                    }
                }

                // 영수증 명세 마감 — 점선 룰 + 상호 + 번호(장식, 이력에서 유도). 기간은 헤더가 말한다.
                ReffiRule(.receipt)
                HStack {
                    Text(verbatim: "REFFI")
                        .reffiType(.monoEyebrow)
                        .foregroundStyle(ReffiColor.muted)
                    Spacer()
                    Text(receiptNo)
                        .font(.reffiNum(.meta)).foregroundStyle(ReffiColor.muted)
                }
            }
        }
    }

    /// 정산 한 행 — 라벨 + 건수. 숫자는 `reffiNum`(§3.4 tabular)이라 두 행의 자릿수가 세로로 맞는다.
    private func tallyRow(_ label: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: ReffiSpace.s2) {
            Text(label).reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
            Spacer(minLength: ReffiSpace.s2)
            Text(count.formatted()).font(.reffiNum(.body)).foregroundStyle(ReffiColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// 낭비율 행 — 값은 `DDayStamp`와 같은 도장 문법(각도 튼 종이 도장). 잉크는 낭비율 구간색(§2.4 예외).
    private var rateRow: some View {
        HStack(spacing: ReffiSpace.s2) {
            Text("Waste rate").reffiType(.checklistItem).foregroundStyle(ReffiColor.ink)
            Spacer(minLength: ReffiSpace.s2)
            DDayStamp(text: rate.formatted(.percent), color: rateColor, size: 15)
        }
        .padding(.vertical, ReffiSpace.s1)
        .accessibilityElement(children: .combine)
    }

    /// 자주 버린 재료 — 실루엣 + 이름 + 횟수. 3종 미만이면 있는 만큼만, 0이면 이 구역 자체가 없다.
    private var tossedSection: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Text("Most tossed").reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            ForEach(topTossed, id: \.key) { row in
                HStack(spacing: ReffiSpace.s3) {
                    miniGlyph(row.glyph)
                    Text(verbatim: row.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer(minLength: ReffiSpace.s2)
                    Text("\(row.count) times")
                        .reffiType(.metaText).monospacedDigit()
                        .foregroundStyle(ReffiColor.ink2)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// 무낭비 스트릭 — 마지막 버림 이후 경과일(버린 적 없으면 기록 시작부터). (PR #4 리포트 통합)
    private var streakDays: Int {
        if let last = logs.filter(\.wasted).map(\.daysAgo).min() { return last }
        return logs.map(\.daysAgo).max() ?? 0
    }

    /// 영수증 번호 — 이력 수치에서 유도(장식, 안정적).
    private var receiptNo: String {
        String(format: "No. %04d", (eaten &* 31 &+ tossed &* 7 &+ rate) % 10000)
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
                Text("Timeline").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
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
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: log.displayName).reffiType(.body).foregroundStyle(ReffiColor.ink)
                // 발주로 소비된 재료는 "한 요리"로 귀속(조리 payoff의 기록면).
                if let via = log.via {
                    Text("Cooked · \(via)")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
            }
            Spacer()
            Text(log.wasted ? "Tossed" : "Ate")
                .reffiType(.caption)
                .foregroundStyle(log.wasted ? ReffiColor.urgentDark : ReffiColor.freshDark)
            Text(verbatim: log.dateText)
                .font(.reffiNum(.meta)).foregroundStyle(ReffiColor.muted)
        }
    }

    /// 더 보기 — **다음에 몇 줄이 오는지**를 문구가 말한다. 남은 게 한 페이지보다 적으면 그 수 그대로라,
    /// 누르기 전에 이 아래가 끝인지 아닌지가 읽힌다. 영수증 명세를 잇는 자리라 점선 룰 아래 한 줄로 앉힌다.
    private func moreButton(_ remaining: Int) -> some View {
        let step = min(remaining, Self.timelinePage)
        return VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            ReffiRule(.receipt)
            Button { timelineShown += Self.timelinePage } label: {
                Text("Show \(step) more")
                    .reffiType(.checklistItem)
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
    /// `seed`는 톱니 **위상**을 카드마다 어긋나게 한다 — 두 장이 세로로 이어지는 화면이라
    /// 절취선이 자로 잰 듯 같은 자리에서 시작하면 오려 낸 종이가 아니라 찍어 낸 패턴으로 읽힌다.
    /// (오래도록 인자만 받고 본문에서 쓰지 않아, 호출부 셋이 있지도 않은 변주를 믿고 있었다.)
    private func card<Content: View>(seed: Int, @ViewBuilder _ content: () -> Content) -> some View {
        content().receiptSurface(seed: seed)
    }
}

