import SwiftUI
import SwiftData

@main
struct ReffiApp: App {
    /// SwiftData 컨테이너 — Ingredient를 영속 저장.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Ingredient.self)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
        // 첫 실행 시 샘플 데이터 시드 (스켈레톤 데모용).
        SampleData.seedIfEmpty(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
