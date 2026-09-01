import SwiftUI

/// 커버 헤더 행의 세로 기준선(50차) — **X는 제목에 붙는다.**
///
/// 가이드를 지정하지 않은 형제(= 닫기 X)는 기본값인 자기 중심으로 붙는다. 제목만 이 가이드를
/// 명시적으로 잡으므로, 제목 열이 accessory로 길어져도 X는 열 전체의 중심이 아니라 **제목 옆**에 남는다.
/// (표준 `.center`로 두면 accessory가 붙는 순간 X가 제목과 accessory 사이로 내려간다 —
/// `CoverHeader`가 49차에 부제를 행 밖으로 뺀 이유와 같은 결함이고, 그때는 행의 내용물을 줄여
/// 피했지만 50차에 accessory가 제목과 한 쌍이 되면서 구조로 풀어야 하는 자리가 됐다.)
private enum CoverTitleCenter: AlignmentID {
    static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
}

extension VerticalAlignment {
    /// 커버 헤더 전용 세로 기준 — 제목 블록의 세로 중심.
    static let coverTitle = VerticalAlignment(CoverTitleCenter.self)
}

/// 풀스크린 커버 헤더의 **단일 공급원**(§14.2, 인터랙션 커먼 룰 ②③) — 커버마다 손으로 조립하던 상단 바를 통일한다.
///
/// - **헤더 행은 [제목(+accessory) 열] + 우측 X 둘로 이뤄진다.** 제목은 좌측 `.heading`,
///   X는 단일 공급원 `PaperCloseButton`(룰 ①)이다. 커버는 X가 유일한 닫기 신호라 항상 노출한다(§14.3).
///
///   **49차: 중앙 → 좌측**(오너 지시). 옛 규칙은 "커버=중앙 / 시트=좌측"(룰 ③)이었고 그 대칭을 위해
///   좌측에 44pt 투명 균형자를 세워 두었다. 그러나 커버 본문은 예외 없이 좌측 정렬(티켓 크라운·덱
///   카드·목록 행)이라, 그 화면들의 제목만 중앙에 뜨면 한 화면에 정렬선이 둘 생긴다 — 화면을 오갈수록
///   "자로 안 잰 느낌"으로 쌓이는 종류의 어긋남이다. 균형자를 걷고 제목을 본문과 같은 선에 세워
///   커버·시트·팝업 셋이 **한 축**으로 정렬된다.
///
///   **제목과 X의 세로 중심이 맞는 것은 이제 `.coverTitle` 정렬이 진다**(50차). 옛 골격은 "행의
///   자식이 제목과 X 둘뿐"이라는 사실에 기대 행 높이를 X의 44로 고정하는 방식이었는데, accessory가
///   행 안으로 들어오면서 그 전제가 깨졌다. 정렬을 명시로 바꾸면 열이 얼마나 길어지든 X가 제목에서
///   풀리지 않는다 — 히트 44는 그대로 남으므로 제목이 한 줄일 때의 행 높이(44)도 그대로다.
/// - **`accessory`는 제목 바로 아래, 제목과 `s0` 쌍으로 선다**(50차 오너: "Cooking now 밑에 Started xx가
///   나오는데 이 둘의 스페이스가 너무 커"). 이 자리를 s1(6)에서 s0(2)로 줄이는 것만으로는 부족했다 —
///   진짜 간격은 6이 아니라 **6 + 7.68**이었다: 제목 줄상자(24 × 1.19336 = 28.64)가 X의 44 히트 프레임
///   안에서 가운데 정렬되며 위아래로 7.68씩 슬랙을 만들고, accessory는 그 슬랙 **밖**에서 시작했다.
///   accessory를 제목과 같은 열로 올려 슬랙을 구조에서 없앤다 — 잉크 대 잉크 16.87 → **5.19pt**(§3.5
///   "두 줄 텍스트 쌍" 규약값), 헤더 두께 65.51 → 53.83. 음수 패딩으로 7.68을 상쇄하는 길은 후보가
///   아니다: 접근성 크기에서는 제목 줄상자가 44를 넘어 슬랙이 스스로 사라지므로 상수 오프셋은 그때 과보정된다.
/// - **부제(`.caption`)는 행 밖, 행 아래 전폭이다**(49차). **다시 행 안으로 넣지 말 것** — 위 정렬로
///   반대 근거 ①("X가 두 줄 *사이*에 뜬다")은 해소됐지만 ②는 그대로다: 행 안에 두면 부제가 우측 X와
///   간격에 눌린 좁은 컬럼(393pt 화면에서 309pt)에 갇힌다. 전폭(361pt)으로 옮긴다고 한 줄이 되지는
///   않는다 — 영문 원문도 한국어 번역도 실측상 두 줄이다 — 노리는 것은 줄 수가 아니라 두 줄이 균형
///   있게 갈리는 것이다. 짧은 한 줄인 accessory("Started 3분")는 좁은 컬럼이 무해해 축이 갈린다.
///
///   그 대가로 **부제 쪽에는 위 7.68 슬랙이 남는다**(행 높이가 X의 44로 잡히므로). 부제 간격은
///   `s1 → s0`로만 좁힌다(덱 헤더 기준 잉크 17.11 → 13.11). 이 잔여를 없애려면 부제를 좁은 컬럼으로
///   들이는 수밖에 없고, 그건 49차 판정을 되돌리는 것이다.
/// - **`subtitle`과 `accessory`를 동시에 쓰면 화면·낭독 순서가 제목 → accessory → 부제가 된다.**
///   지금 그런 호출부는 없다(조리 커버=accessory만, 덱 커버=부제만). 둘 다 필요해지는 날에는 순서가
///   맞는지부터 확인하라 — 자동으로 "제목 → 부제 → accessory"가 되지 않는다.
/// - 타이틀은 2줄까지 접고 그 전에 축소한다(`minimumScaleFactor`) — 긴 한글 타이틀이 X와 부딪히기
///   쉬운데, 잘라내기보다 줄바꿈·축소를 먼저 쓴다.
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
        // 바깥 간격은 **행 → 부제** 하나에만 걸린다(제목 ↔ accessory는 안쪽 열이 s0로 직접 쥔다).
        VStack(alignment: .leading, spacing: ReffiSpace.s0) {
            HStack(alignment: .coverTitle, spacing: ReffiSpace.s2) {
                // 제목 + accessory = §3.5의 "두 줄 텍스트 쌍". 이 열에 부제를 더하지 마라(위 주석 ②).
                VStack(alignment: .leading, spacing: ReffiSpace.s0) {
                    Text(title)
                        .reffiType(.heading).foregroundStyle(ReffiColor.ink)
                        .lineLimit(2).minimumScaleFactor(ReffiShrink.subtle)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 로터 "제목" 탐색은 **제목 하나가** 짊어진다(42차에 이 헤더를 쓰는 커버들의 제목이
                        // 로터에서 사라져 있어 트레잇을 달았다). 옛 코드는 제목+부제를 `.combine`으로 한
                        // 정차에 묶어 트레잇을 그 덩어리에 달았는데, 부제가 다른 행으로 나가면 그 덩어리
                        // 자체가 성립하지 않는다 — `SheetHeader`가 이미 쓰는 '제목 단독 `.isHeader`'로 맞춘다.
                        .accessibilityAddTraits(.isHeader)
                        // X가 붙는 기준선 — 제목(한 줄이든 두 줄이든)의 세로 중심.
                        .alignmentGuide(.coverTitle) { $0[VerticalAlignment.center] }
                    accessory()
                }
                closeButton
            }
            if let subtitle {
                Text(subtitle).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                    .lineLimit(2)
                    // 2줄 상한은 유지하되(§14.2 — 상한을 걷으면 브리지 행을 덮는다) 한국어처럼
                    // 원문보다 긴 번역이 상한에 닿으면 뒷문장을 자르는 대신 살짝 줄인다(42차).
                    .minimumScaleFactor(ReffiShrink.subtle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)   // 전폭 — 제목과 같은 좌측선
            }
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
