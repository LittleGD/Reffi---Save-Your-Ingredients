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
    /// 계측은 **항상 `.fresh`**(시듦 없는 직립 원형)에서 한다 — 충돌체는 신선도와 무관한 상수여야
    /// 날짜가 넘어가도 쌓인 더미가 재정렬되지 않는다(시듦은 3~7% 시각 스쿼시로만 나타난다).
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

    /// 알파 마스크 그대로 — 충돌체가 **그려진 픽셀을 얼마나 덮는가**를 재는 커버리지 테스트용.
    /// `measure`와 같은 래스터 경로·같은 임계(alpha > 127)를 쓴다. 반환 좌표계는 `measure`와 동일하게
    /// row 0 = 시각 top이고, 호출부가 SpriteKit 좌표(+y 위)로 뒤집어 쓴다.
    @MainActor
    static func alphaMask(_ glyph: FoodGlyph, side: Int = 140) -> [Bool]? {
        let renderer = ImageRenderer(content:
            PaperSilhouette(glyph: glyph, fresh: .fresh, shadowed: false)
                .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        var data = [UInt8](repeating: 0, count: side * side * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(side))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)))
        return (0..<(side * side)).map { data[$0 * 4 + 3] > 127 }
    }

    /// 전 글리프 측정 → makeBody 테이블용 라인을 콘솔 + 파일(Documents/glyph-metrics.txt)로 출력.
    @MainActor
    static func dump(fill: CGFloat = 0.90) {
        var out = "=== GLYPH BODY METRICS (fill=\(fill)) ===\n"
        for g in FoodGlyph.allCases {
            guard let m = measure(g) else { out += "\(g.rawValue): <empty>\n"; continue }
            let wf = (m.w * fill * 100).rounded() / 100
            let hf = (m.h * fill * 100).rounded() / 100
            let massUp = (m.dyUp * 100).rounded() / 100
            let bw = (m.w * 100).rounded() / 100, bh = (m.h * 100).rounded() / 100
            let bcUp = ((0.5 - (m.minYf + m.maxYf) / 2) * 100).rounded() / 100   // bbox 중심 오프셋(+ = 위)
            // 세 번째 칸 = **bboxCtrUp**(bodyMetrics의 dy 정본). 여기서 massUp을 찍던 옛 코드가
            // 표의 기준을 v1/v2에서 갈라놓았다 — 붙여 넣기만으로 표가 재현돼야 기준이 안 흔들린다.
            out += String(format: "case .%@: (%.2f, %.2f, %.2f)   // bbox %.2fx%.2f massUp=%.2f bboxCtrUp=%.2f rows[%.2f..%.2f]\n",
                          g.rawValue, wf, hf, bcUp, bw, bh, massUp, bcUp, m.minYf, m.maxYf)
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
