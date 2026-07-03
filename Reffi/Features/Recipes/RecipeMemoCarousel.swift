import SwiftUI
import PhosphorSwift

/// 레시피 추천 캐러셀(§13) — 풀스크린, **네비 없음**. 주방 오더 티켓 종이들이 **금속 집게(불독 클립)**에
/// 집혀 더미로 매달린 모습. 좌우로 넘겨보고, "이걸로 요리"로 발주(Fire the Ticket)한다. 닫기 X로 메인 복귀.
struct RecipeMemoCarousel: View {
    let results: [RecipeRecommender.Result]
    var onClose: () -> Void
    var onFire: (RecipeRecommender.Result) -> Void = { _ in }

    @State private var page = 0

    private let topInset: CGFloat = 134   // 집게 아래로 티켓 시작
    private let botInset: CGFloat = 86

    var body: some View {
        ZStack(alignment: .top) {
            ReffiColor.paperPass.ignoresSafeArea()
            if results.isEmpty { emptyState } else { clippedStack }
            topBar
        }
    }

    // MARK: - 집게에 집힌 티켓 더미

    private var clippedStack: some View {
        ZStack(alignment: .top) {
            // 뒤에 매달린 종이 더미(두께감)
            ForEach(stackDepth, id: \.self) { d in
                receiptBack
                    .padding(.horizontal, ReffiGrid.margin + 8)
                    .padding(.top, topInset)
                    .padding(.bottom, botInset)
                    .scaleEffect(1 - CGFloat(d) * 0.01, anchor: .top)
                    .rotationEffect(.degrees(d % 2 == 1 ? 2.6 : -2.3), anchor: .top)
                    .offset(x: CGFloat(d) * (d % 2 == 1 ? 5 : -5), y: CGFloat(d) * 13)
            }

            // 앞 티켓 — 좌우로 넘겨보기
            TabView(selection: $page) {
                ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                    OrderMemoCard(result: r, number: i + 1) { onFire(r) }
                        .padding(.horizontal, ReffiGrid.margin + 8)
                        .padding(.top, topInset)
                        .padding(.bottom, botInset)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 금속 집게 — 종이 더미 맨 위 중앙을 문다
            BulldogClip()
                .frame(width: 76, height: 96)
                .padding(.top, 66)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) { pageDots.padding(.bottom, ReffiSpace.s6) }
    }

    private var stackDepth: [Int] {
        let n = max(0, min(2, results.count - 1))
        return n == 0 ? [] : Array(1...n)
    }

    private var receiptBack: some View {
        ReceiptShape(tooth: 9).fill(ReffiColor.paper)
            .overlay(ReceiptShape(tooth: 9).stroke(ReffiColor.ink.opacity(0.06), lineWidth: 1))
            .reffiShadow1()
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Today's tickets").reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Text("Ranked by what spoils first")
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
            }
            .buttonStyle(.paperPress)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s4)
    }

    private var pageDots: some View {
        HStack(spacing: ReffiSpace.s1) {
            ForEach(0..<results.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(i == page ? ReffiColor.blue : ReffiColor.muted.opacity(0.4))
                    .frame(width: i == page ? 20 : 7, height: 7)
                    .animation(ReffiMotion.settle, value: page)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: ReffiSpace.s4) {
            FoodMotif(glyph: .generic).frame(width: 110, height: 110)
            Text("No tickets yet").reffiType(.heading).foregroundStyle(ReffiColor.ink)
            Text("Keep a few ingredients on, then start cooking.")
                .reffiType(.body).foregroundStyle(ReffiColor.ink2).multilineTextAlignment(.center)
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 금속 종이 집게(불독 클립)

/// 크롬 불독 클립 — 차가운 회색(저채도 H≈250) 플랫 톤으로 금속을 암시. 종이 더미 위에 얹는 장식.
struct BulldogClip: View {
    private let light = ReffiColor.oklch(0.88, 0.004, 250)
    private let mid   = ReffiColor.oklch(0.78, 0.005, 250)
    private let dark  = ReffiColor.oklch(0.60, 0.007, 250)
    private let edge  = ReffiColor.oklch(0.48, 0.009, 250)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // 두 와이어 손잡이(루프)
                ForEach([-1.0, 1.0], id: \.self) { s in
                    Capsule(style: .continuous)
                        .stroke(mid, lineWidth: w * 0.075)
                        .frame(width: w * 0.32, height: h * 0.5)
                        .overlay(Capsule(style: .continuous).stroke(edge.opacity(0.45), lineWidth: 0.8)
                            .frame(width: w * 0.32, height: h * 0.5))
                        .rotationEffect(.degrees(s * 19))
                        .offset(x: CGFloat(s) * w * 0.18, y: -h * 0.02)
                }
                // 본체(둥근 사다리꼴) — 아래가 넓어 종이를 문다
                ClipBody()
                    .fill(mid)
                    .overlay(alignment: .top) {
                        ClipBody().fill(light)
                            .mask(Rectangle().frame(height: h * 0.13).frame(maxHeight: .infinity, alignment: .top))
                    }
                    .overlay {
                        HStack(spacing: w * 0.14) {
                            Capsule().fill(edge.opacity(0.32)).frame(width: 1.6, height: h * 0.26)
                            Capsule().fill(edge.opacity(0.32)).frame(width: 1.6, height: h * 0.26)
                        }
                    }
                    .overlay(ClipBody().stroke(edge.opacity(0.8), lineWidth: 1))
                    .frame(width: w, height: h * 0.58)
                    .offset(y: h * 0.19)
                // 가운데 리벳
                Circle().fill(light).overlay(Circle().stroke(edge.opacity(0.6), lineWidth: 1))
                    .frame(width: w * 0.13, height: w * 0.13)
                    .offset(y: -h * 0.02)
            }
            .compositingGroup()
            .reffiShadow1()
        }
    }
}

/// 클립 본체 — 위 좁고 아래 넓은 둥근 사다리꼴.
struct ClipBody: Shape {
    func path(in r: CGRect) -> Path {
        let inset = r.width * 0.18, rad = r.width * 0.09
        var p = Path()
        p.move(to: CGPoint(x: r.minX + inset + rad, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - inset - rad, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - inset, y: r.minY + rad), control: CGPoint(x: r.maxX - inset, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + inset, y: r.minY + rad))
        p.addQuadCurve(to: CGPoint(x: r.minX + inset + rad, y: r.minY), control: CGPoint(x: r.minX + inset, y: r.minY))
        p.closeSubpath()
        return p
    }
}
