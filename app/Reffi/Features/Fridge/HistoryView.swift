import SwiftUI
import SwiftData
import PhosphorSwift

/// History — "Past 30 days" 마커에서 진입. 소비/버림 이력 분석.
/// ① 월간 요약(소비·버림·낭비율 + 전월 추세) ② 카테고리별 낭비 ③ 자주 버리는 품목 ④ 통합 타임라인.
struct HistoryView: View {
    @Query(sort: \RemovalLog.removedDate, order: .reverse)
    private var removals: [RemovalLog]
    @Environment(\.dismiss) private var dismiss

    /// 카드 배경 그라데이션 — 팔레트 파스텔(위 진함 → 아래 옅음), 섹션마다 다른 색.
    private static func cardGradient(_ top: String, _ bottom: String) -> LinearGradient {
        LinearGradient(colors: [Color(hex: top), Color(hex: bottom)],
                       startPoint: .top, endPoint: .bottom)
    }
    private static let gBlue        = cardGradient("#D2EBFF", "#EDF6FF") // 요약
    private static let gTerracotta  = cardGradient("#FFDDD3", "#FFEFE9") // 버림 카테고리
    private static let gAmber       = cardGradient("#FDEDCD", "#FEF7E8") // 버린 품목
    private static let gGreen       = cardGradient("#E5F5D9", "#F2FAEA") // 타임라인

    // MARK: 기간 분할
    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: .now) ?? .distantPast
    }
    private var thisMonth: [RemovalLog] { removals.filter { $0.removedDate >= daysAgo(30) } }
    private var prevMonth: [RemovalLog] {
        removals.filter { $0.removedDate >= daysAgo(60) && $0.removedDate < daysAgo(30) }
    }

    private func wasteRate(_ logs: [RemovalLog]) -> Int {
        guard !logs.isEmpty else { return 0 }
        return Int((Double(logs.filter(\.wasted).count) / Double(logs.count) * 100).rounded())
    }

    private var eaten: Int { thisMonth.filter { !$0.wasted }.count }
    private var tossed: Int { thisMonth.filter(\.wasted).count }
    private var rate: Int { wasteRate(thisMonth) }
    private var delta: Int { rate - wasteRate(prevMonth) }

    /// 카테고리별 버림 횟수, 많은 순.
    private var byCategory: [(category: IngredientCategory, count: Int)] {
        let grouped: [IngredientCategory: [RemovalLog]] =
            Dictionary(grouping: thisMonth.filter(\.wasted)) { IngredientCategory(raw: $0.category) }
        var rows: [(category: IngredientCategory, count: Int)] = []
        for (cat, logs) in grouped { rows.append((cat, logs.count)) }
        return rows.sorted { $0.count > $1.count }
    }

    /// 자주 버린 품목 Top, 많은 순.
    private var topWasted: [(name: String, count: Int)] {
        let grouped: [String: [RemovalLog]] =
            Dictionary(grouping: thisMonth.filter(\.wasted)) { $0.name }
        var rows: [(name: String, count: Int)] = []
        for (name, logs) in grouped { rows.append((name, logs.count)) }
        return Array(rows.sorted { $0.count > $1.count }.prefix(5))
    }

    private var rateColor: Color {
        switch rate { case ...10: return ReffiColor.freshDark
                      case ...30: return ReffiColor.soonDark
                      default:    return ReffiColor.urgentDark }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s5) {
                    summary
                    if !byCategory.isEmpty { categorySection }
                    if !topWasted.isEmpty { topSection }
                    timeline
                }
                .padding(Space.s4)
            }
            .background(ReffiColor.canvas)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: ① 월간 요약
    private var summary: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack {
                Text("Past 30 days")
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.ink)
                Spacer()
                if !prevMonth.isEmpty {
                    trendBadge
                }
            }
            HStack(spacing: Space.s3) {
                stat("Eaten", "\(eaten)", ReffiColor.freshDark)
                stat("Tossed", "\(tossed)", ReffiColor.urgentDark)
                stat("Waste rate", "\(rate)%", rateColor)
            }
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.gBlue, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private var trendBadge: some View {
        let up = delta > 0
        return HStack(spacing: Space.s1) {
            (up ? ReffiIcon.up : ReffiIcon.up).reffi(12, .bold)
                .rotationEffect(.degrees(up ? 0 : 180))
            Text("\(abs(delta))% vs last month")
                .reffiText(ReffiType.caption)
        }
        .foregroundStyle(up ? ReffiColor.urgentDark : ReffiColor.freshDark)
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .reffiText(ReffiType.heading)
                .num()
                .foregroundStyle(color)
            Text(label)
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ② 카테고리별 낭비
    private var categorySection: some View {
        section("Most wasted categories", Self.gTerracotta) {
            let maxCount = byCategory.first?.count ?? 1
            VStack(spacing: Space.s3) {
                ForEach(byCategory, id: \.category) { row in
                    HStack(spacing: Space.s3) {
                        CategoryIcon(category: row.category, size: 18)
                            .foregroundStyle(ReffiColor.ink)
                        Text(row.category.label)
                            .reffiText(ReffiType.body)
                            .foregroundStyle(ReffiColor.ink)
                            .frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            Capsule()
                                .fill(ReffiColor.urgent)
                                .frame(width: geo.size.width * CGFloat(row.count) / CGFloat(maxCount), height: 8)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 18)
                        Text("\(row.count)")
                            .reffiText(ReffiType.caption)
                            .num()
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
        }
    }

    // MARK: ③ 자주 버리는 품목
    private var topSection: some View {
        section("Most tossed items", Self.gAmber) {
            VStack(spacing: Space.s2) {
                ForEach(topWasted, id: \.name) { row in
                    HStack {
                        Text(row.name)
                            .reffiText(ReffiType.body)
                            .foregroundStyle(ReffiColor.ink)
                        Spacer()
                        Text(row.count > 1 ? "×\(row.count)" : "once")
                            .reffiText(ReffiType.caption)
                            .num()
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
        }
    }

    // MARK: ④ 통합 타임라인
    private var timeline: some View {
        section("Timeline", Self.gGreen) {
            VStack(spacing: Space.s2) {
                ForEach(thisMonth) { log in
                    HStack(spacing: Space.s3) {
                        (log.wasted ? ReffiIcon.trash : ReffiIcon.cook).reffi(16, .bold)
                            .foregroundStyle(log.wasted ? ReffiColor.urgentDark : ReffiColor.freshDark)
                        Text(log.name)
                            .reffiText(ReffiType.body)
                            .foregroundStyle(ReffiColor.ink)
                        Spacer(minLength: Space.s4)
                        Text(log.removedDate.formatted(date: .abbreviated, time: .omitted))
                            .reffiText(ReffiType.caption)
                            .num()
                            .foregroundStyle(ReffiColor.ink2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: 섹션 래퍼
    private func section<Content: View>(_ title: String, _ gradient: LinearGradient, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title)
                .reffiText(ReffiType.subhead)
                .foregroundStyle(ReffiColor.ink)
            content()
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(gradient, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }
}
