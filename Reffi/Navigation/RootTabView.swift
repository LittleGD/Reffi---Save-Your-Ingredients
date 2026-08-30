import SwiftUI
import PhosphorSwift

/// 루트 — 하단은 캡슐형 네비(홈·냉장고·인라인＋·프로필).
/// 세 탭을 모두 살려두고 표시만 전환한다 — 메인의 물리 더미·되돌리기 창이 탭 전환에 파괴되지 않는다.
/// (물리 씬은 `MainView(isActive:)`가 비표시 동안 일시정지.) 되돌리기 토스트는 여기서 탭 공통으로 띄운다.
struct RootTabView: View {
    enum Tab { case home, fridge, profile }

    @Environment(FridgeStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var tab: Tab = {
        #if DEBUG
        // 스크린샷·QA용 — 런치 인자로 특정 탭 직행(-glyphGallery 선례, PR #4).
        if ProcessInfo.processInfo.arguments.contains("-profileTab") { return .profile }
        // 냉장고 **패인** 인자는 냉장고 탭을 함의한다 — RUN.md가 "단독 지정해도 착지"를 약속하는
        // 인자들이라, 루트가 홈에 머물면 그 약속이 조용히 깨진다(패인 선택은 `FridgeTab.initial`).
        if ["-fridgeTab", "-toBuy", "-toBuy.search", "-toBuy.swipeHint", "-toBuy.sampleMemo",
            "-showHistory"]
            .contains(where: ProcessInfo.processInfo.arguments.contains) { return .fridge }
        #endif
        return .home
    }()
    @State private var showAdd = false
    @State private var undoHaptic = 0
    /// 냉장고가 다음에 열어야 할 패인 — **1회성 신호**다(받는 쪽이 소비하면서 nil로 되돌린다).
    /// 탭 전환과 패인 지정이 서로 다른 뷰에 살기 때문에 값 하나로 묶어 함께 보낸다: `tab`만 바꾸면
    /// 냉장고는 자기가 마지막에 보던 패인을 그대로 띄운다(패인 선택은 `FridgeView`의 세션 상태다).
    @State private var fridgePane: FridgeTab?

    #if DEBUG
    /// `-toBuy.sampleMemo`가 담는 장보기 메모 두 줄(위 `onAppear` 참고). **사전 밖 자유 표기**라
    /// 샘플 냉장고 재료와 캐논이 겹치지 않는다 — 겹치면 흡수 의미론에 걸려 줄이 서지 않거나
    /// `Bought` 재입고가 남의 줄을 건드린다. 두 줄인 이유는 행 **사이**를 봐야 하기 때문이다
    /// (28차 절취선). UI 테스트가 같은 문자열을 그대로 본다.
    static let sampleMemoNames = ["Fish sauce brand X", "Rice vinegar brand Y"]
    #endif

    var body: some View {
        ZStack(alignment: .bottom) {
            // 세 탭 공존(pane) 유지 — switch 전환은 메인 물리 더미·undo 상태를 파괴한다.
            // 프로필 탭은 PR #4의 ProfileView(계정·취향·리포트)로 교체.
            //
            // **공존은 상태를 살리기 위한 것이지 그리기까지 살리자는 뜻이 아니다.** 세 뷰가 전부
            // store를 보므로 판정 한 번에 세 화면분 body가 돌고, 가려진 둘도 리퀴드글래스와 종이
            // 카드를 그대로 다시 그렸다. 그래서 셋 다 `isActive`를 받아 **비활성이면 본문을 세우지
            // 않는다** — @State·@AppStorage·시트는 뷰가 살아 있는 한 그대로다(메인의 물리 씬은
            // 여전히 여기서 일시정지된다).
            pane(MainView(isActive: tab == .home, onOpenToBuy: { openFridge(.toBuy) }), visible: tab == .home)
            pane(FridgeView(isActive: tab == .fridge, pendingPane: $fridgePane), visible: tab == .fridge)
            pane(ProfileView(isActive: tab == .profile), visible: tab == .profile)

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
                    ReffiAnnounce.say(AppLanguage.localizedNow("Undone."))
                }
                .padding(.top, ReffiSpace.s2)
                // 이 토스트는 **잉크 캡슐**이지 종이가 아니다 — 종이컷 표면 전용인 통통 스프링(§7.5)을
                // 태우면 안내가 튀어 오르며 종이 행세를 한다. 들 때는 §7.1 진입(dur-3 ease-out)으로
                // 내려오고, **날 때는 자리를 밀지 않고 그 자리에서 흐려진다**: 되돌리기 창이 만료로
                // 조용히 닫히는 것은 사건이 아니라 시간이 지난 것이라, 다시 위로 걷히면 눈이 그것을
                // 새 사건으로 쫓는다. 진입=이탈 대칭이던 옛 문법의 정확한 반대다(§7.1 이탈은 더 빠르게).
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity)
                        .animation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion)),
                    removal: .opacity
                        .animation(ReffiMotion.gated(ReffiMotion.exit, reduce: reduceMotion))))
            }
        }
        // 트랜지션이 자기 커브를 들고 있으므로 여기서는 **창이 열리고 닫히는 트랜잭션만** 연다
        // (Reduce Motion이면 nil이라 토스트가 즉시 서고 즉시 사라진다, §7.4).
        .animation(ReffiMotion.gated(ReffiMotion.enter, reduce: reduceMotion), value: store.pendingUndo)
        .reffiFeedback(.success, trigger: undoHaptic)
        // 판정·삭제는 뱃지·카드를 화면에서 지우고 토스트만 남긴다 — 그 토스트는 포커스를 가져가지
        // 않으므로, 고지가 없으면 보조기술 사용자는 무엇이 사라졌는지도 되돌릴 수 있다는 것도 모른다.
        // **토스트를 띄우는 이 자리가 고지 자리**다(FridgeStore는 순수 데이터라 보조기술을 볼 수 없다).
        .onChange(of: store.pendingUndo) { previous, current in
            // 창이 **열릴 때만** 말한다: 만료로 닫히는 것은 사건이 아니고, 되돌리기 실행은 버튼이 말한다.
            // 토큰으로 비교하는 이유는 연속 판정 때문이다 — 같은 이름·같은 종류를 잇달아 처리하면
            // 값이 같아 새 창이 열린 줄 모른다(토큰은 창마다 새로 발급된다).
            guard let current, previous?.token != current.token else { return }
            ReffiAnnounce.say(current.announcement)
        }
        // VoiceOver가 켜져 있으면 되돌리기 창을 늘린다 — 고지를 듣고(2~3초) 토스트로 포커스를 옮겨
        // Undo까지 스와이프하는 데 6초는 모자란다. 스토어에 UIKit을 들이지 않으려고 값만 건넨다.
        .onChange(of: voiceOver, initial: true) { _, on in
            store.undoWindowSeconds = on ? FridgeStore.voiceOverUndoWindow : FridgeStore.defaultUndoWindow
        }
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
            // `-toBuy.sampleMemo` — 장보기 메모 두 줄 시드. **위 리셋 바로 뒤여야 한다**
            // (`loadSampleData()`가 `manualToBuy`를 비우므로 순서가 뒤집히면 시드가 지워진다).
            //
            // 왜 필요한가: To buy 패인을 겨눈 QA 인자(`-toBuy.swipeHint`, 28차)는 목록에 줄이 있어야
            // 볼 것이 생기는데 새 설치의 메모는 비어 있고, 메모를 채우는 유일한 경로가 검색 시트
            // 여닫기라 인자 하나로 화면에 닿는다는 규약이 To buy에서만 깨져 있었다. UI 테스트도 같은
            // 이유로 시트를 세 단계 몰아야 했고, 그 조작 사슬이 실측에서 반복적으로 흔들렸다
            // (시트 프레젠테이션 유실·합성 타이핑 포커스 유실).
            //
            // 이름은 **사전 밖 자유 표기**다 — 샘플 냉장고 재료와 캐논이 겹치면 흡수 의미론에 걸려
            // 줄이 서지 않거나 Bought 재입고가 남의 줄을 건드린다. `canonicalIsFinal: true`로 넘겨
            // store의 포함 매칭 폴백도 끊는다(`addTyped`와 같은 규약).
            if ProcessInfo.processInfo.arguments.contains("-toBuy.sampleMemo") {
                for name in Self.sampleMemoNames {
                    store.addToBuy(name: name, canonicalID: nil, canonicalIsFinal: true)
                }
            }
            // 탭 직행 보강 — 위 @State 초기값 클로저와 같은 조건을 onAppear에서도 한 번 더 확인해
            // 스크린샷·QA 자동화가 launch 인자 하나만으로 안정적으로 목표 탭에 도달하게 한다.
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-profileTab") { tab = .profile }
            else if ["-fridgeTab", "-toBuy", "-toBuy.search", "-toBuy.swipeHint",
                     "-toBuy.sampleMemo", "-showHistory"]
                .contains(where: args.contains) { tab = .fridge }
        }
        #endif
        .sheet(isPresented: $showAdd) {
            AddIngredientSheet()   // presentationDetents는 시트 내부에서 적용(중복 방지)
        }
    }

    /// 다른 탭의 흐름이 지정한 목적지로 간다 — **패인을 먼저 예약하고 탭을 옮긴다**(순서가 반대면
    /// 냉장고가 한 프레임 동안 직전 패인을 보여 준 뒤 갈아탄다). 커버 체인은 이미 걷힌 뒤다
    /// (`MainView`가 커버 `onDismiss`에서 부른다) — 여기서 탭을 바꾸는 것이 마지막 한 걸음이다.
    private func openFridge(_ pane: FridgeTab) {
        fridgePane = pane
        tab = .fridge
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

    @Environment(\.dynamicTypeSize) private var typeSize

    /// AX 크기에서는 **아이콘만** 세운다(iOS 표준 탭바와 같은 처세).
    /// 캡슐은 실치수 58pt 높이에 네 항목을 가로로 세우는 면이라, 큰 글자에서 라벨이 들어갈 자리가
    /// 애초에 없다 — 그대로 두면 '홈'은 'H…', 'Fri…'처럼 **잘린 글자**가 되어 큰 글자를 켠 사람에게
    /// 오히려 덜 읽히는 라벨을 준다. 라벨을 지우는 대신 길게 눌러 화면 중앙에 크게 띄우는
    /// Large Content Viewer를 항목마다 걸어 이름을 잃지 않게 한다(아래 `navButton`).
    private var iconOnly: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: ReffiSpace.s3) {
            navItem(.home, ReffiIcon.home, "Home")
            navItem(.fridge, ReffiIcon.fridge, "Fridge")
            actionItem(ReffiIcon.add, "Add")
            navItem(.profile, ReffiIcon.profile, "Profile")
        }
        .padding(.horizontal, ReffiSpace.s5)
        .frame(height: ReffiChrome.navHeight)
        // `.isTabBar` 고지(F53)는 42차에서 시도 후 원복 — XCUITest 요소 재분류로 내비 조회가
        // 깨진다(FridgeTabs 주석 참조). 별도 라운드에서 테스트 계약과 함께 다룬다.
        .navGlass()
        // §6.4의 카드 단(r5/y2)과 같은 잉크 농도의 **의도된 약화 변형**이다 — 떠 있는 요소의
        // 이중 그림자(§6.2)를 쓰면 글래스 캡슐이 카드로 읽힌다(42차: 코드-주석 정합 재서술).
        .shadow(color: ReffiColor.shadowTint.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.bottom, ReffiChrome.navBottom)   // 더 아래로 — 홈 인디케이터 근처
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
            // ＋는 목적지 전환이 아니라 시트를 여는 액션이다(42차·F53) — 탭들과 같은 폼으로 서 있어
            // 힌트가 그 차이를 소리로 보완한다.
            .accessibilityHint(Text("Opens the add sheet"))
    }

    /// 모든 네비 항목 공통 형식 — 아이콘(23) + 라벨(11/caption2 스케일, AX 크기에선 아이콘만).
    private func navButton(icon: Ph, label: LocalizedStringKey, tint: Color, weight: Ph.IconWeight,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: ReffiSpace.s0) {
                icon.reffi(23, weight)
                if !iconOnly {
                    Text(label)
                        .reffiType(.metaText)
                }
            }
            .foregroundStyle(tint)
            // 라벨이 빠지면 보이는 것은 아이콘(23)뿐이라 **손가락이 닿는 면이 같이 줄 위험**이 있다.
            // 그래서 기본 크기의 실치수(52×48)를 유지하되 하한을 §7.3 토큰으로 못 박는다 — tapMin이
            // 언젠가 48로 오르면(토큰 주석 참조) 이 두 값도 같이 따라 올라간다.
            .frame(minWidth: max(52, ReffiChrome.tapMin), minHeight: max(48, ReffiChrome.tapMin))
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        // 길게 누르면 화면 중앙에 아이콘+이름을 크게 띄운다 — 라벨이 숨은 AX 크기에서만 시스템이
        // 켜므로 항상 걸어 둔다. Phosphor는 SF Symbol이 아니라 `systemImage:` 를 못 쓴다 —
        // 이미지 자리에 화면과 **같은 아이콘**(ReffiIcon 경유)을 그대로 넣어야 확대 라벨이
        // 캡슐에 보이는 것과 같은 기호를 보여 준다.
        .accessibilityShowsLargeContentViewer {
            Label {
                Text(label)
            } icon: {
                icon.reffi(23, weight)
            }
        }
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
