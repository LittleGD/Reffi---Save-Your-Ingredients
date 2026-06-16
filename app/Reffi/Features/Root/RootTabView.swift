import SwiftUI

/// 앱 루트 — 4탭 네비게이션(§8.5 하단 내비).
/// iOS 18+/26의 `Tab` API 사용. 활성 색은 Reffi Blue.
///
/// 참고: "재료 추가"는 목업상 중앙 액션(+)이다. 1단계에선 일반 탭으로 두고,
/// 이후 단계에서 모달 시트(영수증 스캔 진입)로 바꾼다.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Fridge", systemImage: "refrigerator") {
                FridgeView()
            }
            Tab("Add", systemImage: "plus.circle") {
                AddView()
            }
            Tab("Me", systemImage: "person") {
                ProfileView()
            }
        }
        .tint(ReffiColor.blue)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Ingredient.self, inMemory: true)
}
