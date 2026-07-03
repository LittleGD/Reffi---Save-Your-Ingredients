import SwiftUI
import PhosphorSwift

/// 레시피 추천 티켓 덱(§13) — 풀스크린, **네비 없음**. 주방 오더 티켓이 **실제로 겹쳐 쌓인 덱**:
/// 뒤에 보이는 종이가 장식이 아니라 다음 티켓이다. 맨 앞 티켓을 **튕겨 넘기면**(플릭) 뒤로 들어가고
/// 다음 티켓이 앞으로 올라온다(순환). "이걸로 요리"로 발주(Fire the Ticket), 닫기 X로 메인 복귀.
struct RecipeMemoCarousel: View {
    let results: [RecipeRecommender.Result]
    /// 재고가 있는데 매칭 레시피가 0인 경우와 재고 자체가 없는 경우를 구분(빈 상태 카피).
    var hasIngredients: Bool = false
    var onClose: () -> Void
    var onFire: (RecipeRecommender.Result) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var order: [Int] = []          // 덱 순서 — [0]이 맨 앞
    @State private var dragOffset: CGSize = .zero
    @State private var fired = false              // 발주 후 덱 잠금(슬램 유지)

    private let topInset: CGFloat = 124   // 뒤 티켓이 위로 살짝 머리를 내밀 공간 포함
    private let botInset: CGFloat = 86

    private var deck: [Int] { order.isEmpty ? Array(results.indices) : order }

    var body: some View {
        ZStack(alignment: .top) {
            ReffiColor.paperPass.ignoresSafeArea()
            if results.isEmpty { emptyState } else { ticketDeck }
            topBar
        }
        .onAppear { order = Array(results.indices) }
    }

    // MARK: - 티켓 덱 (뒤 종이 = 실제 다음 티켓)

    private var ticketDeck: some View {
        ZStack {
            ForEach(Array(deck.enumerated().reversed()), id: \.element) { position, idx in
                ticketCard(idx: idx, depth: position)
            }
        }
        .accessibilityAction(named: Text("Next ticket")) { advance() }
    }

    @ViewBuilder private func ticketCard(idx: Int, depth: Int) -> some View {
        let isFront = depth == 0
        OrderMemoCard(result: results[idx], number: idx + 1) { fire(results[idx]) }
            .padding(.horizontal, ReffiGrid.margin + 8)
            .padding(.top, topInset)
            .padding(.bottom, botInset)
            .scaleEffect(isFront ? 1 : 1 - CGFloat(depth) * 0.035, anchor: .top)
            .offset(y: isFront ? 0 : CGFloat(depth) * -14)   // 뒤 티켓이 위로 머리를 내민다
            .rotationEffect(.degrees(isFront ? Double(dragOffset.width / 22)
                                             : (idx % 2 == 0 ? -2.2 : 2.4)),
                            anchor: .top)
            .offset(isFront ? dragOffset : .zero)
            .shadow(color: ReffiColor.ink.opacity(isFront ? 0.10 : 0.04),
                    radius: isFront ? 14 : 6, x: 0, y: isFront ? 8 : 3)
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
            .zIndex(Double(deck.count - depth))
            .gesture(isFront && deck.count > 1 && !fired ? flick : nil)
    }

    /// 플릭 — 손을 따라오다(살짝 기울며) 임계 넘게 튕기면 뒤로 넘어간다. 못 미치면 제자리로.
    private var flick: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in dragOffset = v.translation }
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Today's tickets").reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Text("Flick a ticket for the next — ranked by what spoils first")
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
