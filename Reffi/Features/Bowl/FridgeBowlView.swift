import SwiftUI
import SpriteKit
import PhosphorSwift

/// 메인 — 재료가 제 일러스트(FoodMotif)대로 리퀴드글래스 보울 안으로 떨어져 쌓인다(잠긴 부분은 굴절·반투명,
/// 솟은 위는 또렷 + 이름 라벨). 슬라이더로 "냉장고를 얼마나" 정하고, 아래엔 신선도 면 레시피 카드 스택(냉장고
/// 목록과 같은 언어, 좌우 스와이프). 보울 실루엣·물리 벽은 `BowlGeometry` 한 정의에서.
struct FridgeBowlView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene = BowlScene()
    @State private var amount: Double = 0.85
    @State private var disabled: Set<UUID> = []
    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var detail: RecipeRecommender.Result?

    private let threshold: CGFloat = 95
    private let glassBody = ReffiColor.oklch(0.93, 0.018, 242).opacity(0.5)   // 옅은 쿨 글래스 몸체

    private var inBowl: [Ingredient] {
        let all = store.sorted
        guard !all.isEmpty else { return [] }
        let n = max(2, Int((Double(all.count) * amount).rounded()))
        return Array(all.prefix(min(n, all.count)))
    }
    private var recipeIngredients: [Ingredient] { inBowl.filter { !disabled.contains($0.id) } }
    private var recipes: [RecipeRecommender.Result] {
        RecipeRecommender.rank(for: recipeIngredients, from: store.recipes)
    }
    private func freshness(of r: RecipeRecommender.Result) -> Freshness { r.used.first?.freshness ?? .fresh }
    private var topF: Freshness {
        guard !recipes.isEmpty else { return .fresh }
        return freshness(of: recipes[min(index, recipes.count - 1)])
    }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            VStack(spacing: ReffiSpace.s3) {
                header
                DropletSlider(value: $amount)
                bowl.frame(height: H * 0.34)
                recipeArea.frame(maxHeight: .infinity)
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.top, ReffiSpace.s2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [ReffiColor.canvas, topF.light.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: topF)
            )
            .onChange(of: recipeIngredients.map(\.id)) { _, _ in
                if index >= recipes.count { index = max(0, recipes.count - 1) }
            }
        }
        .sheet(item: $detail) { RecipeDetailSheet(result: $0) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("What's cooking?").reffiType(.heading).foregroundStyle(ReffiColor.ink)
            Spacer()
            Text("\(recipeIngredients.count) in bowl")
                .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
        }
    }

    // MARK: - Bowl — 안쪽 면 → 재료(일러스트) → 앞쪽 글래스 벽 → 림 하이라이트

    private var bowl: some View {
        GeometryReader { g in
            let r = CGRect(origin: .zero, size: g.size)
            let shape = BowlGeometry.silhouette(in: r)
            ZStack {
                // 1) 뒤 — 유리 몸체(옅은 쿨 글래스). 색 재료가 또렷이 보이도록 배경 대비.
                shape.fill(glassBody)

                // 2) 중간 — 재료(글래스 안에 가둬져 쌓이고, 윗부분은 윗변 위로 솟음)
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .onAppear {
                        scene.scaleMode = .resizeFill
                        scene.size = g.size
                        scene.onToggle = { id in
                            withAnimation {
                                if disabled.contains(id) { disabled.remove(id) } else { disabled.insert(id) }
                            }
                        }
                        scene.sync(inBowl, disabled: disabled, animated: false)
                    }
                    .onChange(of: g.size) { _, s in scene.size = s }
                    .onChange(of: inBowl.map(\.id)) { _, _ in scene.sync(inBowl, disabled: disabled) }
                    .onChange(of: disabled) { _, d in scene.sync(inBowl, disabled: d) }

                // 3) 앞 — 네이티브 리퀴드 글래스(잠긴 재료를 굴절·반투명). 테두리 없음.
                nativeGlassBowl(shape)

                BowlLabelsOverlay(scene: scene)   // 라벨은 글래스 위 최상단(안 흐려짐)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: topF)
        }
    }

    /// 보울 = **네이티브 리퀴드 글래스**. 직접 셰이딩(그라데이션·하이라이트·테두리)을 그리지 않고 시스템
    /// `.glassEffect` 머티리얼 자체를 보울 면으로 쓴다(신선도색은 글래스 틴트로). 재료는 글래스 뒤에서
    /// 비치고, 림 위로 솟은 부분은 글래스 밖이라 또렷.
    @ViewBuilder
    private func nativeGlassBowl(_ shape: Path) -> some View {
        // 글래스는 솟은 끝(림 위)만 비우고 그 아래는 전체적으로 또렷이 — 효과가 사라지지 않게(굴절 강하게).
        let fade = LinearGradient(
            stops: [.init(color: .clear, location: BowlGeometry.rimY - 0.05),
                    .init(color: .white.opacity(0.9), location: BowlGeometry.rimY + 0.03),
                    .init(color: .white, location: BowlGeometry.botY)],
            startPoint: .top, endPoint: .bottom)
        let tint = ReffiColor.oklch(0.85, 0.04, 242)
        Group {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular.tint(tint.opacity(0.3)), in: shape)
            } else {
                shape.fill(.ultraThinMaterial).overlay(shape.fill(tint.opacity(0.24)))
            }
        }
        .mask(fade)
        .allowsHitTesting(false)
    }

    // MARK: - Recipe — 냉장고 목록과 통일된 신선도 면 카드 스택(좌우 스와이프)

    private var recipeArea: some View {
        VStack(spacing: ReffiSpace.s3) {
            if recipes.isEmpty {
                Spacer()
                Text("Tap a faded ingredient to bring it back")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
                Spacer()
            } else {
                ZStack {
                    ForEach(visibleIndices(), id: \.self) { i in
                        let depth = i - index
                        let isTop = depth == 0
                        heroCard(recipes[i], showBubble: isTop)
                            .scaleEffect(isTop ? 1 : 1 - CGFloat(depth) * 0.06, anchor: .top)
                            .offset(y: isTop ? 0 : CGFloat(depth) * 20)   // 아래로 보이는 스택(냉장고 목록처럼)
                            .offset(isTop ? drag : .zero)
                            .rotationEffect(.degrees(isTop && !reduceMotion ? Double(drag.width) / 20 : 0))
                            .zIndex(Double(100 - depth))
                            .allowsHitTesting(isTop)
                            .gesture(isTop ? cardGesture(recipes[i]) : nil)
                            .onTapGesture { detail = recipes[i] }
                            .animation(reduceMotion ? nil : ReffiMotion.standard, value: index)
                    }
                }
                .frame(maxHeight: .infinity)

                caption
                // 명확한 다음 액션: 현재 카드로 요리 시작. 스와이프는 '다른 아이디어 둘러보기'.
                ReffiButton(title: "Start cooking", icon: ReffiIcon.go, fullWidth: true) {
                    detail = recipes[min(max(index, 0), recipes.count - 1)]
                }
            }
        }
    }

    private func visibleIndices() -> [Int] {
        guard !recipes.isEmpty else { return [] }
        let i = min(max(index, 0), recipes.count - 1)   // 슬라이더로 개수가 줄어도 인덱스 안전(크래시 방지)
        let upper = min(i + 2, recipes.count - 1)
        return Array(i...upper).reversed()
    }

    private let bubbleW: CGFloat = 132
    private let bubbleH: CGFloat = 140

    /// 레시피 카드 — 냉장고 목록(이미지 5)과 같은 언어: 신선도 면(자기 임박 재료색) + 작은 분류 + 큰 숫자 + 이름.
    /// 음식 사진은 일러스트 필터를 입혀 카드 위로 '뾱' 솟는 말풍선으로(상단 카드만).
    private func heroCard(_ result: RecipeRecommender.Result, showBubble: Bool) -> some View {
        let r = result.recipe
        let f = freshness(of: result)
        return ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                Color.clear.frame(height: bubbleH * 0.55)          // 말풍선 겹침 영역
                HStack(alignment: .firstTextBaseline) {
                    Text("RECIPE")
                        .font(.custom("Pretendard-SemiBold", size: 11, relativeTo: .caption2))
                        .tracking(0.8).foregroundStyle(ReffiColor.ink.opacity(0.5))
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        ReffiIcon.time.reffi(13).foregroundStyle(ReffiColor.ink.opacity(0.6))
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                        Text("\(r.minutes)").font(.reffiNum(22, relativeTo: .title))
                        Text("min").font(ReffiTextRole.caption.font).foregroundStyle(ReffiColor.ink.opacity(0.7))
                    }
                    .foregroundStyle(ReffiColor.ink)
                }
                Text(r.name)
                    .font(.custom("Pretendard-Bold", size: 22, relativeTo: .title3))
                    .tracking(22 * -0.01)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                usesLine(result)
            }
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.top, ReffiSpace.s4)
            .padding(.bottom, ReffiSpace.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [f.main, f.face(depth: 2)],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
            .reffiShadow1()

            if showBubble {
                RecipePhotoBubble(keywords: photoKeywords(r), tint: f.dark)
                    .frame(width: bubbleW, height: bubbleH)
                    .offset(y: -bubbleH * 0.45)
            }
        }
    }

    private func photoKeywords(_ r: Recipe) -> String {
        r.name.lowercased().split(separator: " ").joined(separator: ",") + ",food"
    }

    /// 소비 재료 — 신선도 점 + 이름 + D-day(냉장고와 같은 D-N 언어). 점으로 스캔되게.
    private func usesLine(_ result: RecipeRecommender.Result) -> some View {
        let items = Array(result.used.prefix(2))
        return HStack(spacing: ReffiSpace.s2) {
            if !items.isEmpty {
                Text("Uses").font(ReffiTextRole.caption.font).foregroundStyle(ReffiColor.ink.opacity(0.6))
                ForEach(Array(items.enumerated()), id: \.element.id) { _, ing in
                    HStack(spacing: 4) {
                        Circle().fill(ing.freshness.dark).frame(width: 5, height: 5)
                        (Text(ing.name).font(ReffiTextRole.caption.font)
                            + Text(" \(ing.dDayText)").font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ing.freshness.dark))
                            .foregroundStyle(ReffiColor.ink)
                    }
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var caption: some View {
        Text("Swipe for more ideas")
            .reffiType(.caption).foregroundStyle(ReffiColor.muted)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Swipe — 좌우 어느 쪽이든 '다음 아이디어 둘러보기'(요리는 Start cooking으로).

    private func cardGesture(_ r: RecipeRecommender.Result) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { v in
                if abs(v.translation.width) > threshold {
                    let dir: CGFloat = v.translation.width > 0 ? 1 : -1
                    if reduceMotion { advance(); return }
                    withAnimation(ReffiMotion.exit) {
                        drag = CGSize(width: dir * 700, height: v.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + ReffiMotion.dur1) {
                        drag = .zero; advance()
                    }
                } else {
                    withAnimation(ReffiMotion.standard) { drag = .zero }
                }
            }
    }

    private func advance() {
        guard !recipes.isEmpty else { return }
        index = (index + 1) % recipes.count
    }
}

/// 재료 이름 라벨 — 글래스 위 최상단 레이어(블러 없음). 위치는 BowlScene이 매 프레임 알려준다.
/// 자체 @State라 라벨이 움직여도 글래스는 다시 그리지 않는다(성능).
private struct BowlLabelsOverlay: View {
    let scene: BowlScene
    @State private var labels: [BowlScene.LabelLayout] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(labels) { l in
                Text(l.name)
                    .font(.custom("Pretendard-Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(ReffiColor.ink2)
                    .shadow(color: .white.opacity(0.6), radius: 1.5)
                    .opacity(Double(l.alpha))
                    .position(l.pos)
            }
        }
        .allowsHitTesting(false)
        .onAppear { scene.onLayout = { labels = $0 } }
    }
}

/// 가로 슬라이더 — "냉장고를 얼마나" → 보울 채움량. 핸들은 둥근 네모(완전 원 금지).
struct DropletSlider: View {
    @Binding var value: Double
    @GestureState private var grabbing = false

    var body: some View {
        VStack(spacing: ReffiSpace.s1) {
            HStack {
                Text("How much of your fridge?").reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                Spacer()
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(ReffiColor.sub).frame(height: 6)
                    Capsule().fill(ReffiColor.blue).frame(width: max(12, w * value), height: 6)
                    handle
                        .frame(width: 22, height: 28)
                        .scaleEffect(grabbing ? 1.25 : 1)
                        .offset(x: max(0, w * value - 11))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: grabbing)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value)
                }
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($grabbing) { _, s, _ in s = true }
                        .onChanged { g in value = min(1, max(0, g.location.x / w)) }
                )
            }
            .frame(height: 28)
            HStack {
                Text("Less").reffiType(.caption).foregroundStyle(ReffiColor.muted)
                Spacer()
                Text("More").reffiType(.caption).foregroundStyle(ReffiColor.muted)
            }
        }
    }

    @ViewBuilder
    private var handle: some View {
        if grabbing, #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: ReffiRadius.sm, style: .continuous)
                .fill(.clear).glassEffect(.regular.interactive(),
                                          in: RoundedRectangle(cornerRadius: ReffiRadius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ReffiRadius.sm, style: .continuous)
                    .strokeBorder(ReffiColor.blue.opacity(0.6), lineWidth: 2))
        } else {
            RoundedRectangle(cornerRadius: ReffiRadius.sm, style: .continuous)
                .fill(ReffiColor.blue)
                .overlay(RoundedRectangle(cornerRadius: 3).fill(.white).frame(width: 8, height: 12))
                .reffiShadow1()
        }
    }
}
