import Testing
import Foundation
import SwiftUI
@testable import Reffi

/// 시든 재료 표현(§13.3) — 트리거 임계와 분류별 처짐을 고정한다.
/// 렌더 결과(픽셀)는 스크린샷 QA의 몫이고, 여기선 **시각 처리를 결정하는 순수 함수**만 잠근다:
/// 임계가 D-3에서 밀리거나(`Freshness` 정본), `categoryLabel` 라벨이 바뀌어 분류가 조용히
/// 무너지는 것(문자열 축을 재사용하므로 실제 위험)이 이 스위트가 막는 회귀다.
struct WiltTests {

    // MARK: 트리거 — Freshness가 임계의 정본(D-3부터)

    @Test func wiltStartsThreeDaysBeforeDue() {
        #expect(Freshness(daysLeft: 4).isWilted == false)   // D-4 이상은 신선
        #expect(Freshness(daysLeft: 3).isWilted)            // 3일 전부터 시든다
        #expect(Freshness(daysLeft: 1).isWilted)
        #expect(Freshness(daysLeft: 0).isWilted)            // 당일
        #expect(Freshness(daysLeft: -2).isWilted)           // 지남
    }

    @Test func wiltFollowsTheSameThresholdAsTheBadge() {
        // 뱃지 색(fresh/soon/urgent)과 시듦이 같은 경계를 쓴다 — 임계 중복 정의 금지.
        for d in -3...10 {
            let f = Freshness(daysLeft: d)
            #expect(f.isWilted == (f.label != "Fresh"))
        }
    }

    @Test func frozenIngredientUsesEffectiveClock() {
        // 냉동 유예(14일)를 받은 재료는 원본 소비기한이 지났어도 시들지 않는다.
        let ing = Ingredient(name: "Dumplings", category: "Other",
                             expiresAt: Ingredient.day(offset: -1),
                             glyph: .dumpling, storage: .freezer,
                             frozenAt: Ingredient.day(offset: -2))
        #expect(ing.freshness.isWilted == false)
    }

    // MARK: 형태(처짐·퍼짐·라운딩) — 분류 축은 categoryLabel 재사용

    @Test func containersKeepTheirShape() {
        // 갑·병·캔·단지·달걀은 색만 바랜다 — 처지지도, 각이 무뎌지지도 않는다.
        for g in [FoodGlyph.milk, .can, .sauceBottle, .honey, .yogurt, .butter, .cheese, .egg] {
            #expect(PaperSilhouette.Wilt.look(for: g) == nil, "\(g.rawValue)는 형태가 변하면 안 된다")
        }
    }

    @Test func vegetablesDroopHardest() {
        let veg = PaperSilhouette.Wilt.look(for: .leaf)
        let meat = PaperSilhouette.Wilt.look(for: .meat)
        #expect(veg != nil && meat != nil)
        guard let veg, let meat else { return }
        #expect(veg.tilt < meat.tilt)        // 더 많이 기울고(음수 방향)
        #expect(veg.squash < meat.squash)    // 더 많이 눌리고
        #expect(veg.spread > meat.spread)    // 눌린 만큼 옆으로 더 퍼진다
        // 잎채소·채소류가 한 묶음으로 같은 강도를 받는다.
        for g in [FoodGlyph.cabbage, .seaweed, .broccoli, .pea, .mushroom] {
            #expect(PaperSilhouette.Wilt.look(for: g) == veg, "\(g.rawValue)는 채소 처짐이어야 한다")
        }
    }

    @Test func produceSoftensMoreThanProtein() {
        // 물러짐(각 무뎌짐)은 채소·과일이 강하고 단백질은 중간 — 용기는 위 테스트대로 0.
        let veg = PaperSilhouette.Wilt.look(for: .leaf)!.rounding
        let fruit = PaperSilhouette.Wilt.look(for: .apple)!.rounding
        let protein = PaperSilhouette.Wilt.look(for: .meat)!.rounding
        #expect(veg > protein)
        #expect(fruit > protein)
        #expect(protein > 0)
    }

    @Test func everyGlyphHasADefinedLook() {
        // 52종 전부가 네 갈래(채소·과일·중간·없음) 중 하나로 떨어진다 — 새 글리프가 늘어도 미정의가 없다.
        let known = [PaperSilhouette.Wilt.look(for: .leaf),
                     PaperSilhouette.Wilt.look(for: .apple),
                     PaperSilhouette.Wilt.look(for: .meat)]
        for g in FoodGlyph.allCases {
            let l = PaperSilhouette.Wilt.look(for: g)
            #expect(l == nil || known.contains(l), "\(g.rawValue) 형태 처리가 분류 밖이다")
        }
    }

