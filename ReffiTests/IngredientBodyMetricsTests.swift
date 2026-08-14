import Testing
import Foundation
import CoreGraphics
@testable import Reffi

/// 충돌체 ↔ 그림 정합 — 홈 물리 씬의 칩이 **그림끼리 겹쳐 보이던** 회귀의 방지선.
///
/// 근본 원인은 바디가 그림 bbox에 **내접한 타원**이었다는 것이다. 컷페이퍼 글리프는 모서리와
/// 뾰족한 끝까지 그림이 차 있어서(생선 꼬리·우유갑 모서리), 타원은 그 모서리를 통째로 비운다.
/// 두 칩의 바디가 정확히 맞닿아도 그림은 수십 pt 겹쳐 보였다. 바디를 수퍼타원(n=4)으로 바꿔 메웠다.
///
/// 이 스위트는 두 가지를 잠근다: ① 53종 전수 실측 테이블 커버리지(빠지면 폴백 바디 + 남의 질량),
/// ② 바디가 실제로 그려진 픽셀을 얼마나 덮는지(모양이 다시 얇아지면 즉시 실패).
@MainActor
struct IngredientBodyMetricsTests {

    /// `Dictionary`는 컴파일러가 전수 커버리지를 강제하지 못한다 — `WiltStyle.rigidity`의 `default` 없는
    /// switch가 해 주는 일을 여기서 대신한다. 실제로 `.gimbap`이 조용히 빠져 있었고(53종 중 52),
    /// 폴백 바디와 남의 면적에서 파생된 질량을 쓰고 있었다.
    @Test func everyGlyphHasMeasuredBodyMetrics() {
        for g in FoodGlyph.allCases {
            #expect(IngredientDropScene.bodyMetric(for: g) != nil,
                    "\(g.rawValue): 실측 바디가 없어 폴백 타원과 남의 질량을 쓰게 된다")
        }
        #expect(FoodGlyph.allCases.allSatisfy { IngredientDropScene.bodyMetric(for: $0) != nil })
    }

    // MARK: - 커버리지 (바디가 그림을 얼마나 덮는가)

    /// 볼록 다각형 내부 판정 — `bodyPolygon`이 각도 증가 순(CCW)이라 모든 외적이 같은 부호면 내부.
    private func contains(_ poly: [CGPoint], _ pt: CGPoint) -> Bool {
        for i in 0..<poly.count {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let cross = (b.x - a.x) * (pt.y - a.y) - (b.y - a.y) * (pt.x - a.x)
            if cross < 0 { return false }
        }
        return true
    }

    /// 글리프 하나의 커버리지 = (바디 안에 있는 불투명 픽셀) / (전체 불투명 픽셀).
    /// `n`을 바꿔 옛 타원(n=2)과 새 수퍼타원(n=4)을 같은 잣대로 비교할 수 있다.
    private func coverage(_ g: FoodGlyph, n: CGFloat, sides: Int, side: Int = 140) -> Double? {
        guard let m = IngredientDropScene.bodyMetric(for: g),
              let mask = GlyphBodyMetrics.alphaMask(g, side: side) else { return nil }
        let poly = IngredientDropScene.bodyPolygon(w: CGFloat(side) * m.w,
                                                   h: CGFloat(side) * m.h,
                                                   dy: CGFloat(side) * m.dy,
                                                   sides: sides, n: n)
        var total = 0, inside = 0
        let half = CGFloat(side) / 2
        for row in 0..<side {
            for col in 0..<side where mask[row * side + col] {
                total += 1
                // 마스크는 row 0 = 시각 top, 바디는 SpriteKit(+y 위) — y를 뒤집어 맞춘다.
                let p = CGPoint(x: CGFloat(col) + 0.5 - half, y: half - (CGFloat(row) + 0.5))
                if contains(poly, p) { inside += 1 }
            }
        }
        return total == 0 ? nil : Double(inside) / Double(total)
    }

    /// 새 바디(수퍼타원 n=4, 16각)가 모든 글리프의 그림을 충분히 덮는지.
    ///
    /// 임계 0.62는 **53종 실측으로 잡았다**(2026-08 계측):
    /// n=4의 최악은 `pea` 0.652, 그 다음이 `noodles` 0.688 · `tofu` 0.724.
    /// 옛 타원(n=2, 14각)에서는 `pea` 0.578 · `noodles` 0.606 · `tofu` 0.620이었다.
    /// 두 분포 사이에 선을 그어, **모양이 타원 쪽으로 되돌아가면 pea·noodles가 즉시 실패**하고
    /// 현재 모양은 최소 0.03의 여유로 통과한다(렌더 미세차로 깜빡이지 않을 만큼).
    ///
    /// 1.0을 요구하지 않는 이유: 바디는 의도적으로 알파 bbox의 **90%**이고(살짝 nestle),
    /// 볼록 다각형이라 오목한 실루엣(버섯 기둥·완두 꼬투리 굴곡)은 원리적으로 다 덮을 수 없다.
    @Test func superellipseBodyCoversDrawnArt() {
        var worst = (glyph: "", value: 1.0)
        for g in FoodGlyph.allCases {
            guard let c = coverage(g, n: 4, sides: 16) else {
                Issue.record("\(g.rawValue): 알파 마스크를 못 만들었다")
                continue
            }
            if c < worst.value { worst = (g.rawValue, c) }
            #expect(c >= 0.62, "\(g.rawValue): 커버리지 \(String(format: "%.3f", c)) — 바디가 그림을 덜 덮는다")
        }
        print("[coverage] worst glyph under n=4: \(worst.glyph) = \(String(format: "%.3f", worst.value))")
    }

    /// 회귀의 **방향성**까지 고정한다 — 옛 타원이 실제로 더 나빴음을 테스트가 직접 증명한다.
    /// 이게 없으면 위 임계 0.62가 어디서 온 숫자인지 코드만 봐서는 알 수 없다.
    @Test func superellipseCoversMoreThanTheOldEllipse() {
        // 진단서가 지목한 모서리·끝 글리프(fish·milk·cheese) + 실측 최악 둘(pea·tofu).
        for g in [FoodGlyph.fish, .milk, .cheese, .pea, .tofu] {
            guard let old = coverage(g, n: 2, sides: 14), let new = coverage(g, n: 4, sides: 16) else {
                Issue.record("\(g.rawValue): 커버리지 계산 실패"); continue
            }
            #expect(new > old, "\(g.rawValue): 수퍼타원이 타원보다 더 덮어야 한다 (old \(old), new \(new))")
            print("[coverage] \(g.rawValue): ellipse \(String(format: "%.3f", old)) -> superellipse \(String(format: "%.3f", new))")
        }
    }
}
