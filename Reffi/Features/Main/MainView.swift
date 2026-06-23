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
    @State private var showProfile = false

    private let margin = ReffiGrid.margin
    private let navClearance: CGFloat = 86

    private var dropIngredients: [Ingredient] { Array(store.sorted.prefix(6)) }
    private var activeIngredients: [Ingredient] { dropIngredients }   // Ate/Tossed는 store에서 직접 제거
    private var carouselResults: [RecipeRecommender.Result] {
        Array(RecipeRecommender.rank(for: activeIngredients, from: store.recipes).prefix(3))
    }
    private var topF: Freshness { dropIngredients.first?.freshness ?? .fresh }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s2)

            physicsField
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !activeIngredients.isEmpty {
                badgeRow
                    .padding(.horizontal, margin)
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
        .fullScreenCover(isPresented: $showCarousel) {
            RecipeMemoCarousel(results: carouselResults) { showCarousel = false }
        }
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showProfile) {
            MyPagePlaceholderView().presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        #if DEBUG
        .onAppear {   // 미리보기/검증용: `-previewCarousel 1`로 캐러셀 바로 열기.
            if ProcessInfo.processInfo.arguments.contains("-previewCarousel") { showCarousel = true }
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
            LinearGradient(colors: [.white.opacity(0.22), .clear, .white.opacity(0.06)],
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
                Button { showProfile = true } label: {
                    ReffiIcon.profile.reffi(19, .regular)
                        .foregroundStyle(ReffiColor.ink2)
                        .frame(width: 36, height: 36)
                        .background(ReffiColor.sub, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel("내 프로필")
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
                    .overlay { IngredientLabelsOverlay(scene: scene) }
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

    // MARK: - Badge row (persistent)

    private var badgeRow: some View {
        FlowLayout(spacing: ReffiSpace.s2, lineSpacing: ReffiSpace.s2) {
            ForEach(Array(activeIngredients.enumerated()), id: \.element.id) { i, ing in
                IngredientBadge(ingredient: ing, seed: i) { decide(ing.id) }
                    .transition(.scale(scale: 1.3, anchor: .center).combined(with: .opacity))   // 뿅 사라짐
            }
            AddBadge(seed: activeIngredients.count) { showAdd = true }
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
            Color.black.opacity(0.22).ignoresSafeArea()
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
        showCarousel = true
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

/// 재료 위 작은 이름 라벨 — 물리 씬이 매 프레임 위치를 알려준다(SpriteView 위 최상단, 안 흐려짐).
private struct IngredientLabelsOverlay: View {
    let scene: IngredientDropScene
    @State private var labels: [IngredientDropScene.LabelInfo] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(labels) { l in
                HStack(spacing: 4) {
                    Circle().fill(l.fresh.dark).frame(width: 5, height: 5)   // 신선도 점
                    Text(l.name)
                        .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
                        .foregroundStyle(ReffiColor.ink)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.85), in: Capsule())
                .opacity(Double(max(0.25, l.alpha)))
                .position(l.pos)
            }
        }
        .allowsHitTesting(false)
        .onAppear { scene.onLayout = { labels = $0 } }
    }
}