    @Test func wiltStaysSubtle() {
        // "한눈에 다르지만 과하지 않게" — 아트 디렉션 범위를 벗어난 튜닝을 막는다.
        // 특히 rounding이 0.5에 가까워지면 각이 사라져 정체불명의 블롭이 된다.
        for g in FoodGlyph.allCases {
            guard let l = PaperSilhouette.Wilt.look(for: g) else { continue }
            #expect(l.tilt <= -4 && l.tilt >= -8)
            #expect(l.squash >= 0.93 && l.squash <= 0.97)
            #expect(l.spread >= 1.0 && l.spread <= 1.04)
            #expect(l.rounding > 0 && l.rounding <= 0.20)
        }
        #expect(PaperSilhouette.Wilt.saturation > 0.5 && PaperSilhouette.Wilt.saturation < 0.7)
    }
}

/// 시든 처리가 **실제 픽셀에 도달하는지**를 52종 전부에 대해 확인한다.
/// 갤러리 스크린샷은 첫 화면 한 판만 볼 수 있어 아래쪽 글리프가 사각지대로 남는다 — 여기서
/// 오프스크린 래스터로 전수 검사한다. 특히 두 계약을 못 박는다:
/// 1. 모든 글리프가 신선/시듦에서 **다른 픽셀**을 낸다 → 물리 텍스처 캐시 키에 시듦 축이 반드시 필요.
/// 2. 용기류(우유갑·캔·병·단지·버터)는 **실루엣이 한 픽셀도 안 변한다**(색만 바램).
@MainActor
struct WiltRenderTests {

    /// 글리프 하나를 side×side로 래스터해 RGB와 실루엣 마스크(알파 > 127)를 뽑는다.
    /// 그림자를 끄고(`shadowed: false`) 그려 실루엣 비교가 블러에 흔들리지 않게 한다.
    private func raster(_ glyph: FoodGlyph, wilted: Bool, side: Int = 96) -> (rgb: [UInt8], mask: [Bool])? {
        let renderer = ImageRenderer(content:
            PaperSilhouette(glyph: glyph, fresh: .fresh, shadowed: false, wilted: wilted)
                .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        var data = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &data, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var mask = [Bool](repeating: false, count: side * side)
        for i in 0..<(side * side) { mask[i] = data[i * 4 + 3] > 127 }
        return (data, mask)
    }

    @Test func everyGlyphRendersDifferentlyWhenWilted() {
        // 픽셀이 그대로인 글리프가 있다면 캐시 공유 버그가 조용히 숨을 수 있다 — 전수로 막는다.
        for g in FoodGlyph.allCases {
            guard let a = raster(g, wilted: false), let b = raster(g, wilted: true) else {
                Issue.record("\(g.rawValue) 래스터 실패"); continue
            }
            var maxDiff = 0
            for i in stride(from: 0, to: a.rgb.count, by: 4) where a.rgb[i + 3] > 127 {
                for c in 0..<3 { maxDiff = max(maxDiff, abs(Int(a.rgb[i + c]) - Int(b.rgb[i + c]))) }
            }
            #expect(maxDiff >= 6, "\(g.rawValue): 시들어도 색이 그대로다(maxDiff \(maxDiff))")
        }
    }

    @Test func containersKeepAnIdenticalSilhouette() {
        // 형태 처리가 nil인 분류(유제품·저장식품)는 좌표계도 패스도 안 건드리므로 실루엣이 동일해야 한다.
        for g in FoodGlyph.allCases where PaperSilhouette.Wilt.look(for: g) == nil {
            guard let a = raster(g, wilted: false), let b = raster(g, wilted: true) else {
                Issue.record("\(g.rawValue) 래스터 실패"); continue
            }
            let moved = zip(a.mask, b.mask).filter { $0.0 != $0.1 }.count
            #expect(moved == 0, "\(g.rawValue): 형태가 변했다(\(moved)px)")
        }
    }

    @Test func produceSilhouetteActuallyMoves() {
        // 반대 방향 계약 — 채소·과일은 처짐·퍼짐·라운딩이 실루엣에 실제로 나타나야 한다.
        for g in [FoodGlyph.leaf, .cabbage, .tomato, .broccoli, .apple, .citrus] {
            guard let a = raster(g, wilted: false), let b = raster(g, wilted: true) else {
                Issue.record("\(g.rawValue) 래스터 실패"); continue
            }
            let moved = zip(a.mask, b.mask).filter { $0.0 != $0.1 }.count
            let drawn = a.mask.filter { $0 }.count
            #expect(moved > drawn / 20, "\(g.rawValue): 형태 변화가 너무 미미하다(\(moved)/\(drawn)px)")
        }
    }
}
