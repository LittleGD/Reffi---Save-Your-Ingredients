import SwiftUI
import PhosphorSwift

/// 레시피 추천 티켓 덱(§13) — 풀스크린, **네비 없음**. 주방 오더 티켓이 **실제로 겹쳐 쌓인 덱**:
/// 뒤에 보이는 종이가 장식이 아니라 다음 티켓이다. 맨 앞 티켓을 **튕겨 넘기면**(플릭) 뒤로 들어가고
/// 다음 티켓이 앞으로 올라온다(순환). "이걸로 요리"로 발주(Fire the Ticket), 닫기 X로 메인 복귀.
struct RecipeMemoCarousel: View {
    let results: [RecipeRecommender.Result]
    /// 재고가 있는데 매칭 레시피가 0인 경우와 재고 자체가 없는 경우를 구분(빈 상태 카피).
    var hasIngredients: Bool = false
    /// AI 생성 진행 중 — store에 진행 상태가 없어 호출부(MainView)가 Task 시작/종료를 관찰해 넘긴다.
    /// 덱 하단에 조용한 힌트만 띄우고, 도착·실패 모두 이 값이 false가 되며 조용히 사라진다(실패 문구 없음).
    var aiGenerating: Bool = false
    var onClose: () -> Void
    var onFire: (RecipeRecommender.Result) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @State private var order: [Int] = []          // 덱 순서 — [0]이 맨 앞
    @State private var dragOffset: CGSize = .zero
    @State private var fired = false              // 발주 후 덱 잠금(슬램 유지)
    /// 앞 티켓 상세 펼침 — 기본은 축약(아이콘+메뉴명). 상태를 덱이 소유해야 플릭으로 티켓이 바뀔 때
    /// 다시 축약부터 시작할 수 있다(§13.6).
    @State private var expanded = false
    /// 진행 중인 드래그가 잡은 축 — 제스처당 **한 번만** 정하고 끝날 때까지 고정한다(`frontDrag` 참고).
    /// nil = 아직 우세 축이 갈리지 않음(= 아무 것도 커밋하지 않는다).
    @State private var dragAxis: Axis?

    /// 커밋 임계(예측 변위) — 이 이상 튕기면 그 방향으로 확정, 못 미치면 현 상태를 유지한다.
    /// 플릭(160/220)보다 훨씬 가볍다 — 펼침/접힘은 파괴적이지 않은 정보성 전환이라 되돌리기가 싸다.
    private let expandCommit: CGFloat = 56
    /// 캐러셀이 열려 있는 동안 도착한 AI 티켓(최대 2장) — 초기 `results` 스냅샷은 불변으로 두고
    /// 여기만 늘려 덱 순서 배열을 **확장**한다(단일 정체성 규칙 — 기존 카드 재구성 금지).
    @State private var appended: [RecipeRecommender.Result] = []

    /// 표시용 전체 결과 — 초기 스냅샷(고정 인덱스 0..<results.count) + 도착분(뒤에 이어붙임).
    private var allResults: [RecipeRecommender.Result] { results + appended }
    private var deck: [Int] { order.isEmpty ? Array(allResults.indices) : order }

    var body: some View {
        GeometryReader { geo in
            // 카드 높이 캡(근본) — 카드가 컨테이너를 절대 넘지 못하게 safe area에 연동해 예산을 뺀다.
            // topInset = safe top + 헤더 예산(~72) + 뒤티켓 peek(28), botInset = safe bottom + 12.
            // 기존 124/86과 유사한 시각을 유지하되 기기별 노치·홈 인디케이터에 안전하다.
            let topInset = geo.safeAreaInsets.top + 72 + 28
            let botInset = geo.safeAreaInsets.bottom + 12
            let cardHeight = max(0, geo.size.height - topInset - botInset)
            ZStack(alignment: .top) {
                ReffiColor.paperPass.ignoresSafeArea()
                if allResults.isEmpty { emptyState } else { ticketDeck(cardHeight: cardHeight, topInset: topInset) }
                topBar
            }
        }
        .onAppear {
            order = Array(allResults.indices)
            #if DEBUG
            // `-cookCarousel.expanded` — 앞 티켓을 펼친 상태로 띄운다(스크린샷 QA · `-fridgeExpand` 선례).
            if ProcessInfo.processInfo.arguments.contains("-cookCarousel.expanded") { expanded = true }
            #endif
        }
        // AI 캐시가 바뀔 때마다(다른 세션 발주로도 바뀔 수 있음) 현재 재고 기준으로 다시 랭크해
        // 아직 덱에 없는 것만, 최대 2장 부드럽게 합류시킨다. fired(슬램 중)면 덱을 잠근다.
        .onChange(of: store.aiRecipes) { _, incoming in syncAIArrivals(incoming) }
    }

