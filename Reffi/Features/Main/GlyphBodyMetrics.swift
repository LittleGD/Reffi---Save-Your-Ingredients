#if DEBUG
import SwiftUI

/// 물리 바디 계측(진단) — 각 글리프의 **그림자 없는** 실루엣을 래스터해 비투명 픽셀의
/// **알파 바운딩 박스**와 **시각 질량 중심(alpha 가중 centroid)**을 측정한다.
/// `makeBody`의 글리프별 (폭·높이 비율, y 오프셋) 테이블을 실측으로 재보정하는 근거.
/// `-glyphMetrics` 런치 인자로 `GlyphMetricsView`가 콘솔에 표를 찍는다(재측정용).
enum GlyphBodyMetrics {
    struct Metric { let w: CGFloat; let h: CGFloat; let dx: CGFloat; let dyUp: CGFloat
        let minYf: CGFloat; let maxYf: CGFloat }   // minYf/maxYf: 버퍼 row 프랙션(0=버퍼 첫 행)

    /// 글리프 하나를 side×side로 래스터해 top-down 버퍼에서 알파를 읽는다(임계 0.5).
    @MainActor
    static func measure(_ glyph: FoodGlyph, side: Int = 220) -> Metric? {
        let renderer = ImageRenderer(content:
            PaperSilhouette(glyph: glyph, fresh: .fresh, shadowed: false)
                .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        let W = side, H = side
        var data = [UInt8](repeating: 0, count: W * H * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: W, height: H, bitsPerComponent: 8,
                                  bytesPerRow: W * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // 버퍼 row 0 = 시각 top이 되도록 뒤집어 그린다(SpriteKit +y = 위 = 작은 row).
        ctx.translateBy(x: 0, y: CGFloat(H))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))

        var minX = W, maxX = -1, minY = H, maxY = -1
        var sumA = 0.0, sumX = 0.0, sumY = 0.0
        for y in 0..<H {
            for x in 0..<W {
                let a = data[(y * W + x) * 4 + 3]
                if a > 127 {
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minY { minY = y }; if y > maxY { maxY = y }
                    let af = Double(a)
                    sumA += af; sumX += Double(x) * af; sumY += Double(y) * af
                }
            }
        }
        guard maxX >= 0, sumA > 0 else { return nil }
        let bw = CGFloat(maxX - minX + 1) / CGFloat(W)
        let bh = CGFloat(maxY - minY + 1) / CGFloat(H)
        let cx = sumX / sumA, cy = sumY / sumA
        let dx = CGFloat(cx) / CGFloat(W) - 0.5
        let dyUp = 0.5 - CGFloat(cy) / CGFloat(H)     // + = 질량이 위쪽(작은 row)
        return Metric(w: bw, h: bh, dx: dx, dyUp: dyUp,
                      minYf: CGFloat(minY) / CGFloat(H), maxYf: CGFloat(maxY) / CGFloat(H))
    }

    /// 전 글리프 측정 → makeBody 테이블용 라인을 콘솔 + 파일(Documents/glyph-metrics.txt)로 출력.
    @MainActor
    static func dump(fill: CGFloat = 0.90) {
        var out = "=== GLYPH BODY METRICS (fill=\(fill)) ===\n"
        for g in FoodGlyph.allCases {
            guard let m = measure(g) else { out += "\(g.rawValue): <empty>\n"; continue }
            let wf = (m.w * fill * 100).rounded() / 100
            let hf = (m.h * fill * 100).rounded() / 100
            let dy = (m.dyUp * 100).rounded() / 100
            let bw = (m.w * 100).rounded() / 100, bh = (m.h * 100).rounded() / 100
            let bcUp = ((0.5 - (m.minYf + m.maxYf) / 2) * 100).rounded() / 100   // bbox 중심 오프셋(+ = 위)
            out += String(format: "case .%@: (%.2f, %.2f, %.2f)   // bbox %.2fx%.2f massUp=%.2f bboxCtrUp=%.2f rows[%.2f..%.2f]\n",
                          g.rawValue, wf, hf, dy, bw, bh, dy, bcUp, m.minYf, m.maxYf)
        }
        out += "=== END METRICS ===\n"
        print(out)
        NSLog("%@", out)
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? out.write(to: dir.appendingPathComponent("glyph-metrics.txt"), atomically: true, encoding: .utf8)
        }
    }
}

/// `-glyphMetrics` 진입 화면 — 나타나면 표를 콘솔에 찍는다(값은 makeBody로 옮겨 고정).
struct GlyphMetricsView: View {
    @State private var done = false
    var body: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(verbatim: "Glyph body metrics")
                    .font(.headline)
                Text(verbatim: done ? "printed to console" : "measuring…")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .task {
            GlyphBodyMetrics.dump()
            done = true
        }
    }
}
#endif
