import SwiftUI
import UIKit

#if DEBUG
/// 검증용 — StoryScript 마지막 글리프 오버행 클리핑 격리 실험. 런치 인자 `-titleClipLab`로 표시.
/// 각 행 90pt 고정 슬롯 — 스크린샷 밴드 측정용. GlyphGalleryView 선례.
struct TitleClipLabView: View {
    private let story34 = Font.custom("StoryScript-Regular", size: 34)

    var body: some View {
        VStack(spacing: 0) {
            row { Text(verbatim: "Step 1").font(story34) }                                   // 1 고정 크기
            row { Text(verbatim: "Step 1").font(ReffiTextRole.display.font) }                // 2 relativeTo
            row { Text(verbatim: "Step 1").font(story34).tracking(0) }                       // 3 tracking(0)
            row { Text(verbatim: "Step 1.").font(story34) }                                  // 4 뒤에 마침표
            row { Text(verbatim: "Step 1").font(story34).fixedSize() }                       // 5 fixedSize
            row { Text(verbatim: "1Step").font(story34) }                                    // 6 숫자가 중간
            row { StoryLabel(text: "Step 1") }                                               // 7 UILabel
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.canvas)
    }

    private func row<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c()
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)
            .frame(height: 90)
    }
}

/// UIKit 대조군 — 같은 폰트의 UILabel(클리핑 여부 비교).
private struct StoryLabel: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UILabel {
        let l = UILabel()
        l.font = UIFont(name: "StoryScript-Regular", size: 34)
        l.text = text
        l.textColor = UIColor(ReffiColor.ink)
        l.clipsToBounds = false
        return l
    }
    func updateUIView(_ uiView: UILabel, context: Context) {}
}
#endif
