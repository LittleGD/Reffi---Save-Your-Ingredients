import SwiftUI
import PhosphorSwift

/// 루트 — 하단 캡슐형 커스텀 네비 (원본 jmlee 구조 이식, 우리 디자인 토큰으로 치환).
/// 목적지 3개(홈·냉장고·프로필) + ＋는 탭이 아니라 재료 추가 시트를 여는 인라인 액션(§8.5).
struct RootTabView: View {
    enum Tab { case home, fridge, profile }

    @State private var tab: Tab = .home
    @State private var showAdd = false

    var body: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 캡슐 네비 높이만큼 콘텐츠를 띄워 하단 버튼과 겹치지 않게.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    CapsuleNav(tab: $tab, onAdd: { showAdd = true })
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Space.s3)
                }
        }
        .sheet(isPresented: $showAdd) {
            AddView()
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:    HomeView()
        case .fridge:  FridgeView()
        case .profile: ProfileView()
        }
    }
}

/// 캡슐 네비 — radius-pill 면 + floating 그림자, 보더 없음(§6).
/// 활성 = Blue + 채움 아이콘 / 비활성·추가 = muted. ＋는 인라인(플로팅 FAB 아님).
private struct CapsuleNav: View {
    @Binding var tab: RootTabView.Tab
    let onAdd: () -> Void

    // 캡슐 면: 캔버스보다 살짝 밝은 근(近)백색 (DS는 순백 금지 — oklch(0.99) 근사).
    private let surface = Color(hex: "#FCFAF4")

    var body: some View {
        HStack(spacing: Space.s3) {
            navItem(.home, ReffiIcon.home, "Home")
            navItem(.fridge, ReffiIcon.fridge, "Fridge")
            actionItem(ReffiIcon.add, "Add")
            navItem(.profile, ReffiIcon.profile, "Profile")
        }
        .padding(.horizontal, Space.s5)
        .frame(height: 60)
        .background(surface, in: Capsule())
        .reffiFloatingShadow()
    }

    private func navItem(_ t: RootTabView.Tab, _ icon: Ph, _ label: String) -> some View {
        let active = tab == t
        return navButton(icon: icon, label: label,
                         tint: active ? ReffiColor.blue : ReffiColor.muted,
                         weight: active ? .fill : .regular, selected: active) { tab = t }
    }

    /// 추가 — 비활성 탭과 동일하게 muted(§2.4: 추가는 Blue로 강조하지 않음).
    private func actionItem(_ icon: Ph, _ label: String) -> some View {
        navButton(icon: icon, label: label, tint: ReffiColor.muted,
                  weight: .regular, selected: false, action: onAdd)
    }

    private func navButton(icon: Ph, label: String, tint: Color,
                           weight: Ph.IconWeight, selected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon.reffi(23, weight)
                Text(label)
                    .font(.custom(ReffiType.gsfMedium, size: 11))
            }
            .foregroundStyle(tint)
            .frame(minWidth: 52, minHeight: 48)  // §7.3 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(ReffiPressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Ingredient.self, inMemory: true)
}
