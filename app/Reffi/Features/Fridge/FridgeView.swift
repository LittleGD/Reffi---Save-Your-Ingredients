import SwiftUI
import SwiftData
import PhosphorSwift

/// 냉장고 탭 — 재료 카드 스택(§8), Apple Wallet식 인터랙션.
/// 탭하면 그 카드가 위로 확대되고 나머지는 하단에 얇게 collapse, 카드 아래에 상세 정보가 붙는다.
/// `matchedGeometryEffect`로 접힌 스택 ↔ 펼친 레이아웃 사이를 카드가 모핑한다.
struct FridgeView: View {
    @Query(sort: \Ingredient.expiryDate, order: .forward)
    private var ingredients: [Ingredient]

    /// 누적 폐기/소비 이력 — 낭비율 마커용.
    @Query private var removals: [RemovalLog]

    @Namespace private var ns
    @State private var selectedID: PersistentIdentifier?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context

    /// 스와이프 중인 카드와 가로 오프셋(왼쪽으로만). 삭제 확인 대상.
    @State private var swipedID: PersistentIdentifier?
    @State private var swipeX: CGFloat = 0
    @State private var pendingDelete: Ingredient?

    /// 왼쪽 스와이프 임계값 — 이만큼 끌면 삭제 확인.
    private let deleteThreshold: CGFloat = -90

    /// 낭비율 바 탭 → 버린 항목 목록 / 펜슬 → 편집.
    @State private var showWasted = false
    @State private var editingItem: Ingredient?

    /// 카드 겹침(§8.2): 보이는 띠 ~72pt(카드 높이 120 − 48).
    private let overlap: CGFloat = -48
    private let cardHeight: CGFloat = 120

    private var selected: Ingredient? {
        guard let id = selectedID else { return nil }
        return ingredients.first { $0.persistentModelID == id }
    }

