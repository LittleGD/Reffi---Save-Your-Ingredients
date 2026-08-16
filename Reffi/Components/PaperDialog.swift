import SwiftUI

/// 종이 다이얼로그(§14.7) — 앱의 종이 언어로 된 확인·질문 팝업. 시스템 `.alert`을 대체한다.
///
/// **왜 시스템 알림이 아니라 오버레이인가 — 두 가지 이유가 겹친다.**
/// ① 생김새: 크림 종이 · 손으로 그린 듯한 테두리 · 종이컷 버튼으로 이뤄진 화면 한복판에 iOS 기본
/// 알림이 뜨면 그 순간만 다른 앱이 된다. ② 프레젠테이션: 풀스크린 커버 **안에서** 시스템 알림을 띄우면
/// 알림 해체 전환이 부모 커버의 닫기 요청과 겹쳐 UIKit이 그 요청을 삼킨다 — 10차(`26dac5d`)에서 실측했고
/// 0.6초 지연으로 우회해야 했다. 오버레이는 같은 뷰 트리 안이라 전환 큐 자체가 없어 그 경쟁이 성립하지 않는다.
///
/// 문법은 판정 커버(`DecisionCover`)와 같은 계열이다: `scrim` 딤 + `PaperRect` 종이 카드 + 종이컷 버튼.
/// **`ReceiptShape`(톱니 영수증)를 쓰지 않는 건 의도**다 — 티켓 덱 위에 뜨는 팝업이 톱니를 두르면
/// "티켓이 한 장 더 나온 것"으로 읽힌다. 다이얼로그는 티켓이 아니라 **묻는 종이**다.
struct PaperDialog: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    /// 종이 삐뚤빼뚤함의 시드 — 같은 화면에 두 다이얼로그가 이어 뜰 때 서로 다른 종이로 보이게 한다.
    var seed: Int = 0
    /// 오른쪽(1차) 행동 — 항상 있다. 알림형은 이것 하나뿐이다.
    let primary: PaperDialogAction
    /// 왼쪽(2차) 행동 — 있으면 질문형(취소/실행 한 줄).
    var secondary: PaperDialogAction?
    /// 딤(바깥) 탭 — nil이면 **무시**한다. 호출부가 의식적으로 정하도록 기본값을 두지 않았다.
    var onBackdropTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 등장 팝(§7.5) — 판정 커버와 같은 방식으로 카드만 튀어 오른다.
    @State private var shown = false
    /// VoiceOver 포커스를 제목으로 옮긴다 — 모달이 떴는데 포커스가 뒤 화면에 남으면 존재를 모른다.
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            ReffiColor.scrim.ignoresSafeArea()
                .opacity(shown ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { onBackdropTap?() }
                // 딤은 시각 요소다 — 라벨을 달면 VoiceOver에 정체불명의 요소가 하나 늘어난다.
                // 바깥 탭의 접근성 대응은 아래 `.escape` 액션이 맡는다(호출부가 준 행동과 같은 것).
                .accessibilityHidden(true)
            card
                .scaleEffect(shown ? 1 : 0.85)
                .opacity(shown ? 1 : 0)
        }
        // 뒤 화면을 VoiceOver에서 가린다 — 모달이 뜬 동안 티켓 덱을 훑을 수 있으면 모달이 아니다.
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { (onBackdropTap ?? primary.handler)() }
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(ReffiMotion.pop) { shown = true } }
            titleFocused = true
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s5) {
            VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                Text(title)
                    .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                if let message {
                    Text(message)
                        .reffiType(.body).foregroundStyle(ReffiColor.ink2)   // §2.6 소형 텍스트는 불투명 토큰
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            buttons
        }
        .padding(ReffiSpace.s5)
        .background {
            let shape = PaperRect(cornerRadius: ReffiRadius.xl, seed: seed)
            shape.fill(ReffiColor.paper).paperEdge(shape, tint: ReffiColor.ink.opacity(0.06))
        }
        .reffiShadow1()
        .padding(.horizontal, ReffiSpace.s6)
        // 큰 화면에서 카드가 통째로 늘어나면 문장이 한 줄로 길어져 읽는 눈이 멀리 이동한다.
        .frame(maxWidth: 420)
    }

    /// 버튼 줄 — 종이컷 CTA(`PaperButton`)를 그대로 쓴다. 새 버튼 어휘를 만들지 않는다.
    /// 순서는 **취소 왼쪽 · 실행 오른쪽**(시스템 알림과 같은 손 방향이라 근육 기억이 깨지지 않는다).
    /// 세로 패딩 s4 + subhead 한 줄이면 실측 높이가 44pt를 넘는다(§7.3 터치 타깃).
    private var buttons: some View {
        HStack(spacing: ReffiSpace.s3) {
            if let secondary {
                PaperButton(title: secondary.title, kind: .secondary, seed: seed &+ 5, action: secondary.handler)
            }
            PaperButton(title: primary.title, kind: .primary, seed: seed &+ 2, action: primary.handler)
        }
    }
}

