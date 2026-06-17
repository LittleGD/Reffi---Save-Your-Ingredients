import SwiftUI
import PhosphorSwift

/// 메인 — 보유 재료로 만들 수 있는 레시피를 틴더/범블식 좌우 스와이프 덱으로.
/// 우 = 선호(담음) · 좌 = 넘기기 · 탭 = 상세. 정렬은 마감 임박 가중(위 = 먼저 먹을 것).
struct SwipeDeckView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var history: [Int] = []
    @State private var detail: RecipeRecommender.Result?

    private let threshold: CGFloat = 110
    private let cardWhite = ReffiColor.oklch(0.99, 0.006, 90)

    var body: some View {
        let results = store.rankedRecipes
        VStack(spacing: ReffiSpace.s4) {
            header(total: results.count)

            ZStack {
                if index >= results.count {
                    EmptyDeckView { reset() }
                } else {
                    ForEach(visibleIndices(results.count), id: \.self) { i in
                        card(results[i], i: i)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if index < results.count {
                actionRow(results)
            }

            Spacer().frame(height: 84)   // 떠 있는 캡슐 네비 여유
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s2)
        .sheet(item: $detail) { RecipeDetailSheet(result: $0) }
    }

    // MARK: Cards

    private func visibleIndices(_ count: Int) -> [Int] {
        let upper = min(index + 2, count - 1)
        return Array(index...upper).reversed()   // 뒤 카드를 먼저(아래에) 그림
    }

    @ViewBuilder
    private func card(_ result: RecipeRecommender.Result, i: Int) -> some View {
        let depth = i - index
        let isTop = depth == 0
        SwipeCardView(result: result, drag: isTop ? drag : .zero, isTop: isTop)
            .scaleEffect(isTop ? 1 : 1 - CGFloat(depth) * 0.04)
            .offset(y: isTop ? 0 : CGFloat(depth) * 14)
            .offset(isTop ? drag : .zero)
            .rotationEffect(.degrees(isTop && !reduceMotion ? Double(drag.width) / 16 : 0))
            .zIndex(Double(100 - depth))
            .allowsHitTesting(isTop)
            .gesture(isTop ? dragGesture() : nil)
            .onTapGesture { if isTop { detail = result } }
            .animation(reduceMotion ? nil : ReffiMotion.standard, value: index)
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > threshold {
                    swipe(right: value.translation.width > 0)
                } else {
                    withAnimation(ReffiMotion.standard) { drag = .zero }
                }
            }
    }

    // MARK: Actions

    private func swipe(right: Bool) {
        if reduceMotion {
            advance()
            return
        }
        let dir: CGFloat = right ? 1 : -1
        withAnimation(ReffiMotion.exit) {
            drag = CGSize(width: dir * 800, height: drag.height + 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ReffiMotion.dur1) { advance() }
    }

    private func advance() {
        history.append(index)
        drag = .zero
        index += 1
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        index = last
        drag = CGSize(width: -600, height: 0)
        withAnimation(reduceMotion ? nil : ReffiMotion.enter) { drag = .zero }
    }

    private func reset() {
        withAnimation(ReffiMotion.standard) {
            index = 0; history = []; drag = .zero
        }
    }

    // MARK: Pieces

    private func header(total: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Reffi")
                .reffiType(.display)
                .foregroundStyle(ReffiColor.ink)
            Spacer()
            if index < total {
                Text("\(index + 1) / \(total)")
                    .font(.reffiNum(14, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink2)
            }
        }
    }

    private func actionRow(_ results: [RecipeRecommender.Result]) -> some View {
        HStack(spacing: ReffiSpace.s6) {
            circleButton(ReffiIcon.close, fg: ReffiColor.ink2, bg: cardWhite) {
                swipe(right: false)
            }
            circleButton(ReffiIcon.undo, fg: ReffiColor.muted, bg: cardWhite, size: 46) {
                undo()
            }
            .opacity(history.isEmpty ? 0.4 : 1)
            .disabled(history.isEmpty)
            circleButton(ReffiIcon.go, fg: .white, bg: ReffiColor.blue) {
                swipe(right: true)
            }
        }
    }

    private func circleButton(_ icon: Ph, fg: Color, bg: Color, size: CGFloat = 58,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon.reffi(size * 0.36, .bold)
                .foregroundStyle(fg)
                .frame(width: size, height: size)
                .background(bg, in: Circle())
                .reffiShadow1()
        }
        .buttonStyle(.reffiPress)
    }
}

/// 덱 소진 빈 상태.
struct EmptyDeckView: View {
    let onReset: () -> Void
    var body: some View {
        VStack(spacing: ReffiSpace.s5) {
            FoodMotif(glyph: .generic)
                .frame(width: 120, height: 120)
            Text("오늘 추천을 다 봤어요")
                .reffiType(.heading)
                .foregroundStyle(ReffiColor.ink)
            Text("새 재료를 추가하거나 처음부터 다시 볼 수 있어요")
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.center)
            ReffiButton(title: "처음부터 다시", icon: ReffiIcon.undo, action: onReset)
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity)
    }
}
