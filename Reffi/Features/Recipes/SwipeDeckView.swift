import SwiftUI
import PhosphorSwift

/// Main — Tinder-style recipe deck. Background tints to the top recipe's expiry; a full-width
/// frosted liquid-glass "bowl" sits in the bottom 40% and the card stack rises out of it.
/// Right/Cook → recipe sheet · Left/Skip → next · tap → preview.
struct SwipeDeckView: View {
    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var history: [Int] = []
    @State private var detail: RecipeRecommender.Result?
    @State private var commitTick = 0
    @State private var warnTick = 0

    private let threshold: CGFloat = 110

    var body: some View {
        let results = store.rankedRecipes
        let topF: Freshness = (index < results.count ? results[index].used.first?.freshness : nil) ?? .fresh

        GeometryReader { geo in
            let H = geo.size.height
            ZStack {
                // 4. background by expiry
                LinearGradient(colors: [topF.face(depth: 0), topF.light],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: topF)

                // header + card stack
                VStack(spacing: 0) {
                    header(total: results.count)
                        .padding(.horizontal, ReffiGrid.margin)
                        .padding(.top, ReffiSpace.s2)
                    Spacer(minLength: 0)
                    ZStack {
                        if index >= results.count {
                            EmptyDeckView { reset() }
                        } else {
                            ForEach(visibleIndices(results.count), id: \.self) { i in
                                card(results[i], i: i)
                            }
                        }
                    }
                    .frame(height: H * 0.52)
                    .padding(.horizontal, ReffiGrid.margin + 6)
                    Spacer().frame(height: H * 0.30)   // cards' lower ~10% dips into the glass
                }

                // 3. frosted liquid-glass bowl (bottom 40%), in front of card bottoms
                VStack(spacing: 0) {
                    Spacer()
                    GlassBowl()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            GlassBowl().stroke(.white.opacity(0.5), lineWidth: 1)
                        )
                        .frame(height: H * 0.40)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)

                // action row (in front of glass)
                VStack(spacing: 0) {
                    Spacer()
                    if index < results.count {
                        actionRow(results).padding(.horizontal, ReffiGrid.margin)
                    }
                    Spacer().frame(height: 96)   // capsule nav clearance
                }
            }
        }
        .sheet(item: $detail) { RecipeDetailSheet(result: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: commitTick)
        .sensoryFeedback(.warning, trigger: warnTick)
    }

    // MARK: Cards

    private func visibleIndices(_ count: Int) -> [Int] {
        let upper = min(index + 2, count - 1)
        return Array(index...upper).reversed()
    }

    @ViewBuilder
    private func card(_ result: RecipeRecommender.Result, i: Int) -> some View {
        let depth = i - index
        let isTop = depth == 0
        SwipeCardView(result: result, drag: isTop ? drag : .zero, isTop: isTop)
            .scaleEffect(isTop ? 1 : 1 - CGFloat(depth) * 0.05)
            .offset(y: isTop ? 0 : CGFloat(depth) * 18)
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
        let results = store.rankedRecipes
        guard index < results.count else { return }
        let chosen = results[index]
        if !right, chosen.used.first?.freshness == .urgent { warnTick += 1 }
        let finish = {
            advance()
            if right { detail = chosen }
        }
        if reduceMotion { finish(); return }
        withAnimation(ReffiMotion.exit) {
            drag = CGSize(width: (right ? 1 : -1) * 800, height: drag.height + 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ReffiMotion.dur1) { finish() }
    }

    private func advance() {
        history.append(index)
        drag = .zero
        index += 1
        commitTick += 1
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        index = last
        drag = CGSize(width: -600, height: 0)
        withAnimation(reduceMotion ? nil : ReffiMotion.enter) { drag = .zero }
    }

    private func reset() {
        withAnimation(ReffiMotion.standard) { index = 0; history = []; drag = .zero }
    }

    // MARK: Pieces

    private func header(total: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("What's cooking?")
                .reffiType(.heading)
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
        HStack(spacing: ReffiSpace.s3) {
            iconButton(ReffiIcon.undo, fg: ReffiColor.muted) { undo() }
                .opacity(history.isEmpty ? 0.4 : 1)
                .disabled(history.isEmpty)
            textButton("Skip", ReffiIcon.close, fg: ReffiColor.ink2,
                       bg: ReffiColor.oklch(0.99, 0.006, 90)) { swipe(right: false) }
            textButton("Cook this", ReffiIcon.go, fg: .white, bg: ReffiColor.blue) { swipe(right: true) }
        }
        .frame(height: 54)
    }

    private func iconButton(_ icon: Ph, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon.reffi(20, .bold)
                .foregroundStyle(fg)
                .frame(width: 54, height: 54)
                .background(ReffiColor.oklch(0.99, 0.006, 90), in: RoundedRectangle(cornerRadius: ReffiRadius.md, style: .continuous))
                .reffiShadow1()
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel("Undo")
    }

    private func textButton(_ title: String, _ icon: Ph, fg: Color, bg: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s2) {
                Text(title).font(ReffiTextRole.subhead.font).tracking(ReffiTextRole.subhead.tracking)
                icon.reffi(18, .bold)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg, in: RoundedRectangle(cornerRadius: ReffiRadius.md, style: .continuous))
            .reffiShadow1()
        }
        .buttonStyle(.reffiPress)
    }
}

/// 사각형 보울 — 풀폭, 위가 얕게 패인(보울 깊이 ~10%) 프로스트 글래스 면. 아래가 두껍다.
struct GlassBowl: Shape {
    func path(in rect: CGRect) -> Path {
        let dip = rect.height * 0.26   // 상단 곡선 깊이
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + dip))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + dip),
                       control: CGPoint(x: rect.midX, y: rect.minY - dip * 0.2))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Deck-exhausted empty state.
struct EmptyDeckView: View {
    let onReset: () -> Void
    var body: some View {
        VStack(spacing: ReffiSpace.s5) {
            FoodMotif(glyph: .generic).frame(width: 120, height: 120)
            Text("You've seen today's picks")
                .reffiType(.heading).foregroundStyle(ReffiColor.ink)
            Text("Add new ingredients or start over.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.center)
            ReffiButton(title: "Start over", icon: ReffiIcon.undo, action: onReset)
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity)
    }
}
