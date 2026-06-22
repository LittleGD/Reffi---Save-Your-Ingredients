import SwiftUI
import PhosphorSwift

/// 틴더형 레시피 카드 — 컬러 배경 위 라이트 면. 음식 이미지가 카드 위로 말풍선처럼 "뾱" 튀어나온다.
/// 스와이프 의미(행동)는 색축과 분리(우=Cook / 좌=Skip).
struct SwipeCardView: View {
    let result: RecipeRecommender.Result
    var drag: CGSize = .zero
    var isTop: Bool = false

    @State private var pop: CGFloat = 0.5

    private var f: Freshness { result.used.first?.freshness ?? .fresh }

    var body: some View {
        let r = result.recipe
        ZStack(alignment: .top) {
            cardBody(r)
            bubble(r)
                .scaleEffect(pop, anchor: .bottom)
                .offset(y: -54)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.80, contentMode: .fit)
        .onAppear { if isTop { animatePop() } }
        .onChange(of: isTop) { _, now in if now { animatePop() } }
    }

    private func animatePop() {
        pop = 0.5
        withAnimation(.spring(response: 0.34, dampingFraction: 0.56)) { pop = 1 }
    }

    private func cardBody(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Color.clear.frame(height: 52)   // 말풍선 겹침 여유
            Text(r.name)
                .reffiType(.heading)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack(spacing: ReffiSpace.s2) {
                if result.urgentUsedCount > 0 {
                    Text("\(result.urgentUsedCount) expiring today").foregroundStyle(ReffiColor.urgentDark)
                } else {
                    Text("\(result.used.count) to use").foregroundStyle(ReffiColor.ink2)
                }
                Text("·").foregroundStyle(ReffiColor.muted)
                Text("\(r.minutes) min").foregroundStyle(ReffiColor.ink2)
            }
            .font(.reffiNum(15, relativeTo: .caption))
            HStack(spacing: ReffiSpace.s1) {
                ForEach(result.used.prefix(3)) { ing in
                    Text(ing.name)
                        .reffiType(.caption)
                        .foregroundStyle(ing.freshness.dark)
                        .lineLimit(1)
                        .padding(.horizontal, ReffiSpace.s2)
                        .padding(.vertical, 4)
                        .background(ing.freshness.light, in: Capsule())
                        .fixedSize()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReffiColor.oklch(0.99, 0.006, 90),
                    in: RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
        .overlay(stamps)
        .reffiShadow1()
    }

    /// 음식 말풍선 — 라이트 원 + 음식 모티프 + 아래 꼬리. 카드 위로 뾱.
    private func bubble(_ r: Recipe) -> some View {
        ZStack {
            Circle().fill(ReffiColor.oklch(0.99, 0.006, 90))
            Circle().strokeBorder(f.main.opacity(0.5), lineWidth: 3)
            FoodMotif(glyph: r.glyph).padding(16)
        }
        .frame(width: 108, height: 108)
        .background(alignment: .bottom) {
            Triangle().fill(ReffiColor.oklch(0.99, 0.006, 90))
                .frame(width: 26, height: 14)
                .offset(y: 7)
        }
        .reffiShadow1()
    }

    private var stamps: some View {
        let urgent = f == .urgent
        return ZStack {
            stamp("Cook", ReffiIcon.go, ReffiColor.blue, leading: true,
                  opacity: Double(max(0, min(1, drag.width / 80))))
            stamp(urgent ? "Use today!" : "Skip", ReffiIcon.close,
                  urgent ? ReffiColor.urgentDark : ReffiColor.muted, leading: false,
                  opacity: Double(max(0, min(1, -drag.width / 80))))
        }
    }

    private func stamp(_ text: String, _ icon: Ph, _ color: Color, leading: Bool, opacity: Double) -> some View {
        HStack(spacing: ReffiSpace.s1) {
            if leading { icon.reffi(20, .bold) }
            Text(text).reffiType(.heading)
            if !leading { icon.reffi(20, .bold) }
        }
        .foregroundStyle(color)
        .padding(.horizontal, ReffiSpace.s3)
        .padding(.vertical, ReffiSpace.s2)
        .background(ReffiColor.canvas.opacity(0.9), in: RoundedRectangle(cornerRadius: ReffiRadius.md, style: .continuous))
        .rotationEffect(.degrees(leading ? -10 : 10))
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leading ? .topLeading : .topTrailing)
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

/// 말풍선 꼬리.
struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.closeSubpath()
        return p
    }
}
