import Foundation

/// 번들 시드 레시피 로더 — `recipes-seed.json`(영-한 이중언어, 다국적)을 읽는다.
/// 레시피 하드코딩 금지(프로젝트 규칙): 코드에는 로더만 있고 데이터는 전부 번들 JSON에.
enum RecipeCatalog {
    private struct File: Decodable {
        var version: Int
        var recipes: [Recipe]
    }

    static func loadSeed(bundle: Bundle = .main) -> [Recipe] {
        guard let url = bundle.url(forResource: "recipes-seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.recipes
    }
}
