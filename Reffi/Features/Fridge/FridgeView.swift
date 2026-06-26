import SwiftUI

/// 냉장고 — 전체 재고를 임박순으로 쌓은 "흰 영수증" 스택(§13).
/// 영수증 냉장고의 IA(스택 + 탭→상세 + 히스토리)를 그대로, 비주얼은 Main의 종이컷 언어로.
/// 카드 탭 → Wallet식으로 펼쳐져 상세(구매정보 + Ate/Tossed), 나머지는 하단에 collapse.
struct FridgeView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var ns
    @State private var selectedID: Ingredient.ID?
    @State private var showHistory = false
    @State private var editing: Ingredient?
    @State private var carouselID: Int? = 0

    private let cardHeight: CGFloat = 128
    private let overlap: CGFloat = -46
    private let cardInset: CGFloat = 18   // 페이지 마진 위 추가 인셋 — 영수증 폭 좁힘(가운데)

    private var items: [Ingredient] { store.sorted }
    private var accent: Color { items.first?.freshness.main ?? ReffiColor.fresh }
    private var selected: Ingredient? { items.first { $0.id == selectedID } }
    private var motion: Animation? { ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion) }

    var body: some View {
        ZStack {
            LiquidGlassBackground(accent: accent)
            if let sel = selected {
                expanded(sel)
            } else {
                collapsed
            }
        }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(item: $editing) { IngredientEditView(ingredient: $0) }
    }

    // MARK: 접힌 스택
    private var collapsed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                header
                historyCarousel
                if items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: overlap) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, ing in
                            FridgeCard(ingredient: ing, depth: i, seed: i, height: cardHeight)
                                .matchedGeometryEffect(id: ing.id, in: ns)
                                .zIndex(Double(i))
                                .contentShape(Rectangle())
                                .onTapGesture { select(ing) }
                                .padding(.horizontal, cardInset)
                        }
                    }
                }
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.top, ReffiSpace.s5)
            .padding(.bottom, 110)
        }
    }

    // MARK: 펼친(Wallet) 레이아웃
    private func expanded(_ sel: Ingredient) -> some View {
        let others = items.filter { $0.id != sel.id }
        return VStack(spacing: 0) {
            doneBar
            ScrollView {
                ExpandedFridgeCard(ingredient: sel, onEdit: { editing = sel })
                    .matchedGeometryEffect(id: sel.id, in: ns)
                    .contentShape(Rectangle())
                    .onTapGesture { deselect() }
                    .padding(.horizontal, ReffiGrid.margin + cardInset)
                    .padding(.top, ReffiSpace.s2)
                    .padding(.bottom, ReffiSpace.s3)
            }
            outcomeButtons(sel)
                .padding(.top, ReffiSpace.s2)
            Spacer(minLength: ReffiSpace.s2)
            if !others.isEmpty { bottomStack(others) }
        }
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            Button { deselect() } label: {
                ReffiIcon.close.reffi(15, .bold)
                    .foregroundStyle(ReffiColor.ink)
                    .frame(width: 40, height: 40)
                    .background {
                        let s = PaperRect(cornerRadius: ReffiRadius.md, seed: 4)
                        s.fill(ReffiColor.oklch(0.99, 0.006, 90)).paperEdge(s)
                    }
                    .reffiShadow1()
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s3)
    }

    /// 처리 — 먹음/버림. store에서 제거 + 카운트 후 복귀.
    private func outcomeButtons(_ sel: Ingredient) -> some View {
        // Main의 결정 오버레이와 동일한 종이컷 아이콘 버튼(기본 88 + s6 간격).
        HStack(spacing: ReffiSpace.s6) {
            PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) {
                remove(sel, ate: false)
            }
            PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) {
                remove(sel, ate: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 하단 collapse 스택 — 나머지 영수증을 띠로 겹침. 탭 시 그 카드로 전환.
    private func bottomStack(_ others: [Ingredient]) -> some View {
        let maxVisible: CGFloat = 132
        let count = max(1, others.count)
        let peek = min(26, (maxVisible - 48) / CGFloat(max(1, count - 1)))
        let visible = CGFloat(count - 1) * peek + 48
        return VStack(spacing: -(cardHeight - peek)) {
            ForEach(Array(others.enumerated()), id: \.element.id) { i, ing in
                FridgeCard(ingredient: ing, depth: i, seed: ing.daysLeft, height: cardHeight)
                    .matchedGeometryEffect(id: ing.id, in: ns)
                    .zIndex(Double(i))
                    .contentShape(Rectangle())
                    .onTapGesture { select(ing) }
            }
        }
        .frame(height: visible, alignment: .top)
        .clipShape(Rectangle())
        .padding(.horizontal, ReffiGrid.margin + cardInset)
        .padding(.bottom, 96)
    }

    // MARK: 헤더
    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            Text("Fridge").reffiType(.display).foregroundStyle(ReffiColor.ink)
            HStack(spacing: ReffiSpace.s2) {
                Text("\(items.count) in stock")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                if store.ateCount + store.tossedCount > 0 {
                    Text("·").foregroundStyle(ReffiColor.muted)
                    Text("Ate \(store.ateCount)")
                        .font(.reffiNum(12, relativeTo: .caption2)).foregroundStyle(ReffiColor.freshDark)
                    Text("Tossed \(store.tossedCount)")
                        .font(.reffiNum(12, relativeTo: .caption2)).foregroundStyle(ReffiColor.urgentDark)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: History 요약 캐러셀 — 옆으로 넘기는 카드 + 페이지 점, 탭하면 상세(History).
    private var historyCarousel: some View {
        VStack(spacing: ReffiSpace.s3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ReffiSpace.s3) {
                    summaryCard(id: 0, title: "Wasted · past 30 days",
                                value: "\(store.wasteRate)%", tint: ReffiColor.urgent)
                    summaryCard(id: 1, title: "Most tossed",
                                value: mostTossed, valueSize: 26, tint: ReffiColor.soon)
                    summaryCard(id: 2, title: "This month",
                                value: "\(store.ateCount) ate · \(store.tossedCount) tossed",
                                valueSize: 20, tint: ReffiColor.fresh)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $carouselID)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == (carouselID ?? 0) ? ReffiColor.ink2 : ReffiColor.muted.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
        }
    }

    /// 자주 버린 품목 1위(없으면 "—").
    private var mostTossed: String {
        let g = Dictionary(grouping: store.history.filter(\.wasted)) { $0.name }
        return g.max { $0.value.count < $1.value.count }?.key ?? "—"
    }

    private func summaryCard(id: Int, title: String, value: String,
                             valueSize: CGFloat = 32, tint: Color) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.lg, seed: id)
        return Button { showHistory = true } label: {
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                HStack {
                    Text(title).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    Spacer()
                    ReffiIcon.chevron.reffi(12, .bold).foregroundStyle(ReffiColor.ink2)
                }
                Spacer(minLength: 0)
                Text(value).font(.reffiNum(valueSize, relativeTo: .largeTitle))
                    .foregroundStyle(ReffiColor.ink).lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(ReffiSpace.s4)
            .frame(height: 104, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.5), in: shape)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .buttonStyle(.paperPress)
        .containerRelativeFrame(.horizontal, count: 20, span: 18, spacing: ReffiSpace.s3)
        .id(id)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text("Nothing here yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
            Text("Add ingredients and they’ll stack up here.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let s = PaperRect(cornerRadius: ReffiRadius.lg, seed: 3)
            s.fill(ReffiColor.sub).paperEdge(s)
        }
    }

    // MARK: 액션
    private func select(_ ing: Ingredient) { withAnimation(motion) { selectedID = ing.id } }
    private func deselect() { withAnimation(motion) { selectedID = nil } }
    private func remove(_ ing: Ingredient, ate: Bool) {
        withAnimation(motion) {
            selectedID = nil
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }
}

/// D-day 도장 — 기울어진 둥근 사각 외곽선 + 글자(영수증 "START" 스탬프 느낌, §13). 색은 신선도색.
struct DDayStamp: View {
    let text: String
    let color: Color
    var size: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(.custom("Pretendard-Bold", size: size, relativeTo: .subheadline))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color, lineWidth: 1.8)
            }
            .rotationEffect(.degrees(-7))
            .accessibilityLabel(text)
    }
}

