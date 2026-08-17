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
    ///
    /// **`legacy`를 주지 않으면 `bodyPolygon`을 인자 없이 부른다** — 즉 씬이 실제로 쓰는 기본 모양
    /// (`bodySides`·`bodyExponent`)을 그대로 잰다. 여기서 n·sides를 테스트가 넘겨 버리면 순수 함수의
    /// 수학적 성질만 확인하게 되고, 누가 기본값을 옛 타원으로 되돌려도 테스트는 그대로 통과한다.
    /// `legacy`는 옛 타원(14각 n=2)과 견주는 **비교 실험 전용**이다.
    private func coverage(_ g: FoodGlyph, legacy: Bool = false, side: Int = 140) -> Double? {
        guard let m = IngredientDropScene.bodyMetric(for: g),
              let mask = GlyphBodyMetrics.alphaMask(g, side: side) else { return nil }
        let w = CGFloat(side) * m.w, h = CGFloat(side) * m.h, dy = CGFloat(side) * m.dy
        let poly = legacy
            ? IngredientDropScene.bodyPolygon(w: w, h: h, dy: dy, sides: 14, n: 2)
            : IngredientDropScene.bodyPolygon(w: w, h: h, dy: dy)   // ← 프로덕션 기본 모양
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
            guard let c = coverage(g) else {
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
    /// `new`는 인자 없는 프로덕션 모양이라, 기본값이 옛 타원으로 되돌아가면 `new == old`가 되어 깨진다.
    @Test func superellipseCoversMoreThanTheOldEllipse() {
        // 진단서가 지목한 모서리·끝 글리프(fish·milk·cheese) + 실측 최악 둘(pea·tofu).
        for g in [FoodGlyph.fish, .milk, .cheese, .pea, .tofu] {
            guard let old = coverage(g, legacy: true), let new = coverage(g) else {
                Issue.record("\(g.rawValue): 커버리지 계산 실패"); continue
            }
            #expect(new > old, "\(g.rawValue): 수퍼타원이 타원보다 더 덮어야 한다 (old \(old), new \(new))")
            print("[coverage] \(g.rawValue): ellipse \(String(format: "%.3f", old)) -> superellipse \(String(format: "%.3f", new))")
        }
    }

    // MARK: - AABB ↔ 폴리곤 정합 (관통 해소가 재는 것 = 실제로 있는 것)

    /// 관통 해소(`depenetrateChips`)·벽 클램프(`clampIntoBox`)·`-physLab` 계측은 전부 `bodyAABB`로
    /// 겹침을 잰다. 그 AABB가 **실제 바디 꼭짓점**을 감싸지 못하면, 재는 겹침과 푸는 겹침이 갈려
    /// 안전망이 실제보다 관대해진다.
    ///
    /// 이 테스트가 잡는 회귀는 구체적이다: 예전엔 회전한 **타원**의 닫힌 식
    /// `√((a·cosθ)²+(b·sinθ)²)`으로 반폭을 냈는데, 바디가 수퍼타원이 된 뒤 그 식은 53종 전부에서
    /// 회전각에 따라 AABB를 최대 18.9% **과소평가**했다(꼭짓점이 사각형 밖으로 나간다).
    /// 누가 다시 닫힌 식으로 되돌리면 아래 포함 검사가 즉시 깨진다.
    @Test func bodyAABBEnclosesEveryPolygonVertex() {
        let side: CGFloat = 169   // 실기기 칩 변
        var worstOutside: CGFloat = 0
        for g in FoodGlyph.allCases {
            guard let m = IngredientDropScene.bodyMetric(for: g) else { continue }
            let w = side * m.w, h = side * m.h, dy = side * m.dy
            for step in 0..<24 {
                let rot = CGFloat(step) / 24 * 2 * .pi
                let box = IngredientDropScene.bodyAABB(w: w, h: h, dy: dy, rotation: rot)
                let c = cos(rot), s = sin(rot)
                for p in IngredientDropScene.bodyPolygon(w: w, h: h, dy: dy) {
                    let x = p.x * c - p.y * s, y = p.x * s + p.y * c
                    let out = max(box.minX - x, x - box.maxX, box.minY - y, y - box.maxY)
                    worstOutside = max(worstOutside, out)
                    #expect(out <= 1e-6,
                            "\(g.rawValue) @\(Int(rot * 180 / .pi))°: 꼭짓점이 AABB 밖으로 \(out)pt 나갔다")
                }
            }
        }
        #expect(worstOutside <= 1e-6)
    }

    /// AABB가 **딱 맞는** 최소 사각인지 — 네 변이 모두 어떤 꼭짓점에 닿아야 한다.
    /// 과대평가된 AABB는 그 반대로 안전망을 필요 이상으로 예민하게 만들어(없는 겹침을 밀어)
    /// 안착 직전 더미를 흔든다. 포함 검사와 짝을 이뤄 "감싸되 남기지 않는다"를 고정한다.
    @Test func bodyAABBIsTightAroundThePolygon() {
        let side: CGFloat = 169
        for g in FoodGlyph.allCases {
            guard let m = IngredientDropScene.bodyMetric(for: g) else { continue }
            let w = side * m.w, h = side * m.h, dy = side * m.dy
            for step in 0..<24 {
                let rot = CGFloat(step) / 24 * 2 * .pi
                let box = IngredientDropScene.bodyAABB(w: w, h: h, dy: dy, rotation: rot)
                let c = cos(rot), s = sin(rot)
                let pts = IngredientDropScene.bodyPolygon(w: w, h: h, dy: dy)
                    .map { CGPoint(x: $0.x * c - $0.y * s, y: $0.x * s + $0.y * c) }
                // **네 변을 각각** 본다 — 부호 있는 값들을 `max`로 합치면 한 변만 느슨한 AABB가
                // 다른 변의 0에 가려져 통과한다(느슨한 쪽은 음수라 최댓값이 되지 못한다).
                let slack = [box.minX - (pts.map(\.x).min() ?? 0),
                             (pts.map(\.x).max() ?? 0) - box.maxX,
                             box.minY - (pts.map(\.y).min() ?? 0),
                             (pts.map(\.y).max() ?? 0) - box.maxY]
                let worst = slack.map(abs).max() ?? 0
                #expect(worst <= 1e-6,
                        "\(g.rawValue) @\(Int(rot * 180 / .pi))°: AABB가 폴리곤에 딱 맞지 않는다(\(slack)pt)")
            }
        }
    }
}
