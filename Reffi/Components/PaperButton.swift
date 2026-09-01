import SwiftUI
import PhosphorSwift

/// 종이컷 버튼의 **표면(라벨)만** 떼어낸 조각 — `Button`이 아닌 컨트롤(`PhotosPicker`·`ShareLink` 등)에도
/// 같은 CTA 재질을 씌우기 위한 공유 프리미티브다. 호출부는 `.buttonStyle(.paperPress)`를 함께 걸어
/// 종이 프레스까지 맞춘다(선례: `CookingStepsView`의 ShareLink + `PaperIconLabel`).
///
/// 면 규격은 `PaperButton`과 **한 곳**에서 나온다 — 손으로 재조립하면 fill 토큰·질감·그림자가
/// 화면마다 갈려 앱에 secondary CTA가 두 종류로 보인다(감사 R4-2).
struct PaperButtonLabel: View {
    /// `destructive`(2026-08, 35차) — urgent 계열 솔리드 면. urgent(파스텔)가 아니라 **urgentDark**를
    /// 쓴다: §2.6 실측표의 "각 색-dark 솔리드 + white = AA+"(urgent 5.92) 행이 정확히 이 조합이다 —
    /// 파스텔 `urgent` 위에 흰 글자를 얹는 건 §2.6이 명시적으로 금지한다("따뜻한 파스텔 면 위 글자는
    /// ink, 흰 글자 금지"). `blue`(면 전용)와 같은 축의 "채운 면" 색이라 취급한다.
    enum Kind { case primary, secondary, destructive }

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    /// **선행 아이콘**(49차) — 라벨 왼쪽에 20pt 글리프를 세운다. 없으면(기본) 텍스트 전용 그대로다.
    ///
    /// 이 슬롯이 없던 동안 아이콘이 필요한 CTA는 **표면을 손으로 다시 조립**했고(조리 티켓의 영상
    /// 버튼이 그랬다: `PaperCutRect` + 틴트 면 + 강조 단면 + 그레인을 콜사이트에서 재조립),
    /// 그 결과 앱에 정본이 그리지 않는 네 번째 CTA 재질(반투명 면 + 아웃라인)이 생겼다 — §13.5가
    /// "표면을 손으로 재조립하지 않는다"로 금지한 바로 그 상태다. 아이콘 하나 때문에 표면을 복제하는
    /// 길을 막으려면 표면 쪽이 아이콘을 받아야 한다.
    ///
    /// 색은 라벨과 **같은** `foreground`다 — 아이콘만 다른 색으로 두면 버튼 하나가 두 톤으로 읽히고,
    /// 브랜드 글리프(유튜브 등)를 그 브랜드 색으로 칠하면 §2.4의 "신선도 색은 신선도에만"과 충돌한다
    /// (식별은 글리프 형태가 맡는다).
    var icon: Ph? = nil
    /// 아이콘 웨이트 — 기본은 `.regular`(§5 "SVG 라인/플랫 아이콘만"의 결). `.fill`은 유튜브처럼
    /// **채운 형태 자체가 식별 표지인 브랜드 마크**에만 쓴다 — 기능 아이콘을 채우면 라벨 옆에
    /// 검은 덩어리가 생겨 버튼 하나 안에서 잉크 무게가 두 단으로 갈린다.
    var iconWeight: Ph.IconWeight = .regular
    /// 지금 이 버튼이 일하는 중인가 — **라벨을 갈아 끼우지 않고 옆에 스피너를 세운다**(§7.2).
    /// 문구를 통째로 바꿔 버리면 방금 누른 것이 무엇이었는지가 화면에서 사라지고, 디밍만으로는
    /// "조건 미충족이라 못 누름"과 구분되지 않는다. 문구는 호출부가 동작 지목형으로 바꾼다.
    var isBusy: Bool = false
    /// 이 버튼이 **종이 카드 위**에 앉는가(§2.8·42차) — secondary 면은 부모가 캔버스냐 카드냐로
    /// 토큰이 갈린다(`sub`는 캔버스 전용, 카드 위에선 다크에서 1.04로 사라진다 → `subRaised`).
    /// `PaperDialog`처럼 종이 카드 안에서 버튼을 세우는 호출부만 켠다.
    var onCard: Bool = false
    /// **보조 줄**(49차) — 라벨 아래 한 줄로 "이 버튼을 누르면 무엇이 처리되는가"를 인쇄한다.
    /// 동사만 있는 CTA는 결과를 눌러 봐야 알 수 있어, 화면의 유일한 결정 지점에 결정의 대상이
    /// 빠져 있는 상태가 된다(레퍼런스 감사: 하단 도킹 바는 동사 옆에 그 동사가 처리할 상태를 함께 찍는다).
    ///
    /// **색은 라벨과 같은 `foreground`다 — 새 토큰을 만들지 않는다.** §2.6이 "Blue 면 위 글자는
    /// white"를 못 박고 §10이 "불투명도로 글자색을 만들지 않는다"를 금지하므로, 이 자리에서 톤을
    /// 낮추는 유일한 합법 수단은 **크기와 굵기**다: `subhead`(18/SemiBold) → `metaText`(13/Medium)로
    /// 1.38배 + 한 단계 굵기 차를 두면 색을 건드리지 않고 위계가 선다. 흰 글자 대비는 두 줄 모두
    /// 같다(§2.8 실측 white on blue 라이트 5.65 · 다크 4.64 — 13pt 본문 요건 4.5를 넘는다).
    var subtitle: LocalizedStringKey? = nil
    /// **컴팩트 칩 폼**(49차) — 같은 종이 표면을 라벨 한 단(`pillLabel` 13) · 아이콘 16 · 패딩
    /// `s3/s2`로 줄인 변형. 와이드 CTA가 아니라 **보조 행동 여럿이 한 줄에 서는 자리**를 위한 것이다:
    /// 선택적 유틸리티 셋을 전폭 버튼으로 쌓으면 카드 세로의 3분의 1을 먹고 1차 행동(도킹 CTA)과
    /// 무게가 겨룬다(레퍼런스: Beli·CREME의 제목 아래 칩 행). 표면·시드·프레스는 그대로라
    /// 재질이 갈리지 않는다 — 크기만 한 단 내린 같은 종이다.
    /// 시각 높이는 34pt대로 내려가지만 히트 영역은 호출부가 `ReffiChrome.tapMin`으로 넓힌다(§7.3).
    var compact: Bool = false

