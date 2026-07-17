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
            }
            Spacer(minLength: ReffiSpace.s2)
            Button(action: onUndo) {
                Text("Undo")
                    .reffiType(.pillLabel)
                    .foregroundStyle(ReffiColor.blueLight)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.paperPress)
        }
        .padding(.horizontal, ReffiSpace.s4).padding(.vertical, ReffiSpace.s1)
        .background(ReffiColor.ink, in: Capsule())
        .reffiShadow1()
        .padding(.horizontal, ReffiGrid.margin)
    }
}