/// 종이 다이얼로그의 버튼 하나 — 문구와 그때 할 일.
struct PaperDialogAction {
    let title: LocalizedStringKey
    let handler: () -> Void

    init(_ title: LocalizedStringKey, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}

extension View {
    /// 종이 다이얼로그를 이 뷰 위에 얹는다 — `.alert(_:isPresented:)`와 **같은 자리·같은 모양**으로 쓴다.
    ///
    /// 버튼을 누르면 `isPresented`를 먼저 내리고 행동을 실행한다(시스템 알림의 순서와 같다).
    /// 두 장을 이어 띄우는 흐름도 그대로 성립한다 — 프레젠테이션 큐가 아니라 오버레이라,
    /// 첫 장을 내리는 것과 둘째 장을 올리는 것이 **같은 업데이트**에서 처리된다(전환이 겹칠 일이 없다).
    ///
    /// - Parameter backdropDismisses: 딤(바깥) 탭을 취소로 볼 것인가. 기본은 **무시**다 —
    ///   되돌릴 게 없는 알림형에서 바깥 탭으로 흐름이 조용히 끝나면, 사용자는 무슨 일이 일어났는지
    ///   모른 채 다음 질문을 못 받는다. 질문형(취소가 있는 쪽)에서만 켜서 취소와 같은 뜻으로 쓴다.
    func paperDialog(isPresented: Binding<Bool>,
                     title: LocalizedStringKey,
                     message: LocalizedStringKey? = nil,
                     seed: Int = 0,
                     backdropDismisses: Bool = false,
                     primary: PaperDialogAction,
                     secondary: PaperDialogAction? = nil) -> some View {
        modifier(PaperDialogModifier(isPresented: isPresented,
                                     title: title,
                                     message: message,
                                     seed: seed,
                                     backdropDismisses: backdropDismisses,
                                     primary: primary,
                                     secondary: secondary))
    }
}

private struct PaperDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let seed: Int
    let backdropDismisses: Bool
    let primary: PaperDialogAction
    let secondary: PaperDialogAction?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    PaperDialog(title: title,
                                message: message,
                                seed: seed,
                                primary: wrapped(primary),
                                secondary: secondary.map(wrapped),
                                // 바깥 탭은 **취소와 같은 것**이어야 한다 — 다른 결과를 내면
                                // 실수로 닫은 사용자가 의도하지 않은 행동을 하게 된다.
                                onBackdropTap: backdropDismisses ? { close(then: (secondary ?? primary).handler) } : nil)
                        .transition(.opacity)
                }
            }
            // 딤의 등장·소멸만 여기서(카드의 팝은 다이얼로그가 스스로 한다). 이탈은 §7대로 더 빠르게.
            .animation(ReffiMotion.gated(.easeOut(duration: ReffiMotion.dur2), reduce: reduceMotion),
                       value: isPresented)
    }

    private func wrapped(_ action: PaperDialogAction) -> PaperDialogAction {
        PaperDialogAction(action.title) { close(then: action.handler) }
    }

    /// 먼저 내리고, 그 다음에 행동한다 — 행동이 다음 다이얼로그를 띄우더라도 같은 업데이트에서 교대된다.
    private func close(then handler: @escaping () -> Void) {
        isPresented = false
        handler()
    }
}
