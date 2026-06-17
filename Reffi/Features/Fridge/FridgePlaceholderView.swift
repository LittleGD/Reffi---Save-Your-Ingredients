import SwiftUI
import PhosphorSwift

struct FridgePlaceholderView: View {
    var body: some View {
        PlaceholderScreen(
            icon: ReffiIcon.fridge,
            title: "냉장고",
            message: "전체 재료를 카테고리별로 보고 관리하는 화면이 곧 들어옵니다."
        )
    }
}
