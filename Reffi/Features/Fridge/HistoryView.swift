import SwiftUI

/// History — Wasted 요약에서 진입. 소비/버림 이력을 종이컷 카드로(§13).
/// ① 요약(먹음·버림·낭비율) ② 자주 버린 품목 ③ 타임라인.
struct HistoryView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var logs: [RemovalLog] { store.history }
    private var eaten: Int { logs.filter { !$0.wasted }.count }
    private var tossed: Int { logs.filter(\.wasted).count }
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
        return grouped.map { (name: $0.key, glyph: $0.value.first!.glyph, count: $0.value.count) }
            .sorted { $0.count > $1.count }
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

    /// 커스텀 헤더 — 가운데 타이틀 + 오른쪽 X(툴바 미사용 → 자동 원형 배경 없음).
    private var header: some View {
        ZStack {
            Text("History").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    ReffiIcon.close.reffi(14, .bold)
                        .foregroundStyle(ReffiColor.ink)
                        .frame(width: 34, height: 34)
                        .background {
                            let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 4)
                            s.fill(ReffiColor.oklch(0.99, 0.006, 90)).paperEdge(s)
                        }
                        .reffiShadow1()
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s4)
        .padding(.bottom, ReffiSpace.s3)
    }

    // MARK: ① 요약 — 도넛 차트(버린 품목 카테고리 구성) + 가운데 낭비율 + 범례
    private var summaryCard: some View {
        card(seed: 0) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Past 30 days").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Text("\(eaten) ate · \(tossed) tossed")
                        .font(.reffiNum(12, relativeTo: .caption2)).foregroundStyle(ReffiColor.ink2)
                }

                if wasteSegments.isEmpty {
                    Text("No waste yet — nicely done.")
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
            }
        }
    }

    /// 버린 품목을 카테고리(글리프 기반)로 묶은 도넛 세그먼트.
    private var wasteSegments: [(name: String, count: Int, color: Color)] {
        let tossed = logs.filter(\.wasted)
        let grouped = Dictionary(grouping: tossed) { Self.category($0.glyph) }
        return grouped
            .map { (name: $0.key, count: $0.value.count, color: Self.catColor($0.key)) }
            .sorted { $0.count > $1.count }
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
                    Text(seg.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                    Spacer()
                    Text("\(Int((Double(seg.count) / Double(total) * 100).rounded()))%")
                        .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
                }
            }
        }
    }

    /// 글리프 → 거친 카테고리.
    private static func category(_ g: FoodGlyph) -> String {
        switch g {
        case .leaf, .broccoli, .onion, .garlic, .potato, .root, .squash, .mushroom, .pepper, .tomato: "Veg"
        case .apple, .citrus, .berry: "Fruit"
        case .egg, .milk, .cheese: "Dairy"
        case .meat, .poultry: "Meat"
        case .fish, .shrimp: "Seafood"
        case .tofu: "Protein"
        case .bread: "Bakery"
        case .generic: "Other"
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
                        Text(row.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                        Spacer()
                        Text(row.count > 1 ? "×\(row.count)" : "once")
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
                        Text(log.name).reffiType(.body).foregroundStyle(ReffiColor.ink)
                        Spacer()
                        Text(log.wasted ? "Tossed" : "Ate")
                            .reffiType(.caption)
                            .foregroundStyle(log.wasted ? ReffiColor.urgentDark : ReffiColor.freshDark)
                        Text(log.dateText)
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
