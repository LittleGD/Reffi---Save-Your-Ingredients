import SwiftUI

/// Tinder-style recipe deck.
/// - Swipe right = Cook, left = Pass, up = Details
/// - Dragging tilts the card and fades in a stamp (distance-proportional).
/// - Under threshold → springs back; over → flies off and the next card rises.
/// - Colors follow the design system (positive = Blue, pass = Urgent). Stamps carry labels (no color-only meaning).
struct RecipeDeckView: View {
    let suggestions: [RecipeSuggestion]
    var onCook: (RecipeSuggestion) -> Void = { _ in }
    var onPass: (RecipeSuggestion) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var detail: RecipeSuggestion?
    @State private var cookTick = 0
    @State private var passTick = 0

    private let threshold: CGFloat = 110

    private var progress: CGFloat {
        min(1, max(abs(drag.width), abs(drag.height)) / threshold)
    }

    private var current: RecipeSuggestion? {
        suggestions.indices.contains(index) ? suggestions[index] : nil
    }

    var body: some View {
        VStack(spacing: Space.s5) {
            ZStack {
                if current == nil {
                    emptyDeck
                } else {
                    ForEach(deckIndices.reversed(), id: \.self) { i in
                        cardView(i)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if current != nil {
                actionButtons
            }
        }
        .sensoryFeedback(.success, trigger: cookTick)
        .sensoryFeedback(.impact(weight: .medium), trigger: passTick)
        .sheet(item: $detail) { recipe in
            RecipeDetailSheet(recipe: recipe)
        }
        // Re-deal from the top whenever the recommendation set changes (e.g. category switch).
        .onChange(of: suggestions) { index = 0; drag = .zero }
    }

    private var deckIndices: [Int] {
        Array(index..<min(index + 3, suggestions.count))
    }

    // MARK: Card

    @ViewBuilder
    private func cardView(_ i: Int) -> some View {
        let depth = i - index
        let isTop = depth == 0
        let effDepth = max(0, CGFloat(depth) - (isTop ? 0 : progress))

        let card = cardBody(suggestions[i], isTop: isTop)
            .scaleEffect(1 - 0.05 * effDepth)
            .offset(y: 14 * effDepth)
            .offset(isTop ? drag : .zero)
            .rotationEffect(.degrees(isTop ? Double(drag.width / 18) : 0), anchor: .bottom)
            .allowsHitTesting(isTop)
            .gesture(dragGesture)

        // §6.2: 그림자는 떠 있는(맨 위) 카드 1장에만 — 스택 전체에 쌓이지 않게.
        if isTop {
            card.reffiFloatingShadow()
        } else {
            card
        }
    }

    private func cardBody(_ recipe: RecipeSuggestion, isTop: Bool) -> some View {
        cardContent(recipe)
            .padding(Space.s5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cardBackground(recipe))
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay { stampLayer(isTop: isTop) }
    }

    private func cardContent(_ recipe: RecipeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("From your leftovers · AI pick")
                .reffiText(ReffiType.caption)
                .foregroundStyle(.white)
            Text(recipe.title)
                .reffiText(ReffiType.heading)
                .foregroundStyle(.white)

            // Why now — based on the most imminent ingredient used (freshness color).
            chip(recipe.rationale, fill: recipe.topFreshness.color, fg: ReffiColor.ink)

            HStack(spacing: Space.s2) {
                chip("\(recipe.usedIngredients.count) in fridge", fill: ReffiColor.blue, fg: .white)
                chip("\(recipe.minutes) min", fill: ReffiColor.neutral200, fg: ReffiColor.ink)
            }

            Spacer(minLength: Space.s4)

            Text("Swipe to decide · up for details")
                .reffiText(ReffiType.caption)
                .foregroundStyle(.white)
        }
    }

    private func chip(_ text: String, fill: Color, fg: Color) -> some View {
        // Chips/tags/badges → radius-xs(6). pill(999) is for pill buttons (DS §4.2).
        Text(text)
            .reffiText(ReffiType.caption)
            .num() // §3.4 데이터성 숫자(개수·분·D-N) tabular
            .foregroundStyle(fg)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, 6)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
    }

    /// Card background: dish image (if any) + legibility scrim. Falls back to Blue.
    private func cardBackground(_ recipe: RecipeSuggestion) -> some View {
        ZStack {
            ReffiColor.blue
            if let name = recipe.imageAssetName {
                Image(name)
                    .resizable()
                    .scaledToFill()
            }
            LinearGradient(
                colors: [ReffiColor.ink.opacity(0.55), ReffiColor.ink.opacity(0.05), ReffiColor.ink.opacity(0.60)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func stampLayer(isTop: Bool) -> some View {
        let rightOpacity = isTop ? clamp(drag.width / threshold) : 0
        let leftOpacity = isTop ? clamp(-drag.width / threshold) : 0
        let upOpacity = isTop ? verticalStampOpacity : 0
        return ZStack {
            stamp("COOK", fill: .white, fg: ReffiColor.blue, rotate: -16)
                .opacity(rightOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            stamp("PASS", fill: ReffiColor.urgent, fg: ReffiColor.ink, rotate: 16)
                .opacity(leftOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            stamp("DETAILS", fill: ReffiColor.neutral200, fg: ReffiColor.ink, rotate: 0)
                .opacity(upOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(Space.s5)
    }

    private func stamp(_ text: String, fill: Color, fg: Color, rotate: Double) -> some View {
        Text(text)
            .reffiText(ReffiType.subhead)
            .foregroundStyle(fg)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s2)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .rotationEffect(.degrees(rotate))
    }

    private var verticalStampOpacity: CGFloat {
        guard drag.height < 0, abs(drag.height) > abs(drag.width) else { return 0 }
        return clamp(-drag.height / threshold)
    }

    // MARK: Gesture · actions

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { ended($0.translation) }
    }

    private func ended(_ t: CGSize) {
        if t.width > threshold {
            cook()
        } else if t.width < -threshold {
            pass()
        } else if t.height < -threshold {
            detail = current
            snapBack()
        } else {
            snapBack()
        }
    }

    private func cook() {
        guard let c = current else { return }
        onCook(c)
        cookTick += 1
        swipeOff(CGSize(width: 700, height: 0))
    }

    private func pass() {
        guard let c = current else { return }
        onPass(c)
        passTick += 1
        swipeOff(CGSize(width: -700, height: 0))
    }

    private func swipeOff(_ target: CGSize) {
        withAnimation(reduceMotion ? nil : ReffiMotion.easeIn) {
            drag = target
        } completion: {
            drag = .zero
            index += 1
        }
    }

    private func snapBack() {
        withAnimation(reduceMotion ? nil : ReffiMotion.easeOut) {
            drag = .zero
        }
    }

    // MARK: Action buttons

    private var actionButtons: some View {
        HStack(spacing: Space.s6) {
            actionButton("Pass", systemImage: "xmark", fg: ReffiColor.urgentDark, bg: ReffiColor.urgentLight) {
                pass()
            }
            actionButton("Details", systemImage: "arrow.up", fg: ReffiColor.ink2, bg: ReffiColor.neutral200) {
                detail = current
            }
            actionButton("Cook", systemImage: "fork.knife", fg: .white, bg: ReffiColor.blue) {
                cook()
            }
        }
    }

    private func actionButton(_ label: String, systemImage: String, fg: Color, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Space.s1) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 56, height: 56)
                    .background(bg)
                    .clipShape(Circle())
                Text(label)
                    .reffiText(ReffiType.caption)
                    .foregroundStyle(ReffiColor.ink2)
            }
        }
        .buttonStyle(ReffiPressStyle())
    }

    // MARK: Empty state

    private var emptyDeck: some View {
        VStack(spacing: Space.s3) {
            Text("All caught up")
                .reffiText(ReffiType.subhead)
                .foregroundStyle(ReffiColor.ink)
            Text("You've seen every pick from your leftovers")
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)
            Button {
                withAnimation(reduceMotion ? nil : ReffiMotion.easeOut) { index = 0 }
            } label: {
                Text("Start over")
                    .reffiText(ReffiType.caption)
                    .foregroundStyle(ReffiColor.blue)
                    .padding(.horizontal, Space.s4)
                    .padding(.vertical, Space.s3)
                    .background(ReffiColor.blueLight)
                    .clipShape(Capsule())
            }
            .buttonStyle(ReffiPressStyle())
            .frame(minHeight: 44)            // §7.3 최소 터치 타깃
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.neutral200)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}

/// Recipe details — swipe up / Details button. Lightweight for now.
private struct RecipeDetailSheet: View {
    let recipe: RecipeSuggestion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ReffiColor.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.s4) {
                Text("From your leftovers · AI pick")
                    .reffiText(ReffiType.caption)
                    .foregroundStyle(ReffiColor.blueDark)
                // Recipe name = Google Sans Flex (heading), not the Story Script display.
                Text(recipe.title)
                    .reffiText(ReffiType.heading)
                    .foregroundStyle(ReffiColor.ink)
                Text(recipe.subtitle)
                    .reffiText(ReffiType.body)
                    .foregroundStyle(ReffiColor.ink2)

                Text("From your fridge")
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.ink)
                    .padding(.top, Space.s3)
                ForEach(recipe.usedIngredients, id: \.self) { item in
                    Text("· \(item)")
                        .reffiText(ReffiType.body)
                        .foregroundStyle(ReffiColor.ink2)
                }

                Text("Pantry & seasoning")
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.ink)
                    .padding(.top, Space.s3)
                ForEach(recipe.pantry, id: \.self) { item in
                    Text("· \(item)")
                        .reffiText(ReffiType.body)
                        .foregroundStyle(ReffiColor.ink2)
                }
                Spacer()
            }
            .padding(Space.s5)
            .padding(.top, Space.s7)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ReffiPressStyle())
            .padding(Space.s3)
        }
    }
}
