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
        .onAppear { order = Array(allResults.indices) }
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
        ZStack {
            ForEach(Array(deck.enumerated().reversed()), id: \.element) { position, idx in
                ticketCard(idx: idx, depth: position, cardHeight: cardHeight, topInset: topInset)
            }
        }
        .accessibilityAction(named: Text("Next ticket")) { advance() }
    }

    @ViewBuilder private func ticketCard(idx: Int, depth: Int, cardHeight: CGFloat, topInset: CGFloat) -> some View {
        let isFront = depth == 0
        // 가장 깊은 티켓(depth ≥ 2)만 headerOnly 경량 렌더 — 바로 뒤(depth 1)는 풀 렌더라
        // 플릭 승격(1→0)이 내용 변화 없이 매끄럽다(ScrollView 상태·래스터 유지, 번쩍임 없음).
        // 전환 진입 성능은 '무거운 카드 3→2장'으로 이득 대부분 유지(§13.6).
        OrderMemoCard(result: allResults[idx], number: idx + 1, headerOnly: depth >= 2) { fire(allResults[idx]) }
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
            .gesture(isFront && deck.count > 1 && !fired ? flick : nil)
    }

    /// 플릭 — 손을 따라오다(살짝 기울며) 임계 넘게 튕기면 뒤로 넘어간다. 못 미치면 제자리로.
    /// onChanged는 수평 우세(|Δx| > |Δy|·1.4)일 때만 따라와, 카드 내부 세로 스크롤과의 경합을 완화한다.
    private var flick: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if abs(v.translation.width) > abs(v.translation.height) * 1.4 {
                    dragOffset = v.translation
                }
            }
            .onEnded { v in
                let p = v.predictedEndTranslation
                if abs(p.width) > 160 || abs(p.height) > 220 {
                    flickAway(toward: p)
                } else {
                    withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) {
                        dragOffset = .zero
                    }
                }
            }
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

    /// 맨 앞 티켓을 덱 뒤로 — 다음 티켓이 스프링으로 올라온다.
    private func advance() {
        guard deck.count > 1, !fired else { return }
        var d = deck
        d.append(d.removeFirst())
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { dragOffset = .zero }
        withAnimation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion)) { order = d }
    }

    private func fire(_ result: RecipeRecommender.Result) {
        fired = true   // 덱 잠금 — 슬램이 보이는 동안 플릭 방지
        onFire(result)
    }

    // MARK: - 상단 바

    private var topBar: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today's tickets").reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    Text("Flick a ticket for the next, ranked by what spoils first")
                        .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                }
                Spacer()
                Button(action: onClose) {
                    ReffiIcon.close.reffi(18, .bold)
                        .foregroundStyle(ReffiColor.ink)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.9), in: PaperRect(cornerRadius: ReffiRadius.md, seed: 1))
                        .paperEdge(PaperRect(cornerRadius: ReffiRadius.md, seed: 1), tint: ReffiColor.ink.opacity(0.08))
                        .reffiShadow1()
                        .frame(minWidth: 44, minHeight: 44)   // §7.3 — 시각은 40, 히트는 44
                        .contentShape(Rectangle())
                }
                .buttonStyle(.paperPress)
                .accessibilityLabel(Text("Close"))
            }
            // 생성 진행 힌트(§13.6) — 덱 하단(=이 상단 바 아래)에 조용히. 도착·실패 모두 사라진다(실패 문구 없음).
            if aiGenerating {
                AIGeneratingHint(reduceMotion: reduceMotion)
                    .transition(.opacity)
            }
        }
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: aiGenerating)
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s4)
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
