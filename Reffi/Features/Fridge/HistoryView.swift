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
        NavigationStack {
            ScrollView {
                VStack(spacing: ReffiSpace.s4) {
                    summaryCard
                    if !topTossed.isEmpty { tossedCard }
                    timelineCard
                }
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.vertical, ReffiSpace.s4)
            }
            .background(LiquidGlassBackground(accent: rateColor.opacity(0.6)))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
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
        }
    }

    // MARK: ① 요약
    private var summaryCard: some View {
        card(seed: 0) {
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                Text("Past 30 days").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                HStack(spacing: ReffiSpace.s3) {
                    stat("Eaten", "\(eaten)", ReffiColor.freshDark)
                    stat("Tossed", "\(tossed)", ReffiColor.urgentDark)
                    stat("Waste rate", "\(rate)%", rateColor)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.reffiNum(24, relativeTo: .title)).foregroundStyle(color)
            Text(label).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ② 자주 버린 품목
    private var tossedCard: some View {
        card(seed: 1) {
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text("Most tossed").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                ForEach(topTossed, id: \.name) { row in
                    HStack(spacing: ReffiSpace.s3) {
                        PaperSilhouette(glyph: row.glyph, fresh: .urgent).frame(width: 30, height: 30)
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
                        PaperSilhouette(glyph: log.glyph, fresh: .fresh).frame(width: 28, height: 28)
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
