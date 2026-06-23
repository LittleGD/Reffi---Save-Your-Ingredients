import SwiftUI

/// 검증/미리보기용 — 종이컷 버튼 컴포넌트들. 런치 인자 `-buttonGallery`로 표시.
struct ButtonGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s7) {
                Text("Paper buttons").reffiType(.heading).foregroundStyle(ReffiColor.ink)

                group("Reference — Tossed · Ate") {
                    HStack(spacing: ReffiSpace.s7) {
                        PaperIconButton(icon: ReffiIcon.toss, label: "Tossed", intent: .soft, seed: 0) {}
                        PaperIconButton(icon: ReffiIcon.ate, label: "Ate", intent: .primary, seed: 1) {}
                    }
                }

                group("Icon buttons — intents") {
                    HStack(spacing: ReffiSpace.s4) {
                        PaperIconButton(icon: ReffiIcon.cook, intent: .primary, size: 72, seed: 2) {}
                        PaperIconButton(icon: ReffiIcon.recipe, intent: .fresh, size: 72, seed: 3) {}
                        PaperIconButton(icon: ReffiIcon.time, intent: .soon, size: 72, seed: 4) {}
                        PaperIconButton(icon: ReffiIcon.undo, intent: .neutral, size: 72, seed: 5) {}
                    }
                }

                group("Wide CTA — PaperButton") {
                    VStack(spacing: ReffiSpace.s3) {
                        PaperButton(title: "Start cooking", kind: .primary) {}
                        PaperButton(title: "Maybe later", kind: .secondary) {}
                    }
                }
            }
            .padding(ReffiSpace.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ReffiColor.canvas.ignoresSafeArea())
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            Text(title).reffiType(.caption).foregroundStyle(ReffiColor.ink2)
            content()
        }
    }
}
