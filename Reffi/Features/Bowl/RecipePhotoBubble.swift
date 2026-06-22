import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// 말풍선 — 둥근 네모 + 아래로 향한 꼬리(카드를 가리킨다). 사진은 둥근 네모 안에, 꼬리는 흰 테두리색.
struct SpeechBubble: Shape {
    var tail: CGFloat = 13
    func path(in r: CGRect) -> Path {
        let body = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - tail)
        var p = Path(roundedRect: body, cornerRadius: ReffiRadius.lg, style: .continuous)
        let cx = r.midX
        var t = Path()
        t.move(to: CGPoint(x: cx - tail, y: body.maxY - 1))
        t.addQuadCurve(to: CGPoint(x: cx, y: r.maxY), control: CGPoint(x: cx - tail * 0.35, y: r.maxY - 1))
        t.addQuadCurve(to: CGPoint(x: cx + tail, y: body.maxY - 1), control: CGPoint(x: cx + tail * 0.35, y: r.maxY - 1))
        t.closeSubpath()
        p.addPath(t)
        return p
    }
}

/// AI 추천 음식 사진 말풍선 — 온라인 실제 사진을 받아 스케치/일러스트(포스터화) 필터를 입혀 카드 위로 '뾱' 솟는다.
/// 사진 출처는 LoremFlickr(키워드 매칭 실사진) — 디자인 빌드용 자리표시. 실제론 AI가 만든 레시피 키워드로 교체.
struct RecipePhotoBubble: View {
    let keywords: String
    let tint: Color
    private let tail: CGFloat = 13

    @State private var image: UIImage?
    @State private var pop = false

    var body: some View {
        ZStack {
            SpeechBubble(tail: tail).fill(.white).reffiShadow1()
            VStack(spacing: 0) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            LinearGradient(colors: [tint.opacity(0.85), tint],
                                           startPoint: .top, endPoint: .bottom)
                            ReffiIcon.cook.reffi(26).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ReffiRadius.lg - 4, style: .continuous))
                Color.clear.frame(height: tail)
            }
            .padding(4)
        }
        .scaleEffect(pop ? 1 : 0.7, anchor: .bottom)
        .opacity(pop ? 1 : 0)
        .task(id: keywords) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { pop = true }
            if let img = await FoodPhoto.shared.sketched(keywords) {
                withAnimation(.easeOut(duration: 0.25)) { image = img }
            }
        }
    }
}

/// 음식 사진 캐시 + 스케치/일러스트 필터. 온라인 실사진 → CoreImage 포스터화 → 플랫 일러스트 룩(앱 톤과 통일).
final class FoodPhoto {
    static let shared = FoodPhoto()
    private var cache: [String: UIImage] = [:]
    private let ctx = CIContext()

    func sketched(_ keywords: String) async -> UIImage? {
        if let c = cache[keywords] { return c }
        let q = keywords.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "food"
        guard let url = URL(string: "https://loremflickr.com/600/600/\(q)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let raw = UIImage(data: data) else { return nil }
            let out = illustrate(raw) ?? raw
            cache[keywords] = out
            return out
        } catch { return nil }
    }

    /// 가벼운 일러스트 필터 — 알아볼 수 있게 사진은 살리고, 살짝 포스터화 + 채도/대비만(플랫 일러스트 힌트).
    /// 블러·외곽선 없음(과하면 뭉개져 안 보임).
    private func illustrate(_ ui: UIImage) -> UIImage? {
        guard let ci = CIImage(image: ui) else { return nil }
        let poster = CIFilter.colorPosterize(); poster.inputImage = ci; poster.levels = 10
        var out = poster.outputImage ?? ci
        let cc = CIFilter.colorControls(); cc.inputImage = out; cc.saturation = 1.18; cc.contrast = 1.05
        out = cc.outputImage ?? out
        guard let cg = ctx.createCGImage(out, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
