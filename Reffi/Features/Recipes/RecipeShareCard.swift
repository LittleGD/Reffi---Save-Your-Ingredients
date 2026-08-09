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
    let ingredientNames: [String]
    /// 조리 시간(분). 구버전 세션엔 없어 nil이면 줄 자체를 생략한다.
    let minutes: Int?
    let count: Int

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
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "ORDER · FIRED")
                    .reffiType(.monoTicketLabel).foregroundStyle(ReffiColor.urgentDark)
                Spacer()
                Text("\(count) used")
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink2)
            }

            Text(verbatim: recipeName)
                .reffiType(.menuName).foregroundStyle(ReffiColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let minutes {
                Text("\(minutes) min")
                    .reffiType(.metaText)
                    .foregroundStyle(ReffiColor.ink2)
            }

            DashedRule()

            // 티켓 크롬은 형제 라벨(ORDER · FIRED)과 같이 verbatim — 인쇄 문자열이라 번역하지 않는다.
            Text(verbatim: "ON THE TICKET")
                .reffiType(.sectionLabel).foregroundStyle(ReffiColor.ink2)

            VStack(alignment: .leading, spacing: ReffiSpace.s1 + 2) {
                ForEach(Array(ingredientNames.prefix(Self.namePreview).enumerated()), id: \.offset) { _, name in
                    Text(verbatim: name)
                        .reffiType(.checklistItem)
                        .foregroundStyle(ReffiColor.ink)
                        .lineLimit(1).truncationMode(.tail)
                }
                if ingredientNames.count > Self.namePreview {
                    Text("+\(ingredientNames.count - Self.namePreview) more on the ticket")
                        .reffiType(.metaText)
                        .foregroundStyle(ReffiColor.ink2)
                }
            }

            DashedRule()
                .padding(.top, ReffiSpace.s2)

            Text(verbatim: "REFFI · KEEP IT FRESH")
                .reffiType(.monoEyebrow).foregroundStyle(ReffiColor.muted)
        }
        .padding(.horizontal, ReffiSpace.s5)
        .padding(.vertical, ReffiSpace.s5 + 2)
        .background(ReceiptShape(tooth: 9).fill(ReffiColor.paper))
        .overlay(ReceiptShape(tooth: 9).stroke(ReffiColor.ink.opacity(0.07), lineWidth: 1))
        .reffiShadow1()
    }
}
