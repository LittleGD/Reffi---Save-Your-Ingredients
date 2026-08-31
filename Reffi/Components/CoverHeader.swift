import SwiftUI

/// 풀스크린 커버 헤더의 **단일 공급원**(§14.2, 인터랙션 커먼 룰 ②③) — 커버마다 손으로 조립하던 상단 바를 통일한다.
///
/// - **헤더 행에는 제목과 X만 선다.** 중앙 타이틀(`.heading`) + 우측 `PaperCloseButton`, 좌측엔 X와 같은
///   폭(44)의 투명 균형자. 행의 자식이 이 셋뿐이라 행 높이가 X의 터치 타깃(`ReffiChrome.tapMin`)으로
///   고정되고, 제목과 X의 세로 중심이 **구조적으로** 맞는다 — 제목이 두 줄로 접혀도 둘의 중심은 같다.
///   시트 헤더(`SheetHeader`)가 **좌측** 타이틀인 것과 의도적으로 대비된다(룰 ③: 커버=중앙 / 시트=좌측).
/// - **부제(`.caption`)는 행이 아니라 행 아래 전폭이다. 다시 행 안으로 넣지 말 것.** 행 안에 두면 두 가지가
///   한꺼번에 무너진다: ① 44pt X가 '제목+부제 블록' 전체의 세로 중심에 맞춰져 제목 옆이 아니라 두 줄
///   *사이*에 뜬다(부제 2줄이면 제목 중심보다 24.5pt 아래) ② 부제가 좌우 44 + 거터에 눌린 좁은 중앙
///   컬럼(393pt 화면에서 257pt)에 갇힌다. 전폭(361pt)으로 옮긴다고 한 줄이 되지는 않는다 — 영문 원문도
///   한국어 번역도 실측상 두 줄이다 — 노리는 것은 줄 수가 아니라 **X 정렬이 제목에서 풀리지 않는 것**과
///   두 줄이 균형 있게 갈리는 것이다.
/// - 우측 종이 X는 단일 공급원 `PaperCloseButton`을 쓴다(룰 ①). 커버는 X가 유일한 닫기 신호라 항상 노출한다(§14.3).
/// - `accessory` — 부제 아래 한 줄 슬롯(경과 시간·진행 힌트 등). 부제와 같은 이유로 헤더 행 밖에 산다.
///   애니메이션·표시 조건은 호출부가 게이팅한다.
/// - 타이틀은 2줄까지 접고 그 전에 축소한다(`minimumScaleFactor`) — 중앙 정렬이라 긴 한글 타이틀이
///   X와 부딪히기 쉬운데, 잘라내기보다 줄바꿈·축소를 먼저 쓴다.
/// - **부제도 2줄에서 끊는다.** 제한이 없으면 큰 글씨에서 부제 혼자 헤더를 몇 줄이고 밀어내
///   아래 콘텐츠(티켓 덱의 카드 머리 등)를 덮는다. 두 줄이면 두 방향 안내가 다 들어간다.
/// - **상단 패딩은 `s4`다(`SheetHeader`의 `s5`로 올리지 말 것).** 커버는 노치 바로 아래에서, 시트는
///   그래버 아래에서 시작하는 다른 문맥이고, §14.2가 `s5`를 정본이라 부르는 대상은 `SheetHeader` 하나다.
///   여기서 8pt를 더하면 그 8pt가 헤더 두께로 그대로 남아 아래 콘텐츠(덱 카드·조리 티켓)를 밀어낸다.
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
            // 이 행의 자식은 **균형자·제목·X 셋뿐이어야 한다.** 부제를 여기 되돌리는 순간 행 높이가
            // 제목+부제 블록으로 자라고, `.center` 정렬은 44pt X를 그 블록의 중심(=두 줄 사이)에
            // 앉힌다 — 제목 옆이 아니라. 지금은 행 높이가 X의 44로 바닥이 잡혀 있어 제목이 한 줄이든
            // 두 줄이든 둘의 세로 중심이 같은 점에 온다(`PaperChecklistDialog`가 음수 패딩으로 손보정한
            // 그 문제를, 여기서는 행의 내용물을 줄여 구조로 없앤다).
            HStack(alignment: .center, spacing: 0) {
                Color.clear.frame(width: ReffiChrome.tapMin, height: ReffiChrome.tapMin)   // 우측 X(44)와 대칭 — 타이틀 진짜 중앙
                Spacer(minLength: ReffiSpace.s2)
                Text(title)
                    .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                    .lineLimit(2).minimumScaleFactor(ReffiShrink.subtle)
                    .multilineTextAlignment(.center)
                    // 로터 "제목" 탐색은 **제목 하나가** 짊어진다(42차에 이 헤더를 쓰는 커버들의 제목이
                    // 로터에서 사라져 있어 트레잇을 달았다). 옛 코드는 제목+부제를 `.combine`으로 한
                    // 정차에 묶어 트레잇을 그 덩어리에 달았는데, 부제가 다른 행으로 나가면 그 덩어리
                    // 자체가 성립하지 않는다 — `SheetHeader`가 이미 쓰는 '제목 단독 `.isHeader`'로 맞춘다.
                    // 요소 수는 1→2로 늘지만 읽기 순서(제목 → 부제)와 로터 도달성은 그대로다.
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: ReffiSpace.s2)
                closeButton
            }
            if let subtitle {
                Text(subtitle).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    .lineLimit(2)
                    // 2줄 상한은 유지하되(§14.2 — 상한을 걷으면 브리지 행을 덮는다) 한국어처럼
                    // 원문보다 긴 번역이 상한에 닿으면 뒷문장을 자르는 대신 살짝 줄인다(42차).
                    .minimumScaleFactor(ReffiShrink.subtle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)   // 전폭 — 헤더 행의 좁은 중앙 컬럼(257pt)에서 풀려난다
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
