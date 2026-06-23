import SwiftUI
import PhosphorSwift

/// 레시피 추천 캐러셀(§13) — 풀스크린, **네비 없음**. 오더 메모 카드 3장을 좌우로 둘러본다(스킵/시작 액션 없음).
/// 네비가 없으므로 우상단 닫기(X)로 메인 복귀.
struct RecipeMemoCarousel: View {
    let results: [RecipeRecommender.Result]
    var onClose: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack(alignment: .top) {
            // 따뜻한 주방 패스 종이 배경.
            ReffiColor.oklch(0.95, 0.016, 90).ignoresSafeArea()

            if results.isEmpty {
                emptyState
            } else {
                TabView(selection: $page) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, r in
                        OrderMemoCard(result: r, number: i + 1)
                            .padding(.horizontal, ReffiGrid.margin + 4)
                            .padding(.top, 96)
                            .padding(.bottom, 64)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()
                    pageDots.padding(.bottom, ReffiSpace.s6)
                }
            }

            topBar
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Today's tickets").reffiType(.heading).foregroundStyle(ReffiColor.ink)
                Text("\(results.count) picks from what you kept")
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
            .accessibilityLabel("닫기")
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
            PaperButton(title: "Back", kind: .secondary, fullWidth: false) { onClose() }
        }
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
