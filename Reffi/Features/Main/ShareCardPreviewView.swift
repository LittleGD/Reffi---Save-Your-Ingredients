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
                steps: recipe?.displaySteps ?? Self.fallbackSteps,
                count: recipe?.ingredients.count ?? 12
            )
            .padding(.vertical, ReffiSpace.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas)
    }

    /// 시드 로드 실패 시 폴백 — bibimbap 실제 영문 스텝(recipes-seed.json)과 동일 문구.
    private static let fallbackSteps = [
        "Blanch the spinach and bean sprouts separately, then season each with salt and a little sesame oil.",
        "Cut the carrot and zucchini into thin strips and stir-fry each with a pinch of salt.",
        "Cook the ground beef with garlic and a splash of soy-style seasoning until browned.",
        "Fry the egg sunny-side up so the yolk stays soft.",
        "Arrange the vegetables and beef over a bowl of warm rice and top with the egg.",
        "Add gochujang and sesame oil, then mix everything together just before eating.",
    ]
}
#endif
