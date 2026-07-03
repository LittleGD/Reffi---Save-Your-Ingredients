import SwiftUI
import SpriteKit
import PhosphorSwift

/// 메인(§13) — 임박 재료 선택 + 요리하기, 단 두 가지.
/// 작업대(`FridgeStore.counterIngredients`)의 재료가 위에서 **진짜 물리로 떨어져 쌓여 그대로 남고**
/// (SpriteKit, 끌어서 던지기·탭 판정), 버튼 위엔 같은 재료의 **뱃지**가 함께 남는다.
/// 판정으로 빈 자리는 냉장고의 다음 임박 재료가 채운다(§13.6). **요리시작**을 누르면 오더 메모 캐러셀로.
/// 작업대·되돌리기 상태는 store에 살아 탭을 오가도 유지된다(undo 토스트는 RootTabView 공통).
struct MainView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 알림 유도(프리퍼미션) — 첫 임박 재료가 생긴 순간이 가치가 증명되는 순간이다.
    // 알림은 기본 OFF + 스위치가 MyPage에만 있어, 여기서 한 번 제안하지 않으면 발견되지 않는다.
    @AppStorage(ExpiryNotifier.enabledKey) private var alertsEnabled = false
    @AppStorage("expiryAlertPromptSeen") private var alertPromptSeen = false

    /// 현재 탭으로 표시 중인지 — 아닐 때 물리 씬을 일시정지한다(배터리).
    var isActive: Bool = true

    /// SKScene 보관 박스 — @State 초기값 식은 뷰 구조체가 재생성될 때마다 평가되므로(예: undo 토스트
    /// 등장·소멸마다 RootTabView body 재평가 → MainView 재구성) 씬을 게으르게 만들어 1회만 생성한다.
    private final class SceneBox { lazy var scene = IngredientDropScene() }
    @State private var sceneBox = SceneBox()
    private var scene: IngredientDropScene { sceneBox.scene }
    @State private var deciding: Ingredient?       // Ate/Tossed 결정 중인 재료(투명 풀스크린 커버)
    @State private var showCarousel = false
    @State private var showSteps = false           // 단계별 레시피(발주 직후 + Cooking now 카드에서)
    @State private var showAdd = false
    @State private var carouselSnapshot: [RecipeRecommender.Result] = []   // 커버 입력 동결(발주 중 재랭크 방지)
    @State private var firedTicket = false         // 커버당 발주 1회 — 슬램 창의 더블 파이어 방지
    @State private var coverGeneration = 0         // 지연 닫기 타이머가 새로 연 커버를 닫지 못하게
    @State private var fireHaptic = 0
    @State private var decisionHaptic = 0

    private let margin = ReffiGrid.margin
    private let navClearance: CGFloat = 86

    private var counter: [Ingredient] { store.counterIngredients }
    private var carouselResults: [RecipeRecommender.Result] {
        // 소비 후보 = 전체 가용 재고(예약 제외) — 티켓이 쓰는 재료가 작업대 밖에 있어도
        // 함께 소비 처리돼 '실제로 썼는데 재고에 남는' 유령 재고가 생기지 않는다.
        Array(store.rankedRecipes.prefix(3))
    }
    private var topF: Freshness { counter.first?.freshness ?? .fresh }
    private var urgentCount: Int { counter.lazy.filter { $0.freshness == .urgent }.count }
    private var soonCount: Int { counter.lazy.filter { $0.freshness == .soon }.count }
    /// 씬 일시정지 — 다른 탭, 캐러셀·판정 커버에 가려진 동안은 물리 렌더를 멈춘다.
    private var scenePaused: Bool { !isActive || showCarousel || deciding != nil }
    /// 씬 동기화 트리거 — id·이름·글리프·신선도 어느 것이 바뀌어도 칩이 따라간다.
    private var sceneSyncKey: [String] {
        counter.map { "\($0.id.uuidString)#\($0.name)#\($0.glyph.rawValue)#\($0.freshness)" }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s2)

            // 발주 진행 카드(§13.6 C) — 헤더 아래 죽은 공간이 상태 표면이 된다.
            if let cook = store.activeCook {
                cookingNowCard(cook)
                    .padding(.horizontal, margin)
                    .padding(.top, ReffiSpace.s3)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showAlertPrompt {
                alertPromptCard
                    .padding(.horizontal, margin)
                    .padding(.top, ReffiSpace.s3)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            physicsField
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !counter.isEmpty {
                badgeScroll
                    .padding(.bottom, ReffiSpace.s2)
                    .id(dayTick)   // 자정 경과 시 D-day·신선도색 재계산
            }

            PaperButton(title: "Start cooking") { cook() }
                .padding(.horizontal, margin)
                .padding(.top, ReffiSpace.s3)
                .padding(.bottom, navClearance)
                .disabled(counter.isEmpty)
                .opacity(counter.isEmpty ? 0.5 : 1)
        }
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: store.activeCook)
        .background {
            ZStack {
                LiquidGlassBackground(accent: topF.main, accentDeep: topF.dark)
                // 긴급도 연출(F) — 오늘 만료가 있으면 상단에 옅은 웜톤 시노.
                if urgentCount > 0 {
                    LinearGradient(colors: [ReffiColor.urgent.opacity(0.14), .clear],
                                   startPoint: .top, endPoint: .center)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .animation(ReffiMotion.gated(.easeInOut(duration: 0.5), reduce: reduceMotion), value: topF)
            .animation(ReffiMotion.gated(.easeInOut(duration: 0.5), reduce: reduceMotion), value: urgentCount > 0)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: fireHaptic)
        .sensoryFeedback(.impact(weight: .light), trigger: decisionHaptic)
        .fullScreenCover(isPresented: $showCarousel, onDismiss: {
            // 발주로 닫혔으면 곧장 단계별 레시피로 — "Cook this"의 다음 화면은 조리다.
            if firedTicket, store.activeCook != nil { showSteps = true }
        }) {
            RecipeMemoCarousel(results: carouselSnapshot,
                               hasIngredients: !store.ingredients.isEmpty,
                               onClose: { showCarousel = false },
                               onFire: fire)
        }
        .fullScreenCover(isPresented: $showSteps) {
            CookingStepsView(onClose: { showSteps = false })
        }
        // 판정은 투명 풀스크린 커버 — 하단 네비까지 덮어 모달리티가 깨지지 않는다.
        .fullScreenCover(item: $deciding) { ing in
            DecisionCover(ingredient: ing,
                          reduceMotion: reduceMotion,
                          onCommit: { ate in commit(ing, ate: ate) },
                          onFreeze: { commitFreeze(ing) },
                          onCancel: { closeDecision() })
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet().presentationDetents([.medium, .large])
        }
        // 자정 경과 — D-day·신선도 파생 UI와 씬 라벨 점을 다시 계산한다.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayTick += 1
            scene.sync(counter)
        }
        #if DEBUG
        .onAppear {   // 미리보기/검증용: `-loadSample`로 샘플 시드, `-previewCarousel 1`로 캐러셀 바로 열기.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-loadSample"), store.isPristine {
                store.loadSampleData()
            }
            if args.contains("-previewCarousel") {
                carouselSnapshot = carouselResults
                showCarousel = true
            }
        }
        #endif
    }

    @State private var dayTick = 0   // 자정 리렌더 트리거

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s1) {
            HStack(alignment: .center) {
                Text(verbatim: "Reffi").reffiType(.display).foregroundStyle(ReffiColor.ink)
                Spacer()
                // 날짜는 분 단위 타임라인으로 갱신 — 자정이 지나도 어제 날짜가 남지 않는다.
                TimelineView(.everyMinute) { ctx in
                    Text(ctx.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.reffiNum(13, relativeTo: .caption)).foregroundStyle(ReffiColor.ink2)
                }
            }
            // 미션 헤더(D) — 오늘의 상태를 한 문장으로. 누계(Ate/Tossed)는 MyPage가 맡는다.
            missionText
                .reffiType(.caption)
                .foregroundStyle(urgentCount > 0 ? ReffiColor.urgentDark : ReffiColor.ink2)
        }
    }

    private var missionText: Text {
        if counter.isEmpty { return Text("Fill the counter, then cook") }
        if urgentCount > 0 { return Text("\(urgentCount) at risk today — cook one?") }
        if soonCount > 0 { return Text("\(soonCount) to eat soon — plan tonight?") }
        return Text("All fresh — get ahead of it.")
    }

    // MARK: - 알림 유도 배너 (프리퍼미션)

    /// 임박 재료가 있고 알림이 꺼져 있고 아직 제안 안 했을 때 한 번만.
    private var showAlertPrompt: Bool {
        !alertsEnabled && !alertPromptSeen && (urgentCount + soonCount) > 0
    }

    /// 미니 영수증 스트립(Cooking now와 같은 자리·같은 언어) — 켜기 / 나중에.
    private var alertPromptCard: some View {
        HStack(spacing: ReffiSpace.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "MORNING ALERTS")
                    .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2))
                    .tracking(1.6).foregroundStyle(ReffiColor.blueDark)
                Text("Know before food turns")
                    .font(.custom("Pretendard-Bold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(ReffiColor.ink).lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: ReffiSpace.s2)
            Button { enableAlerts() } label: {
                Text("Turn on")
                    .font(.custom("Pretendard-SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, ReffiSpace.s3 + 2)
                    .padding(.vertical, ReffiSpace.s1 + 2)
                    .background(ReffiColor.blue, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
            Button { withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { alertPromptSeen = true } } label: {
                Text("Later")
                    .font(.custom("Pretendard-SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
        }
        .padding(.horizontal, ReffiSpace.s4)
        .padding(.vertical, ReffiSpace.s1)
        .frame(minHeight: 44)
        .background {
            let shape = ReceiptShape(tooth: 6)
            shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadow1()
    }

    /// 켜기 — 시스템 권한 요청 후 성공 시 즉시 스케줄. 거부해도 다시 조르지 않는다(seen 처리).
    private func enableAlerts() {
        Task {
            let granted = await ExpiryNotifier.requestAuthorization()
            withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                alertPromptSeen = true
                if granted {
                    alertsEnabled = true
                    ExpiryNotifier.reschedule(for: store.ingredients)
                }
            }
        }
    }

    // MARK: - Cooking now (발주 진행 카드)

    /// 발주 후 "지금 요리 중" — 미니 영수증 스트립. 탭하면 단계별 레시피로 복귀(완료는 그 화면에서).
    private func cookingNowCard(_ cook: FridgeStore.CookSession) -> some View {
        Button { showSteps = true } label: {
            HStack(spacing: ReffiSpace.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "COOKING NOW")
                        .font(.custom("Pretendard-Bold", size: 10, relativeTo: .caption2))
                        .tracking(1.6).foregroundStyle(ReffiColor.blueDark)
                    HStack(spacing: 6) {
                        Text(verbatim: cook.recipeName)
                            .font(.custom("Pretendard-Bold", size: 15, relativeTo: .subheadline))
                            .foregroundStyle(ReffiColor.ink).lineLimit(1)
                        Text(cook.startedAt, style: .relative)
                            .font(.custom("Pretendard-Medium", size: 11, relativeTo: .caption2))
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
                Spacer(minLength: ReffiSpace.s2)
                ReffiIcon.chevron.reffi(15, .bold).foregroundStyle(ReffiColor.blueDark)
            }
            .padding(.horizontal, ReffiSpace.s4)
            .padding(.vertical, ReffiSpace.s2 + 2)
            .frame(minHeight: 44)
            .background {
                let shape = ReceiptShape(tooth: 6)
                shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
            }
            .reffiShadow1()
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Continue cooking \(cook.recipeName)"))
    }

    // MARK: - Physics field (real engine, persistent pile)

    private var physicsField: some View {
        GeometryReader { geo in
            ZStack {
                // 주의: SpriteView(isPaused:)로 SKView를 멈추면 첫 프레임이 안 그려져 회색이 될 수 있다.
                // 씬 레벨 pause(scene.isPaused)로 물리만 멈추고 렌더(투명 배경)는 유지한다.
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .onAppear { configureScene(size: geo.size) }
                    .onChange(of: geo.size) { _, s in scene.size = s }
                    .onChange(of: sceneSyncKey) { _, _ in scene.sync(counter) }
                    .onChange(of: reduceMotion) { _, v in scene.reduceMotion = v }
                    .onChange(of: scenePaused) { _, p in scene.isPaused = p }
                if counter.isEmpty { emptyField }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func configureScene(size: CGSize) {
        scene.scaleMode = .resizeFill
        scene.size = size
        scene.reduceMotion = reduceMotion
        scene.onRemove = { id in decide(id) }
        scene.onDecide = { id, wasted in gestureDecide(id, wasted: wasted) }
        scene.isPaused = scenePaused
        scene.sync(counter)
    }

    /// 제스처 판정(§13.6 B) — 존에 끌어다 놓으면 오버레이 없이 바로 확정. undo 토스트가 안전망.
    private func gestureDecide(_ id: UUID, wasted: Bool) {
        guard let ing = counter.first(where: { $0.id == id }) else { return }
        decisionHaptic += 1
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            if wasted { store.toss(ing) } else { store.eat(ing) }
        }
    }

    /// 빈 작업대 — 첫 실행(데이터 전무)이면 온보딩 카피 + 샘플 CTA, 아니면 추가 유도.
    private var emptyField: some View {
        VStack(spacing: ReffiSpace.s4) {
            ReffiIcon.fridge.reffi(40).foregroundStyle(ReffiColor.muted)
            if store.isPristine {
                VStack(spacing: ReffiSpace.s1) {
                    Text("What's in your fridge?").reffiType(.subhead).foregroundStyle(ReffiColor.ink)
                    Text("Add a few ingredients — Reffi tells you\nwhat to cook before they turn.")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Nothing to use yet").reffiType(.subhead).foregroundStyle(ReffiColor.ink2)
            }
            AddBadge { showAdd = true }
            if store.isPristine {
                Button {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        store.loadSampleData()
                    }
                } label: {
                    Text("Or try a sample fridge")
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.blue)
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.reffiPress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Badge scroll (persistent)

    /// 뱃지 행 — 긴급도순 가로 스크롤(가장 임박이 맨 앞). 끝에 ＋추가.
    /// (신선도 점 행은 뱃지의 인디케이터 바·D-N과 중복이라 제거 — §13.6 E)
    private var badgeScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReffiSpace.s2) {
                ForEach(Array(counter.enumerated()), id: \.element.id) { i, ing in
                    IngredientBadge(ingredient: ing, seed: i) { decide(ing.id) }
                        .transition(.scale(scale: 1.3, anchor: .center).combined(with: .opacity))   // 뿅 사라짐
                }
                AddBadge(seed: counter.count) { showAdd = true }
            }
            .padding(.horizontal, margin)
            .padding(.vertical, ReffiSpace.s1)   // 그림자 여유
        }
        .animation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion), value: counter.map(\.id))
    }

    // MARK: - Ate / Tossed decision

    /// 재료 탭 → "먹었나 버렸나" 묻기. 커버 자체의 슬라이드 애니메이션은 끄고 카드가 pop-in 한다.
    private func decide(_ id: UUID) {
        guard let ing = counter.first(where: { $0.id == id }) else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { deciding = ing }
    }

    private func closeDecision() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { deciding = nil }
    }

    /// 선택 확정 → store에서 제거(실루엣·뱃지 뿅 사라짐) + 이력 기록 + 되돌리기 창(토스트는 탭 공통).
    private func commit(_ ing: Ingredient, ate: Bool) {
        decisionHaptic += 1
        closeDecision()
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            if ate { store.eat(ing) } else { store.toss(ing) }
        }
    }

    /// 냉동(버리기 직전 구제) — 유예 14일의 새 시계를 받고 작업대에서 빠진다(유예 임박에 재등장).
    private func commitFreeze(_ ing: Ingredient) {
        decisionHaptic += 1
        closeDecision()
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.freeze(ing)
        }
    }

    // MARK: - Cook / Fire the Ticket

    private func cook() {
        guard !counter.isEmpty else { return }
        carouselSnapshot = carouselResults   // 발주로 store가 바뀌어도 커버 입력은 고정(재랭크 방지)
        firedTicket = false
        coverGeneration += 1                 // 이전 발주의 지연 닫기 타이머 무효화
        showCarousel = true
    }

    /// 티켓 발주(Fire the Ticket) — used 재료를 이 레시피로 전량 소비 처리 → 슬램 본 뒤 커버 닫기.
    /// 되돌리기 토스트는 store의 통합 undo가 띄운다. 커버당 1회만(더블 파이어 방지).
    private func fire(_ result: RecipeRecommender.Result) {
        guard !firedTicket, !result.used.isEmpty else { return }
        firedTicket = true
        fireHaptic += 1
        withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
            store.cook(result)
        }
        let gen = coverGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            if coverGeneration == gen { showCarousel = false }   // 새로 연 커버는 닫지 않는다
        }
    }
}

/// Ate/Tossed 결정 — 투명 풀스크린 커버 위 딤 + 종이 카드 + 종이컷 아이콘 버튼 쌍 + 명시적 취소.
/// **오늘 만료(urgent)이고 아직 얼린 적 없는 재료**엔 3번째 선택지 Freeze가 나타난다(§13.6) —
/// 미리 얼려두기가 아니라 버리기 직전의 구제로만. 커버라서 하단 네비까지 덮인다(모달리티).
private struct DecisionCover: View {
    let ingredient: Ingredient
    let reduceMotion: Bool
    var onCommit: (Bool) -> Void
    var onFreeze: () -> Void = {}
    var onCancel: () -> Void

    @State private var shown = false

    /// Freeze 노출 조건 — 오늘 만료(urgent) + 재냉동 아님(1회 제한). '미루기 버튼' 방지.
    private var showFreeze: Bool { ingredient.freshness == .urgent && ingredient.canFreeze }

    var body: some View {
        ZStack {
            ReffiColor.scrim.ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)
            card
                .scaleEffect(shown ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
        }
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                withAnimation(ReffiMotion.pop) { shown = true }
            }
        }
        .accessibilityAction(.escape) { onCancel() }
    }

    private var card: some View {
        VStack(spacing: ReffiSpace.s5) {
            VStack(spacing: 2) {
                Text(verbatim: ingredient.name).reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Text("Did you eat it, or toss it?")
                    .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            }
            HStack(spacing: showFreeze ? ReffiSpace.s4 : ReffiSpace.s6) {
                PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) { onCommit(false) }
                if showFreeze {
                    PaperIconButton(icon: ReffiIcon.freeze, label: "Freeze", intent: .neutral, seed: 2) { onFreeze() }
                }
                PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) { onCommit(true) }
            }
            Button { onCancel() } label: {
                Text("Keep it")
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.reffiPress)
        }
        .padding(.horizontal, ReffiSpace.s6)
        .padding(.top, ReffiSpace.s6)
        .padding(.bottom, ReffiSpace.s3)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xl)
            shape.fill(ReffiColor.canvas).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadow1()
        .padding(.horizontal, ReffiSpace.s7)
    }
}
