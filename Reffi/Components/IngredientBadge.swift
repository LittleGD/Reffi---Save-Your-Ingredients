import SwiftUI
import PhosphorSwift

/// 재료 뱃지(§13) — 실루엣이 정착해 모핑되는 형태. 캡슐이 아니라 **종이 둥근 사각**(`PaperRect`),
/// 재료명 **왼쪽에 인디케이터 바**(둥근 직사각, 신선도색). 탭 = Ate/Tossed 판정 묻기.
/// 히트 영역은 최소 44pt(§7.3), 시각은 그대로.
struct IngredientBadge: View {
    let ingredient: Ingredient
    var seed: Int = 0
    /// 오늘 요리 핀(47차) — 홈 오른쪽 존 드래그인으로 꽂힌 상태. 정본은 `FridgeStore.pinnedIDs`고
    /// 배지는 표시만 한다(좌상단 압정 마크 + 낭독 접두).
    var pinned: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        let f = ingredient.freshness
        Button(action: onTap) {
            HStack(spacing: ReffiSpace.s2) {
                // 신선도 그룹(좌측) — 인디케이터 바 + 남은 기간(D-N)을 하나로 묶는다.
                HStack(spacing: ReffiSpace.s1) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(f.dark)
                        .frame(width: 4, height: 14)
                    Text(verbatim: ingredient.dDayText)
                        // D-day는 ko에서 "오늘"·"3일"로 흐른다 — 한글 폴백 오버로드(§3.4·42차).
                        .font(.reffiNum(.meta, for: ingredient.dDayText))
                        .foregroundStyle(f.dark)
                }
                Text(verbatim: ingredient.displayName)
                    .reffiType(.badgeLabel)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
            }
            // 42차 — 스케일 밖 값(10·14) 정리: 좌우 대칭 s3, 형제 `AddBadge`와 같은 리듬.
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background { surface }
            // 핀 마크(47차) — 종이 **모서리에 꽂힌 압정**. 배지 안은 좌변(인디케이터 바)이
            // 이미 신선도의 자리라, 안쪽 어디에 넣어도 바·D-N·이름 중 하나와 폭을 다툰다 —
            // 종이 밖 좌상단 모서리에 살짝 걸치면(오프셋) 아무와도 겹치지 않고 "메모지에
            // 압정"이라는 실물 은유 그대로다. 행이 `scrollClipDisabled`라 걸친 몫도 잘리지 않는다.
            .overlay(alignment: .topLeading) {
                if pinned {
                    ReffiIcon.pin.reffi(12, .fill)
                        .foregroundStyle(ReffiColor.ink)
                        .offset(x: -4, y: -6)
                }
            }
            .frame(minHeight: ReffiChrome.tapMin)              // §7.3 최소 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        // 화면의 "3d"는 뱃지 폭에 맞춘 축약이라 소리로는 뜻이 서지 않는다 — 읽을 때는 풀어 쓴다.
        // 데이터(이름·기한 문구)를 잇는 문장이라 `verbatim` — 보간을 그냥 `Text(_:)`에 넣으면
        // "%@, %@"라는 키로 카탈로그를 뒤지고, 없어서 폴백으로만 맞는 자리가 된다(§i18n).
        // 핀은 **접두**다(47차) — 목록을 훑는 낭독에서 상태가 이름보다 먼저 들려야 구분이 선다.
        // "Pinned"만 카탈로그 키고 나머지는 데이터 연결이라 verbatim 그대로.
        .accessibilityLabel(pinned
            ? Text("Pinned") + Text(verbatim: ", \(ingredient.displayName), \(ingredient.dDayAccessibilityText)")
            : Text(verbatim: "\(ingredient.displayName), \(ingredient.dDayAccessibilityText)"))
        .accessibilityHint(Text("Decide: eaten or tossed?"))
    }

    private var surface: some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
        return shape
            .fill(ReffiColor.paper)
            .paperEdge(shape)
            .reffiShadow1()
    }
}

/// 추가 뱃지 — 점선 종이 사각의 ＋. 탭하면 영수증 스캔 시트(`AddIngredientSheet` → `ReceiptScanView`)로.
struct AddBadge: View {
    var seed: Int = 1
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ReffiSpace.s1) {
                ReffiIcon.add.reffi(15, .bold)
                Text("Add")
                    .reffiType(.badgeLabel)
            }
            .foregroundStyle(ReffiColor.ink2)
            .padding(.horizontal, ReffiSpace.s3)
            .padding(.vertical, ReffiSpace.s2)
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
                shape.stroke(ReffiColor.muted.opacity(0.7),
                             style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            .frame(minHeight: ReffiChrome.tapMin)              // §7.3 최소 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Add ingredients"))
    }
}
