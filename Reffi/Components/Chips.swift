import SwiftUI
import PhosphorSwift

/// AI/레시피 라벨 — 시간 라벨(MetaChip)과 동일 포맷: 인라인 아이콘 + 텍스트, 면 없이 ink-2.
struct AITag: View {
    var text: String = "AI 추천 · 오늘의 레시피"
    var body: some View {
        HStack(spacing: ReffiSpace.s1) {
            ReffiIcon.ai.reffi(15)
            Text(text)
                .font(ReffiTextRole.caption.font)
                .tracking(ReffiTextRole.caption.tracking)
        }
        .foregroundStyle(ReffiColor.ink2)
    }
}

/// 신선도 칩 — light 틴트 면 + ink 글자(AAA), D-N은 색-dark(§2.6). 임박 재료 표시용.
struct FreshnessChip: View {
    let ingredient: Ingredient
    var body: some View {
        let f = ingredient.freshness
        HStack(spacing: ReffiSpace.s1) {
            Text(ingredient.name)
                .font(ReffiTextRole.caption.font)
                .tracking(ReffiTextRole.caption.tracking)
                .foregroundStyle(ReffiColor.ink)
            Text(ingredient.dDayText)
                .font(.reffiNum(13, relativeTo: .caption))
                .foregroundStyle(f.dark)
        }
        .padding(.horizontal, ReffiSpace.s3)
        .padding(.vertical, 7)
        .background(f.light, in: Capsule())
    }
}

/// 인라인 메타 — 아이콘 + 데이터 숫자(시간 등). 면 없이 ink-2.
struct MetaChip: View {
    let icon: Ph
    let text: String
    var body: some View {
        HStack(spacing: ReffiSpace.s1) {
            icon.reffi(15)
            Text(text).font(.reffiNum(14, relativeTo: .caption))
        }
        .foregroundStyle(ReffiColor.ink2)
    }
}