/// 흰 영수증 카드 한 장 — ReceiptShape + 종이질감 + 음식 실루엣 + 이름. 색은 Due date에만(임박 신호).
struct FridgeCard: View {
    let ingredient: Ingredient
    var depth: Int = 0
    var seed: Int = 0
    var height: CGFloat = 128

    private let toothH: CGFloat = 7

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.oklch(0.985, 0.004, 90)   // 흰 영수증

        return VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            Text(ingredient.category)
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2).lineLimit(1)
            HStack(spacing: ReffiSpace.s3) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: 46, height: 46)
                Text(ingredient.name)
                    .reffiType(.subhead).foregroundStyle(ReffiColor.ink).lineLimit(1)
                Spacer(minLength: ReffiSpace.s3)
                // D-day — 영수증 도장 스타일(신선도색).
                DDayStamp(text: ingredient.dDayText, color: f.dark)
            }
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.top, ReffiSpace.s4 + toothH)
        .padding(.bottom, toothH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background(paper, in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 4, x: 0, y: 2)   // 약한 드롭섀도
    }
}

/// 펼친 상세 — 흰 영수증 한 장에 큰 일러스트 + 구매 정보(영수증 명세). 색은 Due date에만.
struct ExpandedFridgeCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}
    private let toothH: CGFloat = 7

    /// 영수증 번호 — 이름에서 유도(장식, 안정적).
    private var receiptNo: String {
        let s = abs(ingredient.name.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) })
        return String(format: "No. %04d", s % 10000)
    }

    var body: some View {
        let f = ingredient.freshness
        let shape = ReceiptShape(tooth: toothH)
        let paper = ReffiColor.oklch(0.985, 0.004, 90)   // 흰 영수증

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더 — 큰 일러스트 + (카테고리·편집) / (이름·Due date)
            HStack(spacing: ReffiSpace.s4) {
                PaperSilhouette(glyph: ingredient.glyph, fresh: f)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ingredient.category).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        Spacer()
                        Button(action: onEdit) {
                            ReffiIcon.manual.reffi(16, .bold)
                                .foregroundStyle(ReffiColor.ink2)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.paperPress)
                        .accessibilityLabel("Edit")
                    }
                    HStack(alignment: .center) {
                        Text(ingredient.name).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                        Spacer()
                        DDayStamp(text: ingredient.dDayText, color: f.dark, size: 14)
                    }
                }
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s4 + toothH)
            .padding(.bottom, ReffiSpace.s3)

            dashRule
            VStack(spacing: 0) {
                row("Purchased", ingredient.purchasedText)
                row("Where", ingredient.placeText)
                row("Quantity", ingredient.amount)
                row("Expires", "\(ingredient.expiresText) · \(ingredient.dDayText)", valueColor: f.dark)
                row("Storage", ingredient.storage)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s2)

            dashRule
            HStack {
                Text("REFFI · KEEP IT FRESH")
                    .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2)).tracking(1.2)
                    .foregroundStyle(ReffiColor.muted)
                Spacer()
                Text(receiptNo)
                    .font(.reffiNum(11, relativeTo: .caption2)).foregroundStyle(ReffiColor.muted)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s3)
            .padding(.bottom, ReffiSpace.s2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, toothH)
        .background(paper, in: shape)
        .paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    private func row(_ label: String, _ value: String, valueColor: Color = ReffiColor.ink) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer(minLength: ReffiSpace.s4)
                Text(value)
                    .font(.reffiNum(15, relativeTo: .subheadline))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, ReffiSpace.s2 + 2)
        }
    }

    private var dashRule: some View {
        HLine().stroke(ReffiColor.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.horizontal, ReffiSpace.s5)
    }
}

/// 가로 점선/구분선용 1px 라인.
struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