    private var motion: Animation? {
        reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)
    }

    /// 최근 30일 이력 — 낭비율 바는 한달치 기준.
    private var recentRemovals: [RemovalLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return removals.filter { $0.removedDate >= cutoff }
    }

    /// 낭비율 — 버림 / (버림 + 소비), 최근 30일. 이력 없으면 0%.
    private var wastePercent: Int {
        let total = recentRemovals.count
        guard total > 0 else { return 0 }
        let wasted = recentRemovals.lazy.filter(\.wasted).count
        return Int((Double(wasted) / Double(total) * 100).rounded())
    }


    /// 낭비율 색(캔버스 위라 dark 변형, §2.6) — 낮을수록 fresh, 높을수록 urgent.
    private var wasteColor: Color {
        switch wastePercent {
        case ...10: return ReffiColor.freshDark
        case ...30: return ReffiColor.soonDark
        default:    return ReffiColor.urgentDark
        }
    }

    /// 마커 카드 배경 — 낭비율 위험도에 연동된 옅은 세로 그라데이션(위 진함 → 아래 옅음).
    private var wasteCardGradient: LinearGradient {
        let pair: (String, String)
        switch wastePercent {
        case ...10: pair = ("#E5F5D9", "#F2FAEA") // fresh
        case ...30: pair = ("#FDEDCD", "#FEF7E8") // soon
        default:    pair = ("#FFDDD3", "#FFEFE9") // urgent
        }
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                              startPoint: .top, endPoint: .bottom)
    }

    /// 냉장고 페이지 배경 — 위 크림 → 아래 옅은 살구빛 세로 그라데이션.
    private static let pageGradient = LinearGradient(
        colors: [Color(hex: "#F8F5EC"), Color(hex: "#FBE6DC")],
        startPoint: .top, endPoint: .bottom
    )

    var body: some View {
        ZStack {
            Self.pageGradient.ignoresSafeArea()

            if let sel = selected {
                expanded(sel)
            } else {
                collapsed
            }
        }
        .alert(
            "Delete this item?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { item in
            Button("Delete", role: .destructive) { delete(item) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { item in
            Text("\(item.name) will be removed from your fridge. This can’t be undone.")
        }
        .sheet(isPresented: $showWasted) {
            HistoryView()
        }
        .sheet(item: $editingItem) { item in
            IngredientEditView(ingredient: item)
        }
    }

    // MARK: 접힌 스택
    private var collapsed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s5) {
                header

                if ingredients.isEmpty {
                    emptyState
                } else {
                    wasteMarker
                    VStack(spacing: overlap) {
                        ForEach(Array(ingredients.enumerated()), id: \.element.persistentModelID) { index, item in
                            swipeRow(item)
                                // 신선할수록(아래로) 위에 깔려 맨 끝 카드가 전체 노출, 임박 카드는 얇은 띠.
                                .zIndex(Double(index))
                        }
                    }
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s5)
            .padding(.bottom, Space.s7)
        }
    }

    /// 한 장의 카드 + 왼쪽 스와이프 삭제 reveal. 가로 드래그=삭제, 세로=스크롤(simultaneous), 탭=선택.
    private func swipeRow(_ item: Ingredient) -> some View {
        let x = swipedID == item.persistentModelID ? swipeX : 0
        return ZStack(alignment: .trailing) {
            // 카드 뒤 삭제 면(붉은 dark) + 휴지통 — 왼쪽으로 끌면 trailing이 드러난다.
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(ReffiColor.urgentDark)
                .overlay(alignment: .trailing) {
                    ReffiIcon.trash.reffi(22, .bold)
                        .foregroundStyle(.white)
                        .padding(.trailing, Space.s5)
                        .opacity(x < -8 ? 1 : 0)
                }

            IngredientCardView(ingredient: item)
                .offset(x: x)
        }
        .frame(height: cardHeight)
        .matchedGeometryEffect(id: item.persistentModelID, in: ns)
        .contentShape(Rectangle())
        .onTapGesture { if x == 0 { select(item) } }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    // 가로 우세일 때만 스와이프로 처리 — 세로는 ScrollView가 가져간다.
                    guard abs(v.translation.width) > abs(v.translation.height) else { return }
                    swipedID = item.persistentModelID
                    swipeX = max(-140, min(0, v.translation.width))
                }
                .onEnded { v in
                    let triggered = v.translation.width < deleteThreshold
                    withAnimation(motion) { swipeX = 0; swipedID = nil }
                    if triggered { pendingDelete = item }
                }
        )
    }

    // MARK: 펼친(Wallet) 레이아웃 — 선택 카드 위로, 나머지 하단 collapse, 카드 아래 상세
    private func expanded(_ sel: Ingredient) -> some View {
        let others = ingredients.filter { $0.persistentModelID != sel.persistentModelID }
        return VStack(spacing: 0) {
            doneBar

            ScrollView {
                ExpandedIngredientCard(ingredient: sel, onEdit: { editingItem = sel })
                    .matchedGeometryEffect(id: sel.persistentModelID, in: ns)
                    .contentShape(Rectangle())
                    .onTapGesture { deselect() }
                    .padding(.horizontal, Space.s4)
                    .padding(.top, Space.s2)
            }

            // 카드 아래 — 소비/버림 선택(스크롤 밖 고정이라 안 잘림).
            outcomeButtons(sel)
                .padding(.top, Space.s4)

            Spacer(minLength: Space.s3)

            if !others.isEmpty {
                bottomStack(others)
            }
        }
    }

    /// 처리 선택 — 버림(빨강 휴지통) / 먹음(파랑 그릇). 고른 값으로 낭비율에 집계 후 제거·복귀.
    private func outcomeButtons(_ sel: Ingredient) -> some View {
        HStack(spacing: Space.s7) {
            outcomeButton("Tossed", icon: ReffiIcon.trash,
                          fg: ReffiColor.urgentDark, bg: ReffiColor.urgentLight) {
                remove(sel, wasted: true)
            }
            outcomeButton("Ate", icon: ReffiIcon.cook,
                          fg: .white, bg: ReffiColor.blue) {
                remove(sel, wasted: false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeButton(_ label: String, icon: Ph, fg: Color, bg: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Space.s2) {
                icon.reffi(24, .bold)
                    .foregroundStyle(fg)
                    .frame(width: 62, height: 62)
                    .background(bg, in: ScallopedCircle())
                Text(label)
                    .reffiText(ReffiType.caption)
                    .foregroundStyle(ReffiColor.ink2)
            }
        }
        .buttonStyle(ReffiPressStyle())
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            Button { deselect() } label: {
                Text("Done")
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.blue)
            }
            .accessibilityLabel("Close detail")
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s3)
    }

    /// 하단 collapse 스택 — 카드를 띠로 겹침. 총 높이를 한도 내로 제한해(카드 수 많아도)
    /// 펼친 카드가 밀려 잘리지 않게 한다. 카드 탭 시 그 카드로 전환.
    private func bottomStack(_ others: [Ingredient]) -> some View {
        let maxVisible: CGFloat = 124   // 하단 스택 최대 높이
        let count = max(1, others.count)
        let peek = min(24, (maxVisible - 46) / CGFloat(max(1, count - 1)))
        let visible = CGFloat(count - 1) * peek + 46
        return VStack(spacing: -(cardHeight - peek)) {
            ForEach(Array(others.enumerated()), id: \.element.persistentModelID) { i, item in
                IngredientCardView(ingredient: item)
                    .frame(height: cardHeight)
                    .matchedGeometryEffect(id: item.persistentModelID, in: ns)
                    .zIndex(Double(i))
                    .contentShape(Rectangle())
                    .onTapGesture { select(item) }
            }
        }
        .frame(height: visible, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .padding(.horizontal, Space.s4)
        .padding(.bottom, Space.s4)
        // 위로 드래그(또는 탭)하면 전체 스택 화면으로 복귀.
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { v in
                    if v.translation.height < -40 { deselect() }
                }
        )
    }

    // MARK: 공통 조각

    /// 카드 스택 맨 위 낭비율 마커 — "지금까지 버린 음식 %"를 프로그레스 바로.
    private var wasteMarker: some View {
        Button { showWasted = true } label: {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(alignment: .top) {
                    // 강조된 버림 % (큰 숫자)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wasted so far")
                            .reffiText(ReffiType.caption)
                            .foregroundStyle(ReffiColor.ink2)
                        HStack(alignment: .center, spacing: Space.s2) {
                            ReffiIcon.trash.reffi(18, .bold)
                                .foregroundStyle(wasteColor)
                            Text("\(wastePercent)%")
                                .reffiText(ReffiType.heading)
                                .num()
                                .foregroundStyle(wasteColor)
                        }
                    }
                    Spacer()
                    // 한달치 기준 명시 + 목록 진입 affordance
                    HStack(spacing: Space.s1) {
                        Text("Past 30 days")
                            .reffiText(ReffiType.caption)
                            .foregroundStyle(ReffiColor.muted)
                        ReffiIcon.chevron.reffi(11, .bold)
                            .foregroundStyle(ReffiColor.muted)
                    }
                }
                wasteBar
            }
            .padding(Space.s4)
            .background(wasteCardGradient, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .buttonStyle(ReffiPressStyle())
        .accessibilityLabel("Wasted \(wastePercent) percent in the past 30 days. View wasted items.")
    }

    /// 존 게이지 — 초록→앰버→빨강(좋음→나쁨) 스케일 트랙 위에 현재 버림%로 노브.
    /// 노브 위치 = "얼마나 버렸나", 노브가 놓인 색 = "좋은지/나쁜지". 끝 경고 뱃지 = 위험(빨강) 끝.
    private var wasteBar: some View {
        let trackH: CGFloat = 10
        let knob: CGFloat = 22
        let badge: CGFloat = 30
        let gap: CGFloat = 8
        let frac = CGFloat(min(100, max(0, wastePercent))) / 100
        return VStack(spacing: Space.s1) {
            GeometryReader { geo in
                let trackW = max(0, geo.size.width - badge - gap)
                let knobX = frac * max(0, trackW - knob)
                HStack(spacing: gap) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [ReffiColor.fresh, ReffiColor.soon, ReffiColor.urgent],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(height: trackH)

                        Circle()
                            .fill(.white)
                            .frame(width: knob, height: knob)
                            .overlay(Circle().strokeBorder(ReffiColor.ink.opacity(0.14), lineWidth: 1))
                            .reffiFloatingShadow()
                            .offset(x: knobX)
                    }
                    .frame(width: trackW, height: knob)

                    ZStack {
                        ScallopedCircle().fill(.white)
                        ReffiIcon.warning.reffi(15, .bold)
                            .foregroundStyle(ReffiColor.urgentDark)
                    }
                    .frame(width: badge, height: badge)
                    .reffiFloatingShadow()
                }
                .frame(height: knob)
            }
            .frame(height: knob)

            // 0~100% 척도
            HStack {
                Text("0%")
                Spacer()
                Text("100%")
            }
            .reffiText(ReffiType.caption)
            .foregroundStyle(ReffiColor.muted)
            .padding(.trailing, badge + gap)
        }
    }

    private var header: some View {
        Text("Ingredients")
            .reffiText(ReffiType.heading)
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Nothing here yet")
                .reffiText(ReffiType.subhead)
                .foregroundStyle(ReffiColor.ink)
            Text("Scan a receipt and fresh items stack up automatically")
                .reffiText(ReffiType.body)
                .foregroundStyle(ReffiColor.ink2)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.neutral200)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    // MARK: 액션
    private func select(_ item: Ingredient) {
        withAnimation(motion) { selectedID = item.persistentModelID }
    }
    private func deselect() {
        withAnimation(motion) { selectedID = nil }
    }

    private func delete(_ item: Ingredient) {
        // 만료(유통기한 지남) 상태로 지우면 '버림', 아니면 '소비'로 누적 집계.
        context.insert(RemovalLog(name: item.name, category: item.category, wasted: item.daysLeft <= 0))
        withAnimation(motion) { context.delete(item) }
        try? context.save()
        pendingDelete = nil
    }

    /// 상세에서 명시적으로 처리 — 사용자가 고른 wasted 값으로 집계 후 제거·복귀.
    private func remove(_ item: Ingredient, wasted: Bool) {
        context.insert(RemovalLog(name: item.name, category: item.category, wasted: wasted))
        withAnimation(motion) {
            selectedID = nil
            context.delete(item)
        }
        try? context.save()
    }
}

#Preview {
    FridgeView()
        .modelContainer(for: Ingredient.self, inMemory: true)
}
