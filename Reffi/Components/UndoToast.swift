import SwiftUI
import PhosphorSwift

/// 되돌리기 토스트(§13.6) — 판정·발주 직후 6초, 하단 잉크 캡슐. RootTabView가 탭 공통으로 띄워
/// 어느 탭에서 판정해도 놓치지 않는다. Undo 버튼 히트 영역 44pt(§7.3).
struct UndoToast: View {
    let undo: FridgeStore.PendingUndo
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: ReffiSpace.s3) {
            // 글리프는 옆 문장이 이미 말한 것을 그림으로 되풀이할 뿐이다 — 이름까지 읽히면 잡음만 는다.
            icon.accessibilityHidden(true)
            message
                .reffiType(.caption).foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: ReffiSpace.s2)
            Button(action: onUndo) {
                Text("Undo")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.toastAction)   // 고정 사유는 토큰 정의 주석 참조
                    .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
        }
        .padding(.horizontal, ReffiSpace.s4).padding(.vertical, ReffiSpace.s1)
        // 캡슐 면은 양 모드 모두 어두운 색이어야 위 흰 텍스트가 살아남는다(ink는 다크에서 크림으로 뒤집힘).
        .background(ReffiColor.toast, in: Capsule())
        .reffiShadow1()
        .padding(.horizontal, ReffiGrid.margin)
        // 문장과 Undo 버튼은 **한 묶음**이다 — 컨테이너로 묶어야 둘 사이에 다른 화면 요소가 끼지 않는다.
        .accessibilityElement(children: .contain)
        // 창은 몇 초 뒤 스스로 닫힌다 — 화면 어디에 떠 있든 **먼저** 읽혀야 사라지기 전에 닿는다.
        .accessibilitySortPriority(1000)
    }

    @ViewBuilder private var icon: some View {
        switch undo.kind {
        case .fired, .finished:
            ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.fresh)
        case .decision(_, let wasted):
            (wasted ? ReffiIcon.toss : ReffiIcon.ate).reffi(15, .fill)
                .foregroundStyle(wasted ? ReffiColor.urgent : ReffiColor.fresh)
        case .removed, .memoRemoved:
            // 이력 없는 정정 삭제 — 판정(먹음/버림)이 아니라 "목록에서 지웠다"라 잉크 톤으로 조용히.
            // 장보기 메모 한 줄도 같은 정본을 쓴다(둘 다 '내림'이다 — 갈리는 것은 아래 문장이다).
            ReffiIcon.delete.reffi(15, .fill).foregroundStyle(ReffiColor.urgent)
        }
    }

    @ViewBuilder private var message: some View {
        switch undo.kind {
        case .fired(let recipe, let count):
            Text("Started \(recipe) · \(count) reserved")
        case .finished(let recipe, let count):
            Text("Finished \(recipe) · \(count) logged")
        case .decision(let name, let wasted):
            wasted ? Text("\(name) · tossed") : Text("\(name) · eaten")
        case .removed(let name):
            Text("\(name) · removed")
        case .memoRemoved(let name):
            // 위 `.removed`와 **다른 문장**을 쓴다. 그쪽은 냉장고에서 재료가 사라졌다는 말이고
            // 이건 살 것 목록에서 내렸다는 말이라, 같은 "removed"로 뭉치면 토스트만 보고는
            // 재고가 지워진 줄 안다.
            Text("\(name) · off the memo")
        }
    }
}

extension FridgeStore.PendingUndo {
    /// 토스트가 떴다는 사실을 **소리로** 옮긴 한 문장. 화면 문구와 한 쌍으로 여기 둔다
    /// (`Ingredient.dDayText`/`dDayAccessibilityText`와 같은 태도) — 화면 쪽만 고치면 둘이 어긋난다.
    ///
    /// 문장이 화면 표기의 복사본이 아닌 이유는 둘이다: ① 가운뎃점으로 이어 붙인 축약은 소리로 읽히지
    /// 않는다 ② **되돌릴 수 있다는 사실**이야말로 고지의 목적이다 — 토스트를 못 본 사람에게는
    /// 판정이 끝났다는 말보다 그쪽이 중요하다.
    var announcement: String {
        switch kind {
        case .fired(let recipe, let count):
            String(localized: "Started \(recipe). \(count) ingredients reserved. Undo available.")
        case .finished(let recipe, let count):
            String(localized: "Finished \(recipe). \(count) ingredients logged. Undo available.")
        case .decision(let name, let wasted):
            wasted ? String(localized: "\(name) tossed. Undo available.")
                   : String(localized: "\(name) eaten. Undo available.")
        case .removed(let name):
            String(localized: "\(name) removed. Undo available.")
        case .memoRemoved(let name):
            String(localized: "\(name) off the memo. Undo available.")
        }
    }
}
