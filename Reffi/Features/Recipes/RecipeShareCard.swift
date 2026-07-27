import SwiftUI

/// 공유용 레시피 영수증 카드(§13.6) — 조리 티켓(`CookingStepsView.ticket`)과 같은 종이 룩을 그대로
/// 재현한 자체완결형 뷰. `ImageRenderer`로 오프스크린 래스터라이즈해 공유 이미지를 만드는 소스가 된다.
/// 표시 전용 — 체크박스·버튼 등 인터랙션이 없고 `@Environment` store에 의존하지 않는다(데이터는 전부 파라미터).
struct RecipeShareCard: View {
    let recipeName: String
    let steps: [String]
    let count: Int

    private static let cardWidth: CGFloat = 340

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

            DashedRule()

            Text(verbatim: "STEPS")
                .reffiType(.sectionLabel).foregroundStyle(ReffiColor.ink2)

            if steps.isEmpty {
                Text("No steps on this ticket. Cook it your way.")
                    .reffiType(.body).foregroundStyle(ReffiColor.ink2)
                    .padding(.vertical, ReffiSpace.s3)
            } else {
                VStack(alignment: .leading, spacing: ReffiSpace.s1) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        stepRow(index: i, text: step)
                    }
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

    /// 단계 한 줄 — 순수 번호+텍스트. 체크박스·취소선·탭 인터랙션은 없음(표시 전용, `CookingStepsView.stepRow` 참고).
    private func stepRow(index: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s3) {
            Text(verbatim: "\(index + 1).")
                .font(.reffiNum(14, relativeTo: .body)).foregroundStyle(ReffiColor.ink2)
            Text(verbatim: text)
                .reffiType(.checklistItem)
                .foregroundStyle(ReffiColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
