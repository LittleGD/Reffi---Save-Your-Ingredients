import SwiftUI

/// History 본문 — 소비/버림 이력을 종이컷 카드로(§13).
/// ① 정산서(먹음·버림 두 행 + 낭비율 도장 + 자주 버린 재료 TOP 3) ② 타임라인.
///
/// **커버 크롬(헤더·닫기)을 갖지 않는 임베더블 본문**이다 — 냉장고 History 탭이 이 뷰를 그대로 얹고,
/// 풀스크린 커버가 필요한 자리는 아래 `HistoryView`가 헤더만 씌운다.
struct HistoryContent: View {
    /// 스크롤 꼬리 여백 — 커버는 기본값(`s6`), 떠 있는 캡슐 네비가 있는 탭 패인은 `navClearance`.
    var bottomPadding: CGFloat = ReffiSpace.s6

    @Environment(FridgeStore.self) private var store

    /// 정산서에 세우는 자주 버린 재료 줄 수 — 영수증 한 장이 삼키는 상한.
    private static let topTossedLimit = 3

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
        ScrollView {
            VStack(spacing: ReffiSpace.s4) {
                settlementCard
                if !logs.isEmpty { timelineCard }   // 기록이 없으면 제목만 남은 빈 카드를 세우지 않는다
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.bottom, bottomPadding)
        }
    }

    // MARK: ① 정산서 — 영수증 한 장에 "먹음·버림 두 행 → 낭비율 도장 → 자주 버린 재료 TOP 3"
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

    // MARK: ② 타임라인
    private var timelineCard: some View {
        card(seed: 2) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Timeline").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                ForEach(logs) { log in
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
            }
        }
    }

    /// 작은 일러스트 — 키운 실루엣(테두리 없음).
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

/// History의 **풀스크린 커버 형태** — 배경 + `CoverHeader`(§14.2 중앙 타이틀+서브 / 우측 종이 X)만
/// 씌운 얇은 래퍼이고 본문은 `HistoryContent`가 전부 그린다. 냉장고에서는 탭이 이 화면을 대신하지만,
/// 커버로 띄워야 하는 진입 경로가 생겼을 때 헤더·닫기 크롬을 다시 조립하지 않게 남겨 둔다.
struct HistoryView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: HistoryContent.rateColor(store.wasteRate).opacity(0.6))
            VStack(spacing: 0) {
                CoverHeader(title: "History",
                            subtitle: "What you ate and what you tossed",
                            onClose: { dismiss() })
                HistoryContent()
            }
        }
    }
}
