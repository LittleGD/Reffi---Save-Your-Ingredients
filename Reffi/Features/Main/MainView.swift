import SwiftUI
import SpriteKit
import PhosphorSwift

/// 메인(§13) — 임박 재료 선택 + 요리하기, 단 두 가지.
/// 추천 임박 재료가 위에서 **진짜 물리로 떨어져 쌓여 그대로 남고**(SpriteKit, 끌어서 던지기·탭 토글),
/// 버튼 위엔 같은 재료의 **뱃지**가 함께 남는다. 실루엣·뱃지 어느 쪽을 탭해도 끄고(dim), ＋로 추가.
/// **요리시작**을 누르면 오더 메모 캐러셀(네비 없음)로.
struct MainView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene = IngredientDropScene()
    @State private var deciding: Ingredient?       // Ate/Tossed 결정 중인 재료
    @State private var showCarousel = false
    @State private var showAdd = false
    @State private var shownIDs: [UUID] = []        // 표시 중인 재료(고정 — 없애면 줄기만)
    @State private var knownIDs: Set<UUID> = []     // 지금까지 등장한 모든 재료(추가분 판별용)
    @State private var carouselSnapshot: [RecipeRecommender.Result] = []   // 커버 입력 동결(발주 중 재랭크 방지)
    @State private var undoFired: [Ingredient] = []  // 되돌리기용
    @State private var showUndo = false

    private let margin = ReffiGrid.margin
    private let navClearance: CGFloat = 86

    /// 표시 중인 재료 — 스냅샷(`shownIDs`) 순서대로 store에 아직 있는 것. 없애면 줄기만 하고
    /// **자동 보충하지 않는다**(+Add로 추가된 것만 `absorbAdded`로 들어온다).
    private var activeIngredients: [Ingredient] {
        let byID = Dictionary(store.ingredients.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return shownIDs.compactMap { byID[$0] }
    }
    private var carouselResults: [RecipeRecommender.Result] {
        Array(RecipeRecommender.rank(for: activeIngredients, from: store.recipes).prefix(3))
    }
    private var topF: Freshness { activeIngredients.first?.freshness ?? .fresh }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s2)

            physicsField
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !activeIngredients.isEmpty {
                badgeSection
                    .padding(.bottom, ReffiSpace.s2)
            }

            PaperButton(title: "Start cooking") { cook() }
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                .padding(.bottom, navClearance)
                .disabled(activeIngredients.isEmpty)
                .opacity(activeIngredients.isEmpty ? 0.5 : 1)
        }
        .background(liquidGlassBackground)
        .overlay { if let ing = deciding { decisionOverlay(ing) } }
        .overlay(alignment: .bottom) {
            if showUndo {
                undoToast
                    .padding(.bottom, navClearance + 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showCarousel) {
            RecipeMemoCarousel(results: carouselSnapshot,
                               onClose: { showCarousel = false },
                               onFire: fire)
        }
        .sheet(isPresented: $showAdd, onDismiss: absorbAdded) {
            AddIngredientSheet().presentationDetents([.medium, .large])
        }
        .onAppear {
            if shownIDs.isEmpty {   // 최초 1회 — 표시할 임박 재료 스냅샷(이후 자동 보충 없음)
                shownIDs = Array(store.sorted.prefix(6).map(\.id))
                knownIDs = Set(store.ingredients.map(\.id))
            }
        }
        #if DEBUG
        .onAppear {   // 미리보기/검증용: `-previewCarousel 1`로 캐러셀 바로 열기.
            if ProcessInfo.processInfo.arguments.contains("-previewCarousel") {
                if shownIDs.isEmpty {
                    shownIDs = Array(store.sorted.prefix(6).map(\.id))
                    knownIDs = Set(store.ingredients.map(\.id))
                }
                carouselSnapshot = carouselResults
                showCarousel = true
            }
        }
        #endif
    }

    // MARK: - Liquid glass background

    private var liquidGlassBackground: some View {
        ZStack {
            ReffiColor.canvas
            // 부드러운 컬러 블롭(신선도 + 블루) → 리퀴드 느낌
            Circle().fill(topF.main.opacity(0.55)).frame(width: 300, height: 300).blur(radius: 80)
                .offset(x: -130, y: -180)
            Circle().fill(ReffiColor.blue.opacity(0.3)).frame(width: 260, height: 260).blur(radius: 90)
                .offset(x: 140, y: 60)
            Circle().fill(topF.dark.opacity(0.16)).frame(width: 220, height: 220).blur(radius: 80)
                .offset(x: 70, y: 300)
            // 글래스 프로스트(뒤 블롭을 흐려 리퀴드글래스) + 상단 시노
            glassFrost
            LinearGradient(colors: [ReffiColor.bgSheen, .clear, .white.opacity(0.06)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .animation(ReffiMotion.gated(.easeInOut(duration: 0.5), reduce: reduceMotion), value: topF)
    }

    @ViewBuilder private var glassFrost: some View {
        if #available(iOS 26.0, *) {
            Rectangle().fill(.clear).glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            HStack(alignment: .center) {
                Text("Reffi").reffiType(.display).foregroundStyle(ReffiColor.ink)
                Spacer()
                Text(Self.today)
                    .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
            }
            HStack(spacing: ReffiSpace.s2) {
                Text("Tap one — did you eat it, or toss it?")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                if store.ateCount + store.tossedCount > 0 {
                    Text("·").foregroundStyle(ReffiColor.muted)
                    Text("Ate \(store.ateCount)").font(.reffiNum(12, relativeTo: .caption2)).foregroundStyle(ReffiColor.freshDark)
                    Text("Tossed \(store.tossedCount)").font(.reffiNum(12, relativeTo: .caption2)).foregroundStyle(ReffiColor.urgentDark)
                }
            }
        }
    }

    // MARK: - Physics field (real engine, persistent pile)

    private var physicsField: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .onAppear { configureScene(size: geo.size) }
                    .onChange(of: geo.size) { _, s in scene.size = s }
                    .onChange(of: activeIngredients.map(\.id)) { _, _ in scene.sync(activeIngredients) }
                if activeIngredients.isEmpty { emptyField }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func configureScene(size: CGSize) {
        scene.scaleMode = .resizeFill
        scene.size = size
        scene.reduceMotion = reduceMotion
        scene.onRemove = { id in decide(id) }
        scene.sync(activeIngredients)
    }

    private var emptyField: some View {
        VStack(spacing: ReffiSpace.s4) {
            ReffiIcon.fridge.reffi(40).foregroundStyle(ReffiColor.muted)
            Text("Nothing to use yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink2)
            AddBadge { showAdd = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Freshness gauge + badge scroll (persistent)

    private var badgeSection: some View {
        VStack(spacing: ReffiSpace.s2 + 2) {
            badgeScroll
            freshnessDots
        }
    }

    /// 신선도 점 인디케이터 — 재료당 점 1개(색=신선도, 임박순), 뱃지 행 아래 중앙.
    private var freshnessDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(activeIngredients.enumerated()), id: \.element.id) { _, ing in
                Circle()
                    .fill(ing.freshness.dark)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: activeIngredients.map(\.id))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("임박 재료 \(activeIngredients.count)개")
    }

    /// 뱃지 행 — 긴급도순 가로 스크롤(가장 임박이 맨 앞). 끝에 ＋추가.
    private var badgeScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(Array(activeIngredients.enumerated()), id: \.element.id) { i, ing in
                    IngredientBadge(ingredient: ing, seed: i) { decide(ing.id) }
                        .transition(.scale(scale: 1.3, anchor: .center).combined(with: .opacity))   // 뿅 사라짐
                }
                AddBadge(seed: activeIngredients.count) { showAdd = true }
            }
            .padding(.horizontal, margin)
            .padding(.vertical, ReffiSpace.s1)   // 그림자 여유
        }
        .animation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion), value: activeIngredients.map(\.id))
    }

    // MARK: - Ate / Tossed decision

    /// 재료 탭 → "먹었나 버렸나" 묻기.
    private func decide(_ id: UUID) {
        guard let ing = activeIngredients.first(where: { $0.id == id }) else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { deciding = ing }
    }

    /// 선택 확정 → store에서 제거(실루엣·뱃지 뿅 사라짐) + 카운트.
    private func commit(_ ing: Ingredient, ate: Bool) {
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            deciding = nil
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }

    /// Ate/Tossed 결정 오버레이 — 딤 배경 + 종이 카드 + 종이컷 아이콘 버튼 쌍.
    private func decisionOverlay(_ ing: Ingredient) -> some View {
        ZStack {
            ReffiColor.scrim.ignoresSafeArea()
                .onTapGesture { withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { deciding = nil } }
            VStack(spacing: ReffiSpace.s5) {
                VStack(spacing: 2) {
                    Text(ing.name).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    Text("Did you eat it, or toss it?")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                HStack(spacing: ReffiSpace.s6) {
                    PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) { commit(ing, ate: false) }
                    PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) { commit(ing, ate: true) }
                }
            }
            .padding(.horizontal, ReffiSpace.s6)
            .padding(.vertical, ReffiSpace.s6)
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.xl)
                shape.fill(ReffiColor.canvas).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            }
            .reffiShadow1()
            .padding(.horizontal, ReffiSpace.s7)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private func cook() {
        guard !activeIngredients.isEmpty else { return }
        carouselSnapshot = carouselResults   // 발주로 store가 바뀌어도 커버 입력은 고정(재랭크 방지)
        showCarousel = true
    }

    /// 티켓 발주(Fire the Ticket) — used 재료를 전부 Ate 처리(비우기) → 슬램 본 뒤 커버 닫고 undo 토스트.
    private func fire(_ result: RecipeRecommender.Result) {
        let used = result.used   // 스냅샷(이후 store 변경과 무관)
        guard !used.isEmpty else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            for ing in used { store.eat(ing) }
        }
        undoFired = used
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            showCarousel = false
            withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { showUndo = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if showUndo { withAnimation { showUndo = false }; undoFired = [] }
            }
        }
    }

    private func undoFire() {
        store.uneat(undoFired)
        undoFired = []
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) { showUndo = false }
    }

    private var undoToast: some View {
        HStack(spacing: ReffiSpace.s3) {
            ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.fresh)
            Text("Saved \(undoFired.count) from the bin")
                .reffiType(.caption).foregroundStyle(.white)
            Spacer(minLength: ReffiSpace.s2)
            Button { undoFire() } label: {
                Text("Undo")
                    .font(.custom("Pretendard-SemiBold", size: 14, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.blueLight)
            }
            .buttonStyle(.paperPress)
        }
        .padding(.horizontal, ReffiSpace.s4).padding(.vertical, ReffiSpace.s3)
        .background(ReffiColor.ink, in: Capsule())
        .reffiShadow1()
        .padding(.horizontal, margin)
    }

    /// +Add로 새로 추가된 재료만 더미에 흡수(기존 미표시분은 보충하지 않음).
    private func absorbAdded() {
        let added = store.ingredients.filter { !knownIDs.contains($0.id) }
        guard !added.isEmpty else { return }
        knownIDs.formUnion(added.map(\.id))
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            shownIDs.append(contentsOf: added.map(\.id))
        }
    }

    private static let today: String = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.setLocalizedDateFormatFromTemplate("MMMd EEEE")
        return f.string(from: Date())
    }()
}

/// 줄바꿈(wrap) 레이아웃 — 뱃지 행이 폭을 넘으면 가운데 정렬로 다음 줄로(§13). iOS 16+ Layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        let rows = rows(maxW: maxW, subviews: subviews)
        let h = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        let w = rows.map(\.width).max() ?? 0
        return CGSize(width: maxW.isFinite ? maxW : w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(maxW: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for idx in row.indices {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                    proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(maxW: CGFloat, subviews: Subviews) -> [Row] {
        var out: [Row] = []
        var row = Row()
        for (i, sv) in subviews.enumerated() {
            let size = sv.sizeThatFits(.unspecified)
            let lead = row.indices.isEmpty ? 0 : spacing
            if !row.indices.isEmpty, row.width + lead + size.width > maxW {
                out.append(row); row = Row()
            }
            let lead2 = row.indices.isEmpty ? 0 : spacing
            row.indices.append(i)
            row.width += lead2 + size.width
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { out.append(row) }
        return out
    }
}