    /// AI 캐시 도착분 합류 — 현재 재고로 다시 랭크해 아직 덱에 없는 것만, 최대 2장까지 뒤에 이어붙인다.
    /// `results`는 절대 건드리지 않고 `appended`만 늘려 `order`를 확장한다(기존 카드 재구성 없음).
    private func syncAIArrivals(_ incoming: [Recipe]) {
        guard !fired, appended.count < 2, !incoming.isEmpty else { return }
        let existingIDs = Set(allResults.map(\.id))
        let ranked = RecipeRecommender.rank(for: store.available, from: incoming,
                                            preferences: RecipePreferences(profile: profile))
            .filter { !existingIDs.contains($0.id) }
        guard !ranked.isEmpty else { return }
        let room = 2 - appended.count
        let fresh = Array(ranked.prefix(room))
        guard !fresh.isEmpty else { return }
        let startIdx = allResults.count
        appended.append(contentsOf: fresh)
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
            order.append(contentsOf: startIdx..<(startIdx + fresh.count))
        }
    }

    // MARK: - 티켓 덱 (뒤 종이 = 실제 다음 티켓)

    private func ticketDeck(cardHeight: CGFloat, topInset: CGFloat) -> some View {
        // 카드 크기는 축약·펼침 두 상태가 같다 — 바뀌는 건 콘텐츠뿐이라 톱니 밑단이 제자리에 있고
        // 덱(겹쳐 쌓인 뒤 티켓들)의 기하가 전환 중에 흔들리지 않는다.
        ZStack {
            ForEach(Array(deck.enumerated().reversed()), id: \.element) { position, idx in
                ticketCard(idx: idx, depth: position, cardHeight: cardHeight, topInset: topInset)
            }
        }
        .accessibilityAction(named: Text("Next ticket")) { advance() }
        // 축약↔펼침 커스텀 액션은 두지 않는다 — 축약 본문 자체가 활성화 버튼이고 펼친 헤더엔
        // 접기 버튼(caret-down)이 있어, 커스텀 액션을 겹치면 같은 동작이 두 경로로 노출된다.
    }

    @ViewBuilder private func ticketCard(idx: Int, depth: Int, cardHeight: CGFloat, topInset: CGFloat) -> some View {
        let isFront = depth == 0
        // 가장 깊은 티켓(depth ≥ 2)만 headerOnly 경량 렌더 — 전환 진입 성능을 지킨다(§13.6).
        // 상세(expanded)는 **앞 티켓만** — 바로 뒤(depth 1)는 앞 티켓과 같은 축약 본문을 그리므로
        // 플릭 승격(1→0)이 내용 변화 없이 매끄럽고(번쩍임 없음), 상세 문구도 화면에 한 벌만 존재한다.
        OrderMemoCard(result: allResults[idx],
                      number: idx + 1,
                      headerOnly: depth >= 2,
                      expanded: isFront && expanded,
                      onFire: { fire(allResults[idx]) },
                      onToggleDetails: { toggleDetails() })
            .frame(height: cardHeight)   // 카드가 컨테이너를 넘지 못하게 캡(headerOnly도 동일 캡)
            .padding(.horizontal, ReffiGrid.margin + 8)
            .padding(.top, topInset)
            .scaleEffect(isFront ? 1 : 1 - CGFloat(depth) * 0.035, anchor: .top)
            .offset(y: isFront ? 0 : CGFloat(depth) * -14)   // 뒤 티켓이 위로 머리를 내민다
            .rotationEffect(.degrees(isFront ? Double(dragOffset.width / 22)
                                             : (idx % 2 == 0 ? -2.2 : 2.4)),
                            anchor: .top)
            .offset(isFront ? dragOffset : .zero)
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
            .zIndex(Double(deck.count - depth))
            .gesture(isFront && !fired ? frontDrag : nil)
    }

    /// 앞 티켓 드래그 — 카드 위 드래그를 중재하는 **유일한 지점**이다(카드는 탭만 받는다).
    /// 한 제스처에서 우세 축을 **한 번만** 판별해 고정한다: 수평(|Δx| > |Δy|·1.4) = 다음 티켓 플릭,
    /// 수직(|Δy| > |Δx|·1.4) = 축약↔펼침. 매 이벤트 재판정하면 곡선 드래그에서 분기가 바뀌며
    /// 직전 분기가 남긴 상태(`dragOffset`)가 스테일로 굳는다 — 축을 잠가 그 창을 없앤다.
    ///
    /// 수직은 **라이브 추종이 없다** — 카드 크기가 상태와 무관하게 고정이라 따라 움직일 값 자체가 없고,
    /// 그래서 놓을 때만 임계로 커밋한다. 축이 갈리지 않은 애매한 구간(대략 35.5°~54.5°)은 끝까지
    /// nil로 남아 **아무 것도 커밋하지 않는다** — 추종 피드백 없이 상태가 뒤집히는 걸 막는다.
    /// 펼친 뒤 본문(ScrollView) 위 세로 드래그는 자식 스크롤이 가져가므로 여기 오지 않는다.
    private var frontDrag: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if dragAxis == nil {
                    let dx = abs(v.translation.width), dy = abs(v.translation.height)
                    if dx > dy * 1.4 { dragAxis = .horizontal }
                    else if dy > dx * 1.4 { dragAxis = .vertical }
                    else { return }   // 아직 갈리지 않았다 — 다음 이벤트에서 다시 본다
                }
                // 수직은 손가락을 따라 바꿀 상태가 없다(크기 불변) — 커밋은 onEnded에서만.
                guard dragAxis == .horizontal, deck.count > 1 else { return }
                dragOffset = v.translation
            }
            .onEnded { v in
                let p = v.predictedEndTranslation
                let axis = dragAxis
                dragAxis = nil   // 어느 경로로 끝나든 축은 여기서 반드시 푼다
                switch axis {
                case .horizontal:
                    // 플릭이 성립하면 flickAway가 dragOffset을 이어받아 날려보낸다(advance가 0으로 되돌림).
                    if deck.count > 1, abs(p.width) > 160 || abs(p.height) > 220 {
                        flickAway(toward: p)
                    } else {
                        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                            dragOffset = .zero
                        }
                    }
                case .vertical:
                    settleDetails(predicted: p.height)
                case .none:
                    break   // 애매 구간 — 커밋 없음(dragOffset도 애초에 건드리지 않았다)
                }
            }
    }

    /// 축약↔펼침 토글(탭·접근성 활성화). 발주 중(슬램)엔 잠근다.
    private func toggleDetails() {
        guard !fired else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { expanded.toggle() }
    }

    /// 수직 드래그 마무리 — 예측 변위가 임계를 넘고 **방향이 현 상태와 반대일 때만** 커밋한다:
    /// 축약 상태에서 위로(−) 튕기면 펼침, 펼친 상태에서 아래로(+) 튕기면 접힘.
    /// 임계 미달이면 아무 것도 하지 않는다 — 드래그 중 라이브 추종이 없어 되돌릴 중간 상태가 없고,
    /// "임계를 못 넘긴 드래그는 현상 유지"가 그대로 성립한다. 정보성 전환이라 햅틱은 없다(§7.6).
    private func settleDetails(predicted: CGFloat) {
        guard !fired else { return }
        let target: Bool
        if !expanded, predicted < -expandCommit { target = true }
        else if expanded, predicted > expandCommit { target = false }
        else { return }
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { expanded = target }
    }

    private func flickAway(toward p: CGSize) {
        guard deck.count > 1 else { return }
        if reduceMotion {
            advance()
            return
        }
        let mag = max(1, hypot(p.width, p.height))
        let target = CGSize(width: p.width / mag * 640, height: p.height / mag * 640)
        withAnimation(.easeOut(duration: 0.2)) { dragOffset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { advance() }
    }

    /// 맨 앞 티켓을 덱 뒤로 — 다음 티켓이 스프링으로 올라온다. 새 앞 티켓은 **다시 축약부터**(§13.6).
    private func advance() {
        guard deck.count > 1, !fired else { return }
        var d = deck
        d.append(d.removeFirst())
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { dragOffset = .zero }
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
            order = d
            expanded = false
        }
    }

    private func fire(_ result: RecipeRecommender.Result) {
        fired = true   // 덱 잠금 — 슬램이 보이는 동안 플릭 방지
        onFire(result)
    }

    // MARK: - 상단 바

    /// 커버 헤더 — 단일 공급원 `CoverHeader`(§14.2: 풀스크린 커버 = 중앙 타이틀 + 종이 X).
    private var topBar: some View {
        CoverHeader(title: "Today's tickets",
                    subtitle: "Flick a ticket for the next, ranked by what spoils first",
                    onClose: onClose) {
            // 생성 진행 힌트(§13.6) — 덱 하단(=이 상단 바 아래)에 조용히. 도착·실패 모두 사라진다(실패 문구 없음).
            if aiGenerating {
                AIGeneratingHint(reduceMotion: reduceMotion)
                    .transition(.opacity)
            }
        }
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: aiGenerating)
    }

    /// 빈 덱 — 원인 기반 안내: 재료가 있는데 매칭 0이면 이름 확인·커스텀 레시피를 유도한다.
    private var emptyState: some View {
        VStack(spacing: ReffiSpace.s4) {
            FoodMotif(glyph: .generic).frame(width: 110, height: 110)
            Text("No tickets yet").reffiType(.heading).foregroundStyle(ReffiColor.ink)
            if hasIngredients {
                Text("No recipes match these ingredients yet.\nCheck their names, or add your own recipe in Profile.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
            } else {
                Text("Keep a few ingredients on, then start cooking.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
            }
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// AI 생성 진행 힌트 — sparkle + 숨쉬는 점 3개. 부모가 `aiGenerating`로 표시/은닉을 통째로 게이팅하므로
/// 여기엔 실패 상태가 없다(도착·실패 모두 부모 쪽에서 조용히 사라짐).
private struct AIGeneratingHint: View {
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: ReffiSpace.s1) {
            ReffiIcon.ai.reffi(12).foregroundStyle(ReffiColor.blueDark)
            Text("Cooking up an AI ticket…")
                .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(ReffiColor.blueDark)
                        .frame(width: 3, height: 3)
                        .opacity(reduceMotion ? 0.6 : (pulse ? 1 : 0.25))
                        .animation(reduceMotion ? nil :
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                            value: pulse)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Generating an AI recipe"))
        .onAppear { if !reduceMotion { pulse = true } }
    }
}
