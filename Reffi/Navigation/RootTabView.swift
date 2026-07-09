import SwiftUI
import PhosphorSwift

/// 루트 — 하단은 캡슐형 네비(홈·냉장고·인라인＋·프로필).
/// 세 탭을 모두 살려두고 표시만 전환한다 — 메인의 물리 더미·되돌리기 창이 탭 전환에 파괴되지 않는다.
/// (물리 씬은 `MainView(isActive:)`가 비표시 동안 일시정지.) 되돌리기 토스트는 여기서 탭 공통으로 띄운다.
struct RootTabView: View {
    enum Tab { case home, fridge, profile }

    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: Tab = {
        #if DEBUG
        // 스크린샷·QA용 — 런치 인자로 특정 탭 직행(-glyphGallery 선례, PR #4).
        if ProcessInfo.processInfo.arguments.contains("-profileTab") { return .profile }
        if ProcessInfo.processInfo.arguments.contains("-fridgeTab") { return .fridge }
        #endif
        return .home
    }()
    @State private var showAdd = false
    @State private var undoHaptic = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // 세 탭 공존(pane) 유지 — switch 전환은 메인 물리 더미·undo 상태를 파괴한다.
            // 프로필 탭은 PR #4의 ProfileView(계정·취향·리포트)로 교체.
            pane(MainView(isActive: tab == .home), visible: tab == .home)
            pane(FridgeView(), visible: tab == .fridge)
            pane(ProfileView(), visible: tab == .profile)

            CapsuleNav(tab: $tab, onAdd: { showAdd = true })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas.ignoresSafeArea())
        // 되돌리기 토스트 — 위에서 내려온다(하단 CTA·네비를 가리지 않게). 어느 탭이든 같은 자리.
        .overlay(alignment: .top) {
            if let undo = store.pendingUndo {
                UndoToast(undo: undo) {
                    undoHaptic += 1
                    withAnimation(ReffiMotion.gated(ReffiMotion.pop, reduce: reduceMotion)) {
                        store.undoPending()
                    }
                }
                .padding(.top, ReffiSpace.s2)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(ReffiMotion.gated(ReffiMotion.settle, reduce: reduceMotion), value: store.pendingUndo)
        .sensoryFeedback(.success, trigger: undoHaptic)
        #if DEBUG
        // UI 테스트 결정적 상태 — 기기에 남은 사용자 데이터와 무관하게 샘플 냉장고로 고정.
        // (-loadSample은 첫 실행(isPristine)에만 시드하므로 테스트엔 강제 리셋 인자가 따로 필요.)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-uiTestSampleFridge") {
                store.loadSampleData()
                // 냉장고 보기 프리퍼런스도 기본값으로 — 직전 테스트가 중간에 죽어도 오염이 남지 않게.
                UserDefaults.standard.set(false, forKey: "fridge.compact")
                UserDefaults.standard.set(FridgeSort.expiry.rawValue, forKey: "fridge.sort")
            }
        }
        #endif
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet()   // presentationDetents는 시트 내부에서 적용(중복 방지)
        }
    }

    @ViewBuilder private func pane(_ view: some View, visible: Bool) -> some View {
        view
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
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
        .frame(height: 58)
        .navGlass()
        .shadow(color: ReffiColor.ink.opacity(0.06), radius: 6, x: 0, y: 2)   // 약한 드롭섀도
        .padding(.bottom, 2)   // 더 아래로 — 홈 인디케이터 근처
    }

    /// 탭(홈·냉장고·프로필) — 활성 Blue+fill / 비활성 muted+regular.
    private func navItem(_ t: RootTabView.Tab, _ icon: Ph, _ label: LocalizedStringKey) -> some View {
        let active = tab == t
        return navButton(icon: icon, label: label,
                         tint: active ? ReffiColor.blue : ReffiColor.muted,
                         weight: active ? .fill : .regular,
                         selected: active) { tab = t }
    }

    /// 추가(액션) — 다른 비활성 탭과 동일한 muted+regular로 통일(Blue·ink 둘 다 배제).
    private func actionItem(_ icon: Ph, _ label: LocalizedStringKey) -> some View {
        navButton(icon: icon, label: label, tint: ReffiColor.muted, weight: .regular,
                  selected: false, action: onAdd)
    }

    /// 모든 네비 항목 공통 형식 — 아이콘(23) + 라벨(11/caption2 스케일).
    private func navButton(icon: Ph, label: LocalizedStringKey, tint: Color, weight: Ph.IconWeight,
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
        .accessibilityLabel(Text(label))
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
