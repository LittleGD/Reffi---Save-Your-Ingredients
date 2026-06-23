import SwiftUI
import SwiftData
import PhosphorSwift

/// History — "Past 30 days" 마커에서 진입. 소비/버림 이력을 "영수증 명세"처럼 보여준다.
/// ① 월간 요약(소비·버림·낭비율 + 전월 추세) ② 카테고리별 낭비 ③ 자주 버리는 품목 ④ 통합 타임라인.
/// 각 섹션은 톱니 가장자리 + 인쇄 그레인 + 점선 리더의 영수증 슬립(§8).
struct HistoryView: View {
    @Query(sort: \RemovalLog.removedDate, order: .reverse)
    private var removals: [RemovalLog]
    @Environment(\.dismiss) private var dismiss

    private let toothH: CGFloat = 6

    // 섹션별 옅은 종이색 — 의미 구분은 유지하되 인쇄지처럼 차분하게.
    private static let pSummary    = Color(hex: "#EDF6FF") // 요약(블루)
    private static let pCategory   = Color(hex: "#FFEFE9") // 버림 카테고리(테라코타)
    private static let pTop        = Color(hex: "#FEF7E8") // 버린 품목(앰버)
    private static let pTimeline   = Color(hex: "#F2FAEA") // 타임라인(그린)

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
        return grouped.map { (category: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
    }

    /// 자주 버린 품목 Top, 많은 순.
    private var topWasted: [(name: String, count: Int)] {
        let grouped: [String: [RemovalLog]] =
            Dictionary(grouping: thisMonth.filter(\.wasted)) { $0.name }
        return Array(grouped.map { (name: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }.prefix(5))
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
                .padding(.horizontal, Space.s5)
                .padding(.vertical, Space.s4)
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

    // MARK: ① 월간 요약 — 영수증 "합계" 슬립
    private var summary: some View {
        receiptSlip(Self.pSummary) {
            HStack(alignment: .firstTextBaseline) {
                Text("PAST 30 DAYS")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(ReffiColor.ink2)
                Spacer()
                if !prevMonth.isEmpty { trendBadge }
            }
            dashed
            leaderRow("Eaten", "\(eaten)")
            leaderRow("Tossed", "\(tossed)")
            dashed
            // 합계 — 낭비율 강조
            HStack(alignment: .firstTextBaseline) {
                Text("WASTE RATE")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(ReffiColor.ink)
                Spacer()
                Text("\(rate)%")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundStyle(rateColor)
            }
            .padding(.top, Space.s1)
        }
    }

    private var trendBadge: some View {
        let up = delta > 0
        return HStack(spacing: 2) {
            ReffiIcon.up.reffi(11, .bold)
                .rotationEffect(.degrees(up ? 0 : 180))
            Text("\(abs(delta))% vs last")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(up ? ReffiColor.urgentDark : ReffiColor.freshDark)
    }

    // MARK: ② 카테고리별 낭비
    private var categorySection: some View {
        receiptSlip(Self.pCategory) {
            slipTitle("Most wasted categories")
            dashed
            ForEach(byCategory, id: \.category) { row in
                HStack(alignment: .bottom, spacing: Space.s2) {
                    CategoryIcon(category: row.category, size: 16)
                        .foregroundStyle(ReffiColor.ink)
                    Text(row.category.label.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ReffiColor.ink2)
                        .fixedSize()
                    leader
                    Text("\(row.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(ReffiColor.ink)
                        .fixedSize()
                }
                .padding(.vertical, Space.s2)
            }
        }
    }

    // MARK: ③ 자주 버리는 품목
    private var topSection: some View {
        receiptSlip(Self.pTop) {
            slipTitle("Most tossed items")
            dashed
            ForEach(topWasted, id: \.name) { row in
                leaderRow(row.name, row.count > 1 ? "x\(row.count)" : "once")
            }
        }
    }

    // MARK: ④ 통합 타임라인
    private var timeline: some View {
        receiptSlip(Self.pTimeline) {
            slipTitle("Timeline")
            dashed
            ForEach(thisMonth) { log in
                HStack(alignment: .bottom, spacing: Space.s2) {
                    (log.wasted ? ReffiIcon.trash : ReffiIcon.cook).reffi(15, .bold)
                        .foregroundStyle(log.wasted ? ReffiColor.urgentDark : ReffiColor.freshDark)
                    Text(log.name)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ReffiColor.ink)
                        .fixedSize()
                    leader
                    Text(log.removedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(ReffiColor.ink2)
                        .fixedSize()
                }
                .padding(.vertical, Space.s2)
            }
        }
    }

    // MARK: 영수증 슬립 래퍼 + 조각들
    private func receiptSlip<Content: View>(_ paper: Color, @ViewBuilder _ content: () -> Content) -> some View {
        let shape = ReceiptShape(toothHeight: toothH)
        return VStack(alignment: .leading, spacing: Space.s2) {
            content()
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s4 + toothH)
        .padding(.bottom, Space.s4 + toothH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paper, in: shape)
        .paperGrain(shape)
        .reffiStackShadow()
    }

    private func slipTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(ReffiColor.ink2)
    }

    /// 라벨 ···· 값 한 줄.
    private func leaderRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .bottom, spacing: Space.s2) {
            Text(label.uppercased())
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ReffiColor.ink2)
                .fixedSize()
            leader
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(ReffiColor.ink)
                .fixedSize()
        }
        .padding(.vertical, Space.s2)
    }

    /// 가변 점선 리더(라벨과 값 사이를 채움).
    private var leader: some View {
        ReceiptRule()
            .stroke(ReffiColor.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
    }

    /// 가로 대시 구분선.
    private var dashed: some View {
        ReceiptRule()
            .stroke(ReffiColor.ink.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }
}
