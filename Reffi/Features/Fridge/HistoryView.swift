import SwiftUI

/// History 본문 — 소비/버림 이력을 종이컷 카드로(§13).
/// ① 이번 주 히어로(종이 고리 + 요일 블롭 일곱) ② 정산서(먹음·버림 두 행 + 낭비율 도장 +
/// 자주 버린 재료 TOP 3) ③ 타임라인.
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
        // 집계는 **본문당 한 번**만 돈다. computed로 두면 고리·요일 행·접근성 라벨이 각자 이력을
        // 다시 훑고, 그 사이에 자정이 지나면 한 화면 안에서 두 값이 다른 주를 가리킬 수 있다.
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

    // MARK: ① 이번 주 히어로 — 고리 하나 + 요일 블롭 일곱
    //
    // **창은 이번 주다**(정산서의 30일이 아니라). 바로 아래 요일 행이 이번 주 7일이므로, 고리만
    // 30일이면 한 블록 안에서 서로 다른 두 책을 읽게 된다 — 옛 도넛이 링과 가운데 숫자에 다른 분모를
    // 놓아 실패한 지점이 정확히 그것이다(§13.9). 요일 칸 일곱의 합이 곧 고리의 분자라, 화면에서
    // 눈으로 검산된다. 30일 수치는 아래 정산서가 자기 라벨과 함께 계속 말한다.
    //
    // 전면 블리드(`-ReffiGrid.margin`)는 카테고리 칩 행이 쓰던 관용구 그대로다 — 히어로는 카드가
    // 아니라 패인이 앉은 **바닥 면**이라 좌우 마진에 갇히면 카드 한 장으로 오해된다.
    private func hero(_ week: ConsumptionWeek.Summary) -> some View {
        VStack(spacing: ReffiSpace.s4) {
            ring(week)
            weekRow(week)
            Text("One circle a day. The number is what you ate.")
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ReffiGrid.margin + ReffiSpace.s2)
        .padding(.vertical, ReffiSpace.s5)
        .background { PaperGlyphPile(glyphs: pileGlyphs) }
        .padding(.horizontal, -ReffiGrid.margin)
    }

    /// 고리 지름·두께 — 안지름(지름 − 2×두께 = 120)이 가운데 두 줄을 받는 폭이다.
    private static let ringSize: CGFloat = 156
    private static let ringThickness: CGFloat = 18

    private func ring(_ week: ConsumptionWeek.Summary) -> some View {
        PaperRing(fraction: Double(week.eatenRate ?? 0) / 100,
                  // 값은 "먹은 비율"인데 **색은 낭비율의 색**이다 — 앱 전체에서 초록은 "덜 버렸다"이고,
                  // 그 임계값의 단일 공급원이 아래 `rateColor`다. 여기서 뒤집지 않으면 잘한 주가 빨개진다.
                  tint: Self.rateColor(week.wasteRate ?? 0),
                  thickness: Self.ringThickness,
                  seed: 4) {
            VStack(spacing: 2) {
                if let rate = week.eatenRate {
                    Text(rate.formatted(.percent))
                        .font(.reffiNum(.hero))
                        .foregroundStyle(ReffiColor.ink)
                    Text("eaten this week")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                    // **분자·분모를 눈에 보이게 둔다**(22차). 비율만 세우면 히어로의 가장 큰 숫자가
                    // 사용자의 행동에 반응하지 않는 구간이 생긴다 — 이번 주에 버린 게 없으면 뭘 더
                    // 먹어도 100%에 고정된다(실측: 재고에서 먹음 판정 후 요일 칸은 0→1, 정산서는
                    // 7→8로 움직였는데 링의 100%만 그대로였고, 그것이 "안 바뀐다"는 제보의 정체였다).
                    // 이 줄은 판정마다 반드시 움직이고, 동시에 **표본 크기**를 드러내 아래 30일
                    // 정산서의 낭비율과 나란히 놓였을 때의 모순감도 함께 푼다(2개 중 2개 vs 13개 중 5개).
                    Text("\(week.eaten) of \(week.removed)")
                        .font(.reffiNum(.meta))
                        .foregroundStyle(ReffiColor.muted)
                } else {
                    // 처리 0건 — 0%는 "다 버렸다"는 없는 판정이다. 숫자를 아예 세우지 않는다.
                    Text("Nothing this week")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            // 안지름 120에서 s3(12)씩 물리면 캡션이 96pt에 갇혀 **기본 크기에서도** 축소된다 —
            // 캡션("eaten this week")의 자연 폭이 그보다 넓다. 여백은 고리 안쪽 곡률이 이미 주고
            // 있으므로 최소(s1)만 남긴다.
            .padding(.horizontal, ReffiSpace.s1)
            .frame(width: Self.ringSize - Self.ringThickness * 2)
        }
        .frame(width: Self.ringSize, height: Self.ringSize)
        // 고리는 숫자 하나가 아니라 "무엇의 몇 퍼센트인가"다 — 분자·분모까지 읽어 준다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringLabel(week))
    }

    private func ringLabel(_ week: ConsumptionWeek.Summary) -> Text {
        guard let rate = week.eatenRate else {
            return Text("Nothing cleared out this week yet.")
        }
        // `^[...](inflect: true)` — 분모 1일 때 "1 of 1 items"로 읽히지 않게 자동 문법 일치(en 전용;
        // ko는 수 일치가 없어 번역값에 마크업이 없다).
        return Text("Eaten this week: \(rate) percent, \(week.eaten) of ^[\(week.removed) items](inflect: true)")
    }

    /// 요일 블롭 한 변.
    private static let dayBlob: CGFloat = 38

    private func weekRow(_ week: ConsumptionWeek.Summary) -> some View {
        HStack(spacing: ReffiSpace.s1) {
            ForEach(week.days) { dayCell($0) }
        }
        .accessibilityElement(children: .contain)
    }

    private func dayCell(_ day: ConsumptionWeek.Day) -> some View {
        VStack(spacing: ReffiSpace.s1) {
            Text(verbatim: ConsumptionWeek.initial(of: day))
                .reffiType(.metaText)
                .foregroundStyle(day.isToday ? ReffiColor.ink : ReffiColor.muted)
            ZStack {
                dayBlobSurface(day)
                // 0은 찍지 않는다 — 일곱 칸에 0이 늘어서면 숫자가 아니라 노이즈가 된다.
                // 조용한 날은 빈 종이 조각으로 남고, 먹은 날만 숫자를 든다.
                if !day.isFuture, day.eaten > 0 {
                    Text(day.eaten.formatted())
                        .font(.reffiNum(.body))
                        .foregroundStyle(day.isToday ? ReffiColor.canvas : ReffiColor.ink)
                }
            }
            .frame(width: Self.dayBlob, height: Self.dayBlob)
        }
        // 큰 글자에서 블롭을 키우지 않고 **글자를 줄인다**(`FridgeTabBar` 알약과 같은 방어).
        // 일곱 칸이 한 줄에 서는 배치라 칸이 커지면 주가 화면 밖으로 밀려난다 — 잘리는 것보다
        // 작아지는 편이 낫고, 진짜 값은 접근성 라벨이 온전히 읽어 준다.
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel(day))
    }

    /// 오늘 칸만 **잉크 솔리드**다(§13.5 탭 알약과 같은 문법).
    ///
    /// 바로 그 §13.5는 카테고리 필터 칩에 "선택 표시가 콘텐츠보다 무거워지면 안 된다"고 못 박았는데,
    /// 그 규칙의 근거는 *조작 상태*가 조작 대상보다 무거워지는 것을 막는 것이었다. 오늘 칸은 조작
    /// 상태가 아니다 — 이 행에서 **어디가 지금인지**를 정하는 유일한 기준점이고(그것 없이는 어느 쪽이
    /// 지나간 날이고 어느 쪽이 아직 오지 않은 날인지 읽히지 않는다), 탭 알약이 패인 행에서 하는 일과
    /// 같은 일이다. 게다가 이 행은 눌리지 않으므로, 무거운 표시가 컨트롤로 오독될 여지도 없다.
    @ViewBuilder
    private func dayBlobSurface(_ day: ConsumptionWeek.Day) -> some View {
        let shape = PaperBlob(sides: 9, seed: 40 + day.weekday)
        if day.isToday {
            shape.fill(ReffiColor.ink)
                .overlay(PaperGrain(seed: UInt64(40 + day.weekday), strength: 0.9).clipShape(shape))
                .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                .compositingGroup()
        } else if day.isFuture {
            // 아직 오지 않은 날 — 자리는 지키되 종이를 덜 오려 둔다(빈 칸이면 주가 짧아 보인다).
            shape.fill(ReffiColor.sub.opacity(0.55))
        } else {
            shape.fill(ReffiColor.paper).paperEdge(shape)
        }
    }

    private func dayLabel(_ day: ConsumptionWeek.Day) -> Text {
        let name = ConsumptionWeek.name(of: day)
        if day.isFuture { return Text("\(name), still to come") }
        // 오늘은 요일 이름 대신 "Today"로 읽는다 — 화면에서 잉크로 구분해 둔 그 사실이 소리로도 와야 한다.
        if day.isToday { return Text("Today, \(day.eaten) eaten") }
        return Text("\(name), \(day.eaten) eaten")
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

