import SwiftUI

/// 하단 시트의 **유일한 골격**(§14.8 · 61차) — 헤더(`SheetHeader`)·본문·(선택)도킹 CTA·프레젠테이션
/// 모디파이어(핸들·캔버스 배경)를 한 곳에서 세운다. 옛 `ProfilePreferenceSheets`의 private 셸을 앱 전역으로
/// 올린 것이다 — 그 셸이 프로필 시트 4종의 헤더·핸들을 같이 잡아 준 동안, 나머지 여덟 시트는 각자 조립하며
/// 인셋(16·24·28)·헤더 간격(12·20·24)·CTA 바(8·12·24)가 갈렸다.
///
/// **두 가지 크기 모드**(`Sizing`):
/// - `.fills` — detent는 호출부가 정한다(§14.5 정책: `.medium`/`.large`). 본문이 남는 세로를 다 쓴다
///   (ScrollView·List·그리드). 바가 있으면 `dockedCTA`로 safe-area 하단에 도킹된다(페이드 띠 포함).
/// - `.fitted` — **콘텐츠 맞춤 높이.** 헤더+본문+(바)의 고유 높이를 재서 `.height(h)` detent 하나로 올린다.
///   `.height(260)` 같은 매직 넘버(닉네임·알림 시간이 그랬다)는 Dynamic Type에서 조용히 잘렸고,
///   `.medium`은 화면의 절반이라는 뜻일 뿐 콘텐츠와 무관해 스캔 소스 선택이 그 안에서 넘쳤다(캡션 둘째 줄이
///   말줄임으로 사라짐, 61차). 결정이 몇 개뿐인 짧은 시트는 제 키만큼만 선다.
///
/// **인셋 계약.** 셸은 본문에 가로 패딩을 **걸지 않는다** — ScrollView 본문은 스크롤 영역이 시트 전폭이어야
/// 카드 그림자가 안 잘리므로, 본문이 자기 콘텐츠에 `ReffiSheet.inset`을 건다(`.sheetInset()`). 헤더와 바는
/// 셸이 같은 값으로 세우므로 세 자리가 한 선에 선다.
///
/// **바닥 계약.** `.fitted`는 셸이 `ReffiSheet.bottom`을 준다. `.fills` + 바 있음은 `dockedCTA`가 준다.
/// `.fills` + 바 없음은 **본문이 자기 스크롤 콘텐츠 끝에** `ReffiSheet.bottom`을 준다(밖에서 걸면 스크롤
/// 영역이 바닥 위에서 잘려 마지막 행이 시트 바닥 밑으로 못 흐른다).
struct SheetShell<Content: View, Bar: View>: View {
    enum Sizing {
        /// 호출부가 detent를 정한다(§14.5). 본문이 남는 세로를 채운다.
        case fills
        /// 콘텐츠 고유 높이 = 시트 높이. 본문은 스크롤하지 않는 짧은 구성이어야 한다.
        case fitted
    }

    let title: LocalizedStringKey
    var showsClose: Bool = true
    var onClose: (() -> Void)? = nil
    var sizing: Sizing = .fills
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bar: () -> Bar

    @State private var fitHeight: CGFloat = 0

    private var hasBar: Bool { Bar.self != EmptyView.self }

    var body: some View {
        Group {
            switch sizing {
            case .fills:
                fillsBody
            case .fitted:
                fittedBody
            }
        }
        .background(ReffiColor.canvas)
        .presentationDragIndicator(.visible)   // §14.3 룰④ — 핸들 없는 시트를 두지 않는다. 셸이 보증한다.
        .presentationBackground(ReffiColor.canvas)
    }

    private var header: some View {
        SheetHeader(title: title, showsClose: showsClose, onClose: onClose)
    }

    @ViewBuilder private var fillsBody: some View {
        let column = VStack(spacing: 0) {
            header
            content()
        }
        if hasBar {
            column.dockedCTA(over: ReffiColor.canvas, inset: ReffiSheet.inset, bottomInset: ReffiSheet.bottom) {
                bar()
            }
        } else {
            column
        }
    }

    private var fittedBody: some View {
        VStack(spacing: 0) {
            header
            content()
            if hasBar {
                // 스크롤이 없으니 페이드 띠는 필요 없다 — 간격만 도킹 바와 같게(`barTop`) 둬서
                // 같은 성격의 Save 버튼이 `.fills` 시트와 같은 리듬에 선다.
                bar()
                    .padding(.horizontal, ReffiSheet.inset)
                    .padding(.top, ReffiSheet.barTop)
            }
        }
        .padding(.bottom, ReffiSheet.bottom)
        .sheetFitHeight($fitHeight)
        .presentationDetents([ReffiSheet.fitDetent(fitHeight)])
    }
}

extension SheetShell where Bar == EmptyView {
    init(title: LocalizedStringKey,
         showsClose: Bool = true,
         onClose: (() -> Void)? = nil,
         sizing: Sizing = .fills,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.showsClose = showsClose
        self.onClose = onClose
        self.sizing = sizing
        self.content = content
        self.bar = { EmptyView() }
    }
}

extension ReffiSheet {
    /// 콘텐츠 맞춤 detent(§14.5) — 실측이 아직 없으면(첫 프레임) `.medium`으로 서고, 오면 `.height`로 바뀐다.
    static func fitDetent(_ height: CGFloat) -> PresentationDetent {
        height > 0 ? .height(height) : .medium
    }
}

extension View {
    /// 시트 본문의 **좌우 인셋**(§14.8) — `ReffiSheet.inset` 한 선. 호출부가 `ReffiGrid.margin`을 적던 자리다.
    func sheetInset() -> some View {
        padding(.horizontal, ReffiSheet.inset)
    }

    /// **콘텐츠 고유 높이 실측**(§14.5 콘텐츠 맞춤 detent) — 세로를 고유 크기로 고정해(`fixedSize`) 시트 높이에
    /// 되먹임되지 않는 값을 재고, `.height(h)` detent 재료로 넘긴다. 안의 `Spacer`는 최소 길이로 접히므로
    /// 맞춤 시트 본문은 Spacer가 아니라 토큰 간격으로 리듬을 세운다.
    ///
    /// 바깥은 `ScrollView`다(61차 리뷰) — 시트 높이와 콘텐츠가 어긋나는 두 경우를 한 장치로 받는다:
    /// ① 첫 프레임(`.medium` 폴백)이나 시스템이 `.height`를 상한으로 깎았을 때 콘텐츠가 **위에 붙는다**(맨
    /// `frame`이면 가운데 정렬돼 헤더와 X가 위로 잘린다) ② 접근성 글자 크기로 콘텐츠가 최대 detent를 넘으면
    /// 잘리는 대신 **스크롤**된다. 딱 맞을 때는 `basedOnSize`라 바운스도 없어 평소엔 있는지 모른다.
    func sheetFitHeight(_ height: Binding<CGFloat>) -> some View {
        ScrollView {
            fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
