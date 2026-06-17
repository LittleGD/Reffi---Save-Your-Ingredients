import SwiftUI
import PhosphorSwift

/// 메인 레시피 배너(화면 ~절반) — 가장 급한 재료들을 조합한 추천.
/// 따뜻한 패널 + 색면 음식 일러스트로 식욕을 살리고, Blue는 AI 태그·CTA에만(60:30:5:5).
struct RecipeBannerView: View {
    let result: RecipeRecommender.Result
    var onCook: () -> Void = {}

    var body: some View {
        let recipe = result.recipe
        let used = result.used

        VStack(spacing: 0) {
            // 상단: AI 태그 · 조리시간
            HStack(alignment: .top) {
                AITag()
                Spacer()
                MetaChip(icon: ReffiIcon.time, text: "\(recipe.minutes)분")
            }

            // 음식 일러스트(가변 영역)
            FoodHeroMotif(glyph: recipe.glyph)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, ReffiSpace.s2)

            // 하단: 레시피명 · 설명 · 임박 재료칩 · CTA
            VStack(alignment: .leading, spacing: ReffiSpace.s3) {
                Text(recipe.name)
                    .reffiType(.heading)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subcopy(used))
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                if !used.isEmpty {
                    HStack(spacing: ReffiSpace.s2) {
                        ForEach(used.prefix(3)) { FreshnessChip(ingredient: $0) }
                        if used.count > 3 {
                            Text("+\(used.count - 3)")
                                .font(.reffiNum(13, relativeTo: .caption))
                                .foregroundStyle(ReffiColor.ink2)
                        }
                        Spacer(minLength: 0)
                    }
                }

                ReffiButton(title: "조리하기", icon: ReffiIcon.go, fullWidth: true, action: onCook)
                    .padding(.top, ReffiSpace.s1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ReffiSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.sub, in: RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
        .reffiShadow1()
    }

    private func subcopy(_ used: [Ingredient]) -> String {
        used.isEmpty
            ? "냉장고 속 재료로 만드는 추천이에요"
            : "가장 급한 재료 \(used.count)개를 한 번에 써요"
    }
}
