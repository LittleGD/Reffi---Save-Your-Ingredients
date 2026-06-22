import SwiftUI
import PhosphorSwift

/// 루트 — 메인은 레시피 스와이프 덱. 하단은 캡슐형 네비(홈·냉장고·인라인＋·프로필).
struct RootTabView: View {
    enum Tab { case home, fridge, profile }

    @State private var tab: Tab = .home
    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:    FridgeBowlView()
                case .fridge:  FridgePlaceholderView()
                case .profile: MyPagePlaceholderView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CapsuleNav(tab: $tab, onAdd: { showAdd = true })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas.ignoresSafeArea())
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet().presentationDetents([.medium, .large])
        }
    }
}

/// 캡슐 네비 — radius-pill 면 + reffiShadow1, 보더 없음. ＋는 인라인(플로팅 아님), 프로필은 아바타.
private struct CapsuleNav: View {
    @Binding var tab: RootTabView.Tab
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: ReffiSpace.s3) {
            navItem(.home, ReffiIcon.home, "Home")
            navItem(.fridge, ReffiIcon.fridge, "Fridge")
            actionItem(ReffiIcon.add, "Add")
            navItem(.profile, ReffiIcon.profile, "Profile")
        }
        .padding(.horizontal, ReffiSpace.s5)
        .frame(height: 60)
        .navGlass()
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 6, x: 0, y: 2)   // 약한 드롭섀도
        .padding(.bottom, ReffiSpace.s3)
    }

    /// 탭(홈·냉장고·프로필) — 활성 Blue+fill / 비활성 muted+regular.
    private func navItem(_ t: RootTabView.Tab, _ icon: Ph, _ label: String) -> some View {
        let active = tab == t
        return navButton(icon: icon, label: label,
                         tint: active ? ReffiColor.blue : ReffiColor.muted,
                         weight: active ? .fill : .regular,
                         selected: active) { tab = t }
    }

    /// 추가(액션) — 다른 비활성 탭과 동일한 muted+regular로 통일(Blue·ink 둘 다 배제).
    private func actionItem(_ icon: Ph, _ label: String) -> some View {
        navButton(icon: icon, label: label, tint: ReffiColor.muted, weight: .regular,
                  selected: false, action: onAdd)
    }

    /// 모든 네비 항목 공통 형식 — 아이콘(23) + 라벨(11/caption2 스케일).
    private func navButton(icon: Ph, label: String, tint: Color, weight: Ph.IconWeight,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon.reffi(23, weight)
                Text(label)
                    .font(.custom("Pretendard-Medium", size: 11, relativeTo: .caption2))
            }
            .foregroundStyle(tint)
            .frame(minWidth: 52, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private extension View {
    /// 네비 배경 — iOS 네이티브 리퀴드글래스(프로스트). Apple 권장대로 GlassEffectContainer로 감쌈.
    /// iOS 26+; 이전은 ultraThinMaterial 폴백.
    @ViewBuilder func navGlass() -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                self.glassEffect(.regular, in: Capsule())
            }
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
