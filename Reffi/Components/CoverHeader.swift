import SwiftUI

/// 풀스크린 커버 헤더의 **단일 공급원**(§14.2, 인터랙션 커먼 룰 ②③) — 커버마다 손으로 조립하던 상단 바를 통일한다.
///
/// - **중앙** 타이틀(`.heading`) + (선택)서브타이틀(`.caption`) / 우측 `PaperCloseButton`.
///   시트 헤더(`SheetHeader`)가 **좌측** 타이틀인 것과 의도적으로 대비된다(룰 ③: 커버=중앙 / 시트=좌측).
/// - 좌측에 X와 같은 폭(44)의 투명 균형자를 두어 타이틀을 진짜 중앙에 두고, 긴 텍스트가 X와 겹치지 않게 한다.
/// - 우측 종이 X는 단일 공급원 `PaperCloseButton`을 쓴다(룰 ①). 커버는 X가 유일한 닫기 신호라 항상 노출한다(§14.3).
/// - `accessory` — 타이틀 아래 한 줄 슬롯(경과 시간·진행 힌트 등). 헤더 행이 아니라 **아래**에 두어
///   중앙 컬럼의 좁은 폭(양쪽 44 + 거터)에 눌리지 않게 한다. 애니메이션·표시 조건은 호출부가 게이팅한다.
/// - 타이틀은 2줄까지 접고 그 전에 축소한다(`minimumScaleFactor`) — 중앙 정렬이라 긴 한글 타이틀이
///   X와 부딪히기 쉬운데, 잘라내기보다 줄바꿈·축소를 먼저 쓴다.
/// - **부제도 2줄에서 끊는다.** 제한이 없으면 큰 글씨에서 부제 혼자 헤더를 몇 줄이고 밀어내
///   아래 콘텐츠(티켓 덱의 브리지 행 등)를 덮는다. 두 줄이면 두 방향 안내가 다 들어간다.
struct CoverHeader<Accessory: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    /// 닫기 버튼의 접근성 힌트 — 닫아도 상태가 남는 커버(조리 중 등)에서 결과를 알린다. nil이면 붙이지 않는다.
    var closeHint: LocalizedStringKey?
    let onClose: () -> Void
    let accessory: () -> Accessory

    init(title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         closeHint: LocalizedStringKey? = nil,
         onClose: @escaping () -> Void,
         @ViewBuilder accessory: @escaping () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.closeHint = closeHint
        self.onClose = onClose
        self.accessory = accessory
    }

    var body: some View {
        VStack(spacing: ReffiSpace.s1) {
            HStack(alignment: .center, spacing: 0) {
                Color.clear.frame(width: ReffiChrome.tapMin, height: ReffiChrome.tapMin)   // 우측 X(44)와 대칭 — 타이틀 진짜 중앙
                Spacer(minLength: ReffiSpace.s2)
                VStack(spacing: ReffiSpace.s3) {
                    Text(title)
                        .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                        .lineLimit(2).minimumScaleFactor(0.85)
                    if let subtitle {
                        Text(subtitle).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                            .lineLimit(2)
                    }
                }
                .multilineTextAlignment(.center)
                Spacer(minLength: ReffiSpace.s2)
                closeButton
            }
            accessory()
        }
        .padding(.horizontal, ReffiGrid.margin)
        .padding(.top, ReffiSpace.s4)
        .padding(.bottom, ReffiSpace.s3)
    }

    /// 힌트가 없으면 빈 힌트를 붙이지 않는다(VoiceOver가 공백을 읽지 않게).
    @ViewBuilder private var closeButton: some View {
        if let closeHint {
            PaperCloseButton(action: onClose).accessibilityHint(Text(closeHint))
        } else {
            PaperCloseButton(action: onClose)
        }
    }
}

/// accessory 없는 기본형 — 기존 호출부(History·To buy)는 그대로 쓴다.
extension CoverHeader where Accessory == EmptyView {
    init(title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         closeHint: LocalizedStringKey? = nil,
         onClose: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, closeHint: closeHint,
                  onClose: onClose) { EmptyView() }
    }
}
