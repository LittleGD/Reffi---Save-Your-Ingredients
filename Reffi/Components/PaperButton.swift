import SwiftUI

/// 종이컷 버튼의 **표면(라벨)만** 떼어낸 조각 — `Button`이 아닌 컨트롤(`PhotosPicker`·`ShareLink` 등)에도
/// 같은 CTA 재질을 씌우기 위한 공유 프리미티브다. 호출부는 `.buttonStyle(.paperPress)`를 함께 걸어
/// 종이 프레스까지 맞춘다(선례: `CookingStepsView`의 ShareLink + `PaperIconLabel`).
///
/// 면 규격은 `PaperButton`과 **한 곳**에서 나온다 — 손으로 재조립하면 fill 토큰·질감·그림자가
/// 화면마다 갈려 앱에 secondary CTA가 두 종류로 보인다(감사 R4-2).
struct PaperButtonLabel: View {
    enum Kind { case primary, secondary }

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    /// 지금 이 버튼이 일하는 중인가 — **라벨을 갈아 끼우지 않고 옆에 스피너를 세운다**(§7.2).
    /// 문구를 통째로 바꿔 버리면 방금 누른 것이 무엇이었는지가 화면에서 사라지고, 디밍만으로는
    /// "조건 미충족이라 못 누름"과 구분되지 않는다. 문구는 호출부가 동작 지목형으로 바꾼다.
    var isBusy: Bool = false

    private var fill: Color { kind == .primary ? ReffiColor.blue : ReffiColor.sub }
    private var foreground: Color { kind == .primary ? .white : ReffiColor.ink }

    var body: some View {
        HStack(spacing: ReffiSpace.s2) {
            Text(title)
                .font(ReffiTextRole.subhead.font)
                .tracking(ReffiTextRole.subhead.tracking)
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(foreground)   // 스피너 잉크는 라벨과 같은 색 — 면 위에서 한 덩어리로 읽힌다
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s4)
        .background { surface }
    }

    private var surface: some View {
        let shape = PaperCutRect(seed: seed)   // 아이콘 버튼(9각형)과 같은 종이컷 8각형 계열
        return shape.fill(fill)                // 솔리드(그라데이션 없음)
            .overlay(PaperGrain(seed: UInt64(seed) &+ 11).clipShape(shape))   // 종이 질감
            .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill, width: 1)
            .compositingGroup()
            .reffiShadow1()
    }
}

/// 종이컷 버튼 — 와이드 1차 CTA(§13). 모서리 잘린 길쭉한 **8각형**(`PaperCutRect`) **솔리드** 면 +
/// **종이 질감**(`PaperGrain`) + 통통 프레스(`paperPress`). 아이콘·그라데이션 없음(텍스트만).
struct PaperButton: View {
    typealias Kind = PaperButtonLabel.Kind

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    /// 진행 중 표시 — 라벨 옆 스피너(`PaperButtonLabel.isBusy`). 기본값이 있어 기존 호출부는 그대로다.
    var isBusy: Bool = false
    let action: () -> Void

    /// `.disabled(_:)`가 걸리면 투명도만 낮춰 "지금 못 누름"을 보인다(§7.2 disabled = opacity .45, 색 변경 X).
    /// 디밍은 **여기 한 곳**에서만 한다 — 호출부가 `.opacity(...)`를 겹쳐 걸면
    /// `\.isEnabled`가 하위로 전파되며 두 값이 곱해져(0.45 × 0.5 = 0.225) CTA 텍스트가 소실된다.
    /// 걸리지 않은 기존 호출부엔 영향이 없다(enabled = 1).
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            PaperButtonLabel(title: title, kind: kind, fullWidth: fullWidth, seed: seed, isBusy: isBusy)
        }
        .buttonStyle(.paperPress)
        .opacity(isEnabled ? 1 : ReffiOpacity.disabled)
    }
}

extension View {
    /// **풀스크린 커버의 하단 도킹 CTA**(§13.6) — 확정 액션을 safe-area 하단에 붙이고 본문만 스크롤시킨다.
    /// 메인(`Start cooking`)·시트(`Add N items`)가 이미 쓰던 "하단에 CTA가 고정된다"는 관례를 커버까지
    /// 넓히는 한 곳이다 — 커버마다 손으로 조립하면 페이드 높이·여백이 화면별로 갈린다.
    ///
    /// `surface`는 그 화면의 바탕색이다(커버는 저마다 다르다 — 조리 = `paperPass`, To buy = 글래스 위 `canvas`).
    /// 바 위쪽 `s6` 띠는 그 색으로의 페이드고 그 아래는 불투명 면이라, 콘텐츠가 짧아 스크롤이 없을 때도
    /// CTA가 허공에 뜨지 않고 바닥에 붙은 종이로 읽힌다(냉장고 하단 마스크와 같은 어휘, `FridgeView`).
    /// 홈 인디케이터까지 면이 이어지도록 배경만 safe area를 무시한다 — 버튼 자체는 safe area 안에 남는다.
    ///
    /// `bottomInset`은 **바 아래로 남길 여백**이다. 커버는 화면 바닥을 통째로 쓰므로 기본 `s3`이지만,
    /// 냉장고 To buy 탭처럼 **떠 있는 캡슐 네비가 있는 화면**에 얹을 때는 그 자리(`ReffiChrome.navReserve`)를
    /// 비워야 CTA가 네비 밑에 깔리지 않는다. 값만 바꾸고 페이드·불투명 면 구성은 한 곳에 남긴다.
    func dockedCTA<Bar: View>(over surface: Color,
                              bottomInset: CGFloat = ReffiSpace.s3,
                              @ViewBuilder bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            bar()
                .padding(.horizontal, ReffiGrid.margin)
                .padding(.top, ReffiSpace.s6)     // 페이드 띠 높이와 같다 — 버튼은 불투명 면 위에서 시작한다
                .padding(.bottom, bottomInset)
                .background {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [surface.opacity(0), surface],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: ReffiSpace.s6)
                        surface
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                }
        }
    }
}
