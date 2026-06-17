import SwiftUI

/// 홈 — 상단 ~절반 메인 레시피 배너, 그 아래 마감 임박 순 카드 스택.
struct HomeView: View {
    @Environment(FridgeStore.self) private var store
    @State private var showProfile = false
    var onAdd: () -> Void = {}

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ReffiSpace.s5) {
                HomeTopBar(onProfile: { showProfile = true })

                if let recommendation = store.recommendation {
                    RecipeBannerView(result: recommendation)
                        .containerRelativeFrame(.vertical) { height, _ in
                            max(420, height * 0.62)   // 화면 상단~70% 차지하는 히어로
                        }
                }

                IngredientStackView(style: .current)
            }
            .padding(.horizontal, ReffiGrid.margin)
            .padding(.top, ReffiSpace.s2)
            .padding(.bottom, 120)   // 떠 있는 하단 네비 여유
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(ReffiColor.canvas.ignoresSafeArea())
        .sheet(isPresented: $showProfile) {
            MyPagePlaceholderView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// 상단 바 — Story Script 워드마크 + 오늘 날짜 + 내 프로필(아바타) 버튼.
private struct HomeTopBar: View {
    var onProfile: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: ReffiSpace.s2) {
            Text("Reffi")
                .reffiType(.display)
                .foregroundStyle(ReffiColor.ink)
            Spacer()
            Text(Self.today)
                .font(.reffiNum(14, relativeTo: .caption))
                .foregroundStyle(ReffiColor.ink2)
            Button(action: onProfile) {
                ReffiIcon.profile.reffi(20, .regular)
                    .foregroundStyle(ReffiColor.ink2)
                    .frame(width: 38, height: 38)
                    .background(ReffiColor.sub, in: Circle())   // 아바타(§5 박스=콘텐츠 예외)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.reffiPress)
            .accessibilityLabel("내 프로필")
        }
        .padding(.top, ReffiSpace.s2)
    }

    private static let today: String = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.setLocalizedDateFormatFromTemplate("MMMd EEEE")
        return f.string(from: Date())
    }()
}
