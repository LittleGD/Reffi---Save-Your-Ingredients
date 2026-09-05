import SwiftUI

/// 칩 흐름 배치(61차) — 칩이 **제 폭**으로 서고 줄이 차면 다음 줄로 흐른다.
///
/// 옛 `LazyVGrid(.adaptive(minimum: 92))`는 칸 폭이 고정이라 "Mediterranean"처럼 칸보다 긴 라벨이 말줄임됐고
/// (요리 스타일 시트 — 시트 인셋이 24로 넓어지며 칸이 더 좁아졌다), "Thai" 같은 짧은 라벨 옆은 빈 칸으로 남았다.
/// 칩은 컨트롤이라 폭이 라벨을 따라야 한다(§9.4 ① — 면 안에 갇힌 글자). 태그 편집 시트의 태그 칩도 같은 배치다.
///
/// 줄 안 정렬은 좌측(§9.4), 줄 높이는 그 줄에서 가장 큰 칩이다(칩은 전부 `tapMin` 44라 실제로는 같다).
struct ReffiFlowLayout: Layout {
    var spacing: CGFloat = ReffiSpace.s2
    var lineSpacing: CGFloat = ReffiSpace.s2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layoutRows(width: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: width == .infinity ? widest : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in layoutRows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                                           proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 칩을 고유 크기로 재서 줄을 나눈다 — 한 줄에 하나도 못 들어갈 만큼 긴 칩은 혼자 한 줄을 차지한다(잘리지 않는다).
    private func layoutRows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let extended = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty && extended > width {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
