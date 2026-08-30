import SwiftUI

/// 공유용 레시피 영수증 카드(§13.6) — 조리 티켓(`CookingStepsView.ticket`)과 같은 종이 룩을 그대로
/// 재현한 자체완결형 뷰. `ImageRenderer`로 오프스크린 래스터라이즈해 공유 이미지를 만드는 소스가 된다.
/// 표시 전용 — 버튼 등 인터랙션이 없고 `@Environment` store에 의존하지 않는다(데이터는 전부 파라미터).
///
/// 담는 건 단서까지다: 무엇을(메뉴), 무엇으로(재료 이름 최대 5개), 얼마나(시간). 조리 단계는 싣지 않는다 —
/// 앱 안에서도 단계를 보여주지 않으므로 공유 이미지만 다른 약속을 하면 안 된다.
struct RecipeShareCard: View {
    let recipeName: String
    /// 표시용 재료 이름(전체) — 카드는 앞 5개만 그리고 나머지는 "+N" 줄로 접는다.
    /// **비어 있으면 "ON THE TICKET" 섹션(라벨 + 구분선)을 통째로 생략한다** — 예약 모델 이전(v1)
    /// 세션은 예약 재료가 없어, 그대로 두면 빈 라벨만 남는다.
    let ingredientNames: [String]
    /// 조리 시간(분). 구버전 세션엔 없어 nil이면 줄 자체를 생략한다.
    let minutes: Int?
    /// 소비 확정 예정 재료 수. 0이면 헤더의 "N used"도 생략한다(빈 수치를 인쇄하지 않는다).
    let count: Int
    /// 대표 아이콘 — 이 카드는 표시 전용(데이터는 전부 파라미터)이라 레시피→아이콘 체인은 호출부가 푼다.
    /// 정체(요리 그림/재료 글리프)까지 `RecipeHeroIcon`으로 받는다 — 여기서 카탈로그를 다시 부르면
    /// 커스텀 "김밥"이 공유 카드에서만 티켓과 다른 그림이 된다.
    let icon: RecipeHeroIcon

    private static let cardWidth: CGFloat = 340
    private static let namePreview = 5

    var body: some View {
        ticket
            .padding(ReffiSpace.s5)   // 크림 여백 — 톱니 코너의 투명 부분을 받쳐준다
            .frame(width: Self.cardWidth)
            .background(ReffiColor.canvas)
    }

    private var ticket: some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            // 헤더 — 조리 티켓과 같은 모노 크롬(CookingStepsView.ticket 참고).
            // "N used"는 셀 게 있을 때만 — 예약 모델 이전(v1) 세션은 count가 0이라 "0 used"가 남는다.
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "ORDER · FIRED")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.urgentDark)
                Spacer()
                if count > 0 {
                    Text("\(count) used")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }
            }

            // 메뉴명 + 요리 아이콘 — 조리 티켓과 같은 배치(글 왼쪽·그림 오른쪽). 카드가 340pt로 좁아
            // 아이콘만 한 단계 작게 잡아 같은 시각 비중을 유지한다(`ReffiDishIcon.card`).
            HStack(alignment: .top, spacing: ReffiSpace.s3) {
                Text(verbatim: recipeName)
                    .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: ReffiSpace.s2)
                RecipeHeroIconView(icon: icon)
                    .frame(width: ReffiDishIcon.card, height: ReffiDishIcon.card)
            }

            if let minutes {
                Text("\(minutes) min")
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink2)
            }

            // 재료 블록은 **이름이 있을 때만** 통째로 그린다(라벨·구분선 포함) — 예약 모델 이전 세션엔
            // 예약 재료가 없어, 없으면 빈 "ON THE TICKET" 라벨만 덩그러니 남는다.
            if !ingredientNames.isEmpty {
                ReffiRule(.ticket)

                // 티켓 크롬은 형제 라벨(ORDER · FIRED)과 같이 verbatim — 인쇄 문자열이라 번역하지 않는다.
                Text(verbatim: "ON THE TICKET")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.ink2)

                VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                    ForEach(Array(ingredientNames.prefix(Self.namePreview).enumerated()), id: \.offset) { _, name in
                        Text(verbatim: name)
                            .reffiType(.checklistItem)
                            .foregroundStyle(ReffiColor.ink)
                            .lineLimit(1).truncationMode(.tail)
                    }
                    if ingredientNames.count > Self.namePreview {
                        Text("+\(ingredientNames.count - Self.namePreview) more")
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }

            ReffiRule(.ticket)
                .padding(.top, ReffiSpace.s2)

            Text(verbatim: "REFFI · KEEP IT FRESH")
                .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.muted)
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.ticketTop)
        .background(ReceiptShape(tooth: ReffiTooth.ticket).fill(ReffiColor.paper))
        .overlay(ReceiptShape(tooth: ReffiTooth.ticket).stroke(ReffiColor.paperEdge, lineWidth: 1))
        .reffiShadow1()
    }
}
