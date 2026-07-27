import SwiftUI

/// History — Wasted 요약에서 진입. 소비/버림 이력을 종이컷 카드로(§13).
/// ① 요약(먹음·버림·낭비율) ② 자주 버린 품목 ③ 타임라인.
struct HistoryView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var logs: [RemovalLog] { store.history }
    /// 요약(도넛·비율)은 라벨 그대로 **최근 30일** 기준. 타임라인은 전체.
    private var recent: [RemovalLog] { store.recentHistory }
    private var eaten: Int { recent.filter { !$0.wasted }.count }
    private var tossed: Int { recent.filter(\.wasted).count }
    private var rate: Int { store.wasteRate }

    private var rateColor: Color {
        switch rate {
        case ...10: ReffiColor.freshDark
        case ...30: ReffiColor.soonDark
        default:    ReffiColor.urgentDark
        }
    }

    /// 자주 버린 품목 — 버림 이력을 이름으로 묶어 많은 순.
    private var topTossed: [(name: String, glyph: FoodGlyph, count: Int)] {
        let grouped = Dictionary(grouping: logs.filter(\.wasted)) { $0.name }
        return grouped
            .compactMap { name, group in
                group.first.map { (name: name, glyph: $0.glyph, count: group.count) }
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: rateColor.opacity(0.6))
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: ReffiSpace.s4) {
                        summaryCard
                        if !topTossed.isEmpty { tossedCard }
                        timelineCard
                    }
                    .padding(.horizontal, ReffiGrid.margin)
                    .padding(.bottom, ReffiSpace.s6)
                }
            }
        }
    }

    /// 커버 헤더 — 단일 공급원 `CoverHeader`(§14.2 중앙 타이틀+서브 / 우측 종이 X).
    private var header: some View {
        CoverHeader(title: "History",
                    subtitle: "What you ate and what you tossed",
                    onClose: { dismiss() })
    }

    // MARK: ① 요약(No-waste report) — 도넛(낭비 구성) + 낭비율 + 스트릭 도장 + 영수증 명세 마감
    private var summaryCard: some View {
        card(seed: 0) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                HStack(alignment: .center, spacing: ReffiSpace.s2) {
                    Text("No-waste report").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    if streakDays > 0 {
                        DDayStamp(text: String(localized: "DAY \(streakDays)"), color: ReffiColor.freshDark, size: 10)
                    }
                    Spacer()
                    Text("\(eaten) ate · \(tossed) tossed")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }

                if wasteSegments.isEmpty {
                    Text("No waste yet. Nicely done.")
                        .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, ReffiSpace.s5)
                } else {
                    ZStack {
                        donut.frame(width: 180, height: 180)
                        VStack(spacing: 0) {
                            Text("\(rate)%").font(.reffiNum(32, relativeTo: .largeTitle)).foregroundStyle(rateColor)
                            Text("Wasted").reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    legend
                }

                // 영수증 명세 마감 — 점선 룰 + 기간 라벨 + 번호(장식, 이력에서 유도).
                HLine().stroke(ReffiColor.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
                HStack {
                    Text(verbatim: "REFFI · PAST 30 DAYS")
                        .reffiType(.monoEyebrow)
                        .foregroundStyle(ReffiColor.muted)
                    Spacer()
                    Text(receiptNo)
                        .font(.reffiNum(11, relativeTo: .caption2)).foregroundStyle(ReffiColor.muted)
                }
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

    /// 버린 품목을 카테고리(글리프 기반)로 묶은 도넛 세그먼트 — 최근 30일(라벨과 일치).
    private var wasteSegments: [(name: String, count: Int, color: Color)] {
        let tossed = recent.filter(\.wasted)
        let grouped = Dictionary(grouping: tossed) { $0.glyph.categoryLabel }
        return grouped
            .map { (name: $0.key, count: $0.value.count, color: Self.catColor($0.key)) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    private var donut: some View {
        let segs = wasteSegments
        let total = max(1, segs.reduce(0) { $0 + $1.count })
        return Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            let ir = r * 0.62
            let gap = 0.04
            var start = -Double.pi / 2
            for seg in segs {
                let sweep = Double(seg.count) / Double(total) * 2 * .pi
                let s = start + gap / 2, e = start + sweep - gap / 2
                var p = Path()
                p.addArc(center: c, radius: r, startAngle: .radians(s), endAngle: .radians(e), clockwise: false)
                p.addArc(center: c, radius: ir, startAngle: .radians(e), endAngle: .radians(s), clockwise: true)
                p.closeSubpath()
                ctx.fill(p, with: .color(seg.color))
                start += sweep
            }
        }
    }

    private var legend: some View {
        let segs = wasteSegments
        let total = max(1, segs.reduce(0) { $0 + $1.count })
        return VStack(spacing: ReffiSpace.s2) {
            ForEach(segs, id: \.name) { seg in
                HStack(spacing: ReffiSpace.s2) {
                    Circle().fill(seg.color).frame(width: 9, height: 9)
                    Text(LocalizedStringKey(seg.name)).reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Text("\(Int((Double(seg.count) / Double(total) * 100).rounded()))%")
                        .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
                }
            }
        }
    }

    /// 카테고리 색 — DS 토큰만. 흔한 3종(Veg·Fruit·Dairy)은 명도 일관 파스텔(fresh·urgent·soon).
    private static func catColor(_ c: String) -> Color {
        switch c {
        case "Veg":     ReffiColor.fresh
        case "Fruit":   ReffiColor.urgent
        case "Dairy":   ReffiColor.soon
        case "Meat":    ReffiColor.urgentDark
        case "Seafood": ReffiColor.blue
        case "Bakery":  ReffiColor.blueDark
        case "Protein": ReffiColor.freshDark
        default:        ReffiColor.muted
        }
    }

    // MARK: ② 자주 버린 품목
    private var tossedCard: some View {
        card(seed: 1) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Most tossed").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                ForEach(topTossed, id: \.name) { row in
                    HStack(spacing: ReffiSpace.s3) {
                        miniGlyph(row.glyph)
                        Text(verbatim: row.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                        Spacer()
                        (row.count > 1 ? Text(verbatim: "×\(row.count)") : Text("once"))
                            .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
        }
    }

    // MARK: ③ 타임라인
    private var timelineCard: some View {
        card(seed: 2) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Timeline").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                ForEach(logs) { log in
                    HStack(spacing: ReffiSpace.s3) {
                        miniGlyph(log.glyph)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: log.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
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
                            .font(.reffiNum(12, relativeTo: .caption2)).foregroundStyle(ReffiColor.muted)
                    }
                }
            }
        }
    }

    /// 작은 일러스트 — 키운 실루엣(테두리 없음).
    private func miniGlyph(_ glyph: FoodGlyph) -> some View {
        PaperSilhouette(glyph: glyph, fresh: .fresh)
            .frame(width: 36, height: 36)
    }

    // MARK: 영수증 카드 래퍼 — Fridge 스택과 같은 흰 영수증(톱니)
    private func card<Content: View>(seed: Int, @ViewBuilder _ content: () -> Content) -> some View {
        let shape = ReceiptShape(tooth: 7)
        return content()
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + 7)   // 톱니 인셋
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReffiColor.oklch(0.985, 0.004, 90), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}
