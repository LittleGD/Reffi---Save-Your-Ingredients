import SwiftUI
import PhosphorSwift

/// 되돌리기 토스트(§13.6) — 판정·발주 직후 6초, 하단 잉크 캡슐. RootTabView가 탭 공통으로 띄워
/// 어느 탭에서 판정해도 놓치지 않는다. Undo 버튼 히트 영역 44pt(§7.3).
struct UndoToast: View {
    let undo: FridgeStore.PendingUndo
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: ReffiSpace.s3) {
            switch undo.kind {
            case .fired(let recipe, let count):
                ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.fresh)
                Text("Started \(recipe) · \(count) reserved")
                    .reffiType(.caption).foregroundStyle(.white)
                    .lineLimit(1)
            case .finished(let recipe, let count):
                ReffiIcon.ate.reffi(15, .fill).foregroundStyle(ReffiColor.fresh)
                Text("Finished \(recipe) · \(count) logged")
                    .reffiType(.caption).foregroundStyle(.white)
                    .lineLimit(1)
            case .decision(let name, let wasted):
                (wasted ? ReffiIcon.toss : ReffiIcon.ate).reffi(15, .fill)
                    .foregroundStyle(wasted ? ReffiColor.urgent : ReffiColor.fresh)
                (wasted ? Text("\(name) · tossed") : Text("\(name) · eaten"))
                    .reffiType(.caption).foregroundStyle(.white)
                    .lineLimit(1)
            case .removed(let name):
                // 이력 없는 정정 삭제 — 판정(먹음/버림)이 아니라 "목록에서 지웠다"라 잉크 톤으로 조용히.
                ReffiIcon.delete.reffi(15, .fill).foregroundStyle(ReffiColor.urgent)
                Text("\(name) · removed")
                    .reffiType(.caption).foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: ReffiSpace.s2)
            Button(action: onUndo) {
                Text("Undo")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.toastAction)   // 고정 사유는 토큰 정의 주석 참조
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
        }
        .padding(.horizontal, ReffiSpace.s4).padding(.vertical, ReffiSpace.s1)
        // 캡슐 면은 양 모드 모두 어두운 색이어야 위 흰 텍스트가 살아남는다(ink는 다크에서 크림으로 뒤집힘).
        .background(ReffiColor.toast, in: Capsule())
        .reffiShadow1()
        .padding(.horizontal, ReffiGrid.margin)
    }
}
