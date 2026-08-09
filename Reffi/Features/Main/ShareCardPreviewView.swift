import SwiftUI

#if DEBUG
/// 검증용 — 공유 시트는 시스템 UI라 스크린샷 검증이 어려워, 실제 공유될 `RecipeShareCard`를 화면에
/// 그대로 띄운다. 런치 인자 `-shareCardPreview`로 표시. `-cookTicket`과 같은 소스(bibimbap 시드)를 재사용.
struct ShareCardPreviewView: View {
    var body: some View {
        let recipe = RecipeCatalog.loadSeed().first { $0.id == "bibimbap" }
        ScrollView {
            RecipeShareCard(
                recipeName: recipe?.displayName ?? "Bibimbap",
                // 시드 재료 표기를 그대로(레시피 콘텐츠는 코드에 리터럴로 두지 않는다 — 시드가 없으면 빈 목록).
                ingredientNames: recipe?.ingredients.map(\.displayName) ?? [],
                minutes: recipe?.minutes,
                count: recipe?.ingredients.count ?? 0
            )
            // 실제 공유 경로(CookingStepsView.renderShareImage)와 같은 라이트 고정 렌더를 검증용에서도 재현.
            .environment(\.colorScheme, .light)
            .padding(.vertical, ReffiSpace.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas)
    }
}
#endif
