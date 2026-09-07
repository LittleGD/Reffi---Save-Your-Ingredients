import SwiftUI
import UIKit

#if DEBUG
/// OK단단체 한글·영문 디스플레이/헤딩과 줄 끝 클리핑 확인. `-titleClipLab`로 표시.
/// 각 행 90pt 고정 슬롯 — 스크린샷 밴드 측정용. GlyphGalleryView 선례.
struct TitleClipLabView: View {
    private let display34 = Font.custom("OkDanDan-Bold", size: 34)

    var body: some View {
        VStack(spacing: 0) {
            row { Text(verbatim: "Step 1").font(display34) }                                   // 1 고정 크기
            row { Text(verbatim: "냉장고 오늘 뭐 먹지").font(ReffiTextRole.display.font) }                // 2 relativeTo
            row { Text(verbatim: "Fresh food 먼저 먹어요").font(display34).tracking(0) }                       // 3 tracking(0)
            row { Text(verbatim: "Fridge").font(ReffiTextRole.heading.font) }                                  // 4 영문 Heading
            row { Text(verbatim: "오늘의 냉장고").font(ReffiTextRole.heading.font) }                       // 5 한글 Heading
            row { Text(verbatim: "1Step").font(display34) }                                    // 6 숫자가 중간
            row { DisplayLabel(text: "Step 1") }                                               // 7 UILabel
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
private struct DisplayLabel: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UILabel {
        let l = UILabel()
        l.font = UIFont(name: "OkDanDan-Bold", size: 34)
        l.text = text
        l.textColor = UIColor(ReffiColor.ink)
        l.clipsToBounds = false
        return l
    }
    func updateUIView(_ uiView: UILabel, context: Context) {}
}
#endif