    private var fill: Color {
        switch kind {
        case .primary: ReffiColor.blue
        case .secondary: onCard ? ReffiColor.subRaised : ReffiColor.sub
        case .destructive: ReffiColor.urgentDark
        }
    }
    // `blue` 면 위 콘텐츠는 `onAccent`(§2.7 — 흰색 근거가 blue의 다크 L 상한 .565에 묶여 있다).
    // `urgentDark`는 다크에서 L .74로 **밝게 뒤집히는** 면이라 고정 흰색을 얹으면 2.43:1로 무너진다 —
    // 그 위 콘텐츠는 `onInk`다(라이트 흰색 그대로 5.92, 다크 7.14 — `PaperDayChip`이 먼저 실측한 짝).
    private var foreground: Color {
        switch kind {
        case .primary: ReffiColor.onAccent
        case .destructive: ReffiColor.onInk
        case .secondary: ReffiColor.ink
        }
    }

    var body: some View {
        VStack(spacing: ReffiSpace.s0) {
            titleRow
            if let subtitle {
                Text(subtitle)
                    .font(ReffiActionRole.metaText.font)
                    .tracking(ReffiActionRole.metaText.tracking)
                    .lineLimit(1)
                    .minimumScaleFactor(ReffiShrink.chrome)
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, compact ? ReffiSpace.s3 : ReffiSpace.s5)
        // 보조 줄이 서면 세로 패딩을 한 단 줄여 총높이를 흡수한다 — `ReffiChrome.navReserve`가
        // CTA 높이에서 파생되지 않지만, 도킹 바가 갑자기 두꺼워지면 그 위 콘텐츠 예산이 흔들린다.
        .padding(.vertical, compact ? ReffiSpace.s2 : (subtitle == nil ? ReffiSpace.s4 : ReffiSpace.s3))
        .background { surface }
    }

    private var titleRow: some View {
        HStack(spacing: compact ? ReffiSpace.s1 : ReffiSpace.s2) {
            if let icon {
                // 장식이 아니라 라벨의 동반 기호다 — 라벨이 이미 뜻을 말하므로 보조기술에선 숨긴다.
                icon.reffi(compact ? 16 : 20, iconWeight).accessibilityHidden(true)
            }
            Text(title)
                .font(compact ? ReffiActionRole.pillLabel.font : ReffiTextRole.subhead.font)
                .tracking(compact ? ReffiActionRole.pillLabel.tracking : ReffiTextRole.subhead.tracking)
                .lineLimit(1)
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(foreground)   // 스피너 잉크는 라벨과 같은 색 — 면 위에서 한 덩어리로 읽힌다
            }
        }
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
/// **종이 질감**(`PaperGrain`) + 통통 프레스(`paperPress`). 그라데이션 없음. 선행 아이콘은 선택(49차 `icon:`).
struct PaperButton: View {
    typealias Kind = PaperButtonLabel.Kind

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    /// 선행 아이콘 — `PaperButtonLabel.icon` 그대로 전달(49차).
    var icon: Ph? = nil
    /// 아이콘 웨이트 — `PaperButtonLabel.iconWeight` 그대로 전달(49차).
    var iconWeight: Ph.IconWeight = .regular
    /// 진행 중 표시 — 라벨 옆 스피너(`PaperButtonLabel.isBusy`). 기본값이 있어 기존 호출부는 그대로다.
    var isBusy: Bool = false
    /// 종이 카드 위에 앉는 버튼인가 — `PaperButtonLabel.onCard` 그대로 전달(§2.8·42차).
    var onCard: Bool = false
    /// 컴팩트 칩 폼 — `PaperButtonLabel.compact` 그대로 전달(49차). 히트 영역은 여기서 §7.3까지 넓힌다.
    var compact: Bool = false
    /// 보조 줄 — `PaperButtonLabel.subtitle` 그대로 전달(49차).
    var subtitle: LocalizedStringKey? = nil
    let action: () -> Void

    /// `.disabled(_:)`가 걸리면 투명도만 낮춰 "지금 못 누름"을 보인다(§7.2 disabled = opacity .45, 색 변경 X).
    /// 디밍은 **여기 한 곳**에서만 한다 — 호출부가 `.opacity(...)`를 겹쳐 걸면
    /// `\.isEnabled`가 하위로 전파되며 두 값이 곱해져(0.45 × 0.5 = 0.225) CTA 텍스트가 소실된다.
    /// 걸리지 않은 기존 호출부엔 영향이 없다(enabled = 1).
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            PaperButtonLabel(title: title, kind: kind, fullWidth: fullWidth, seed: seed,
                             icon: icon, iconWeight: iconWeight,
                             isBusy: isBusy, onCard: onCard, subtitle: subtitle, compact: compact)
                // 컴팩트는 시각 34pt대라 히트가 §7.3 하한에 못 미친다 — 면은 그대로 두고 타깃만 넓힌다
                // (`HistoryView` 힌트 X가 쓰는 "시각 30 / 히트 44"와 같은 처세).
                .frame(minHeight: compact ? ReffiChrome.tapMin : nil)
                .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .opacity(isEnabled ? 1 : ReffiOpacity.disabled)
        // §7.2 표가 disabled 행에 명시한 그 전환(dur1 · ease-std) — 값(0.45)만 토큰이고 전환이
        // 빠져 있어, 폼을 채우다 CTA가 살아나는 가장 흔한 상태 변화만 앱의 시계 밖에서 튀었다.
        .animation(ReffiMotion.gated(ReffiMotion.press, reduce: reduceMotion), value: isEnabled)
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
