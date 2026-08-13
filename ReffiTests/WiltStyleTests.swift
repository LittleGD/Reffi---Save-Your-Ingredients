import Testing
import CoreGraphics
import Foundation
import SwiftUI
@testable import Reffi

/// 시듦(WiltStyle) — 두 축을 고정한다.
/// - **강도 축**: 신선도가 나빠질수록 한 방향으로만 시든다(단조성), 색조는 안 바뀐다(색행렬 성질).
/// - **재질 축**: 글리프별 형태 처리 표 — 용기류는 형태 불변, 잎채소가 가장 많이 숙는다.
/// 렌더 없이 순수 값만 검증한다(픽셀 도달 여부는 `WiltRenderTests`).
struct WiltStyleTests {

    private let ordered: [WiltStyle] = [.freshStyle, .soonStyle, .urgentStyle]

    @Test func mapsEachFreshnessState() {
        #expect(WiltStyle.for(.fresh) == .freshStyle)
        #expect(WiltStyle.for(.soon) == .soonStyle)
        #expect(WiltStyle.for(.urgent) == .urgentStyle)
    }

    @Test func freshIsUntouched() {
        // 신선한 재료는 원본 그대로 — 필터·트랜스폼을 건너뛸 수 있어야 렌더 비용이 0이다.
        let f = WiltStyle.freshStyle
        #expect(f.isIdentity)
        #expect(f.saturation == 1 && f.brightness == 1 && f.shapeWeight == 0)
        // 형태 가중치가 0이면 어떤 글리프든 좌표계를 안 건드린다.
        for g in FoodGlyph.allCases {
            #expect(f.stagedShape(for: g) == nil, "\(g.rawValue): 신선한데 형태가 변한다")
        }
        #expect(!WiltStyle.soonStyle.isIdentity)
        #expect(!WiltStyle.urgentStyle.isIdentity)
    }

    @Test func frozenIngredientUsesEffectiveClock() {
        // 냉동 유예(14일)를 받은 재료는 원본 소비기한이 지났어도 시들지 않는다.
        let ing = Ingredient(name: "Dumplings", category: "Other",
                             expiresAt: Ingredient.day(offset: -1),
                             glyph: .dumpling, storage: .freezer,
                             frozenAt: Ingredient.day(offset: -2))
        #expect(WiltStyle.for(ing.freshness).isIdentity)
    }

    // MARK: 강도 축 — 단조 증가

    @Test func wiltIsStrictlyMonotonic() {
        // fresh → soon → urgent 로 갈수록 채도·명도는 줄고 형태 강도는 커진다(역전 금지).
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            #expect(b.saturation < a.saturation)
            #expect(b.brightness < a.brightness)
            #expect(b.shapeWeight > a.shapeWeight)
        }
    }

    @Test func shapeGradationIsInterpolatedNotScaled() {
        // soon은 fresh와 urgent 사이 — D-3에서 시각 예산을 다 쓰지 않는다.
        // 그리고 **항등에서 보간**한다: 그냥 곱하면 w=0.5에서 글리프가 반토막 난다(squash 0.468).
        let soon = WiltStyle.soonStyle.stagedShape(for: .leaf)
        let urgent = WiltStyle.urgentStyle.stagedShape(for: .leaf)
        #expect(soon != nil && urgent != nil)
        guard let soon, let urgent else { return }
        #expect(soon.tilt > urgent.tilt && soon.tilt < 0)          // 기울기는 음수 방향으로 커진다
        #expect(soon.squash > urgent.squash && soon.squash < 1)    // 1에서 표 값 쪽으로만 내려간다
        #expect(soon.spread < urgent.spread && soon.spread > 1)
        #expect(soon.rounding > 0 && soon.rounding < urgent.rounding)
        // w=1이면 표 값 그대로.
        #expect(urgent == WiltStyle.shape(for: .leaf))
        // w=0.5는 정확히 중간(항등 기준).
        #expect(abs(soon.squash - (1 + (urgent.squash - 1) / 2)) < 0.0001)
        #expect(abs(soon.spread - (1 + (urgent.spread - 1) / 2)) < 0.0001)
    }

    @Test func wiltStaysWithinLegibleRange() {
        // 시들어도 재료를 알아볼 수 있어야 한다 — 회색으로 무너지거나 형체가 찌그러지면 실패.
        for s in ordered {
            #expect(s.saturation >= 0.6 && s.saturation <= 1)
            #expect(s.brightness >= 0.9 && s.brightness <= 1)
            #expect(s.shapeWeight >= 0 && s.shapeWeight <= 1)
        }
    }

    @Test func tokensAreDistinct() {
        // 텍스처 캐시 키 조각 — 겹치면 시든 칩이 신선한 칩의 텍스처를 재사용한다.
        #expect(Set(ordered.map(\.token)).count == ordered.count)
    }

    @Test func colorMatrixKeepsGrayAxisAndDarkensByBrightness() {
        // 회색(무채색)은 채도와 무관 — 밝기 배수만 남아야 한다(색조 이동 없음의 필요조건).
        for s in ordered {
            let m = s.colorMatrix
            let rowR = Double(m.r1 + m.r2 + m.r3)
            let rowG = Double(m.g1 + m.g2 + m.g3)
            let rowB = Double(m.b1 + m.b2 + m.b3)
            #expect(abs(rowR - s.brightness) < 0.0001)
            #expect(abs(rowG - s.brightness) < 0.0001)
            #expect(abs(rowB - s.brightness) < 0.0001)
            // 상수항(5열)과 알파 행은 건드리지 않는다 — 프리멀티플라이 알파에서 테두리가 뜨지 않게.
            #expect(m.r5 == 0 && m.g5 == 0 && m.b5 == 0 && m.a5 == 0)
            #expect(m.a1 == 0 && m.a2 == 0 && m.a3 == 0 && m.a4 == 1)
        }
    }

    // MARK: 재질 축 — 글리프별 형태 표

    @Test func containersKeepTheirShape() {
        // 갑·병·캔·단지·달걀은 색만 바랜다 — 처지지도, 각이 무뎌지지도 않는다.
        // 치즈는 여기 없다(덩어리가 실제로 늘어지고 땀을 흘린다 → soft).
        for g in [FoodGlyph.milk, .can, .sauceBottle, .honey, .yogurt, .butter, .egg] {
            #expect(WiltStyle.rigidity(for: g) == .rigidContainer)
            #expect(WiltStyle.shape(for: g) == nil, "\(g.rawValue)는 형태가 변하면 안 된다")
            #expect(WiltStyle.urgentStyle.stagedShape(for: g) == nil)
        }
        #expect(WiltStyle.rigidity(for: .cheese) == .soft)
    }

    @Test func vegetablesDroopHardest() {
        let veg = WiltStyle.shape(for: .leaf)
        let meat = WiltStyle.shape(for: .meat)
        #expect(veg != nil && meat != nil)
        guard let veg, let meat else { return }
        #expect(veg.tilt < meat.tilt)        // 더 많이 기울고(음수 방향)
        #expect(veg.squash < meat.squash)    // 더 많이 눌리고
        #expect(veg.spread > meat.spread)    // 눌린 만큼 옆으로 더 퍼진다
        // 잎·해조·봉오리·꼬투리·버섯이 한 묶음으로 같은 강도를 받는다.
        for g in [FoodGlyph.cabbage, .seaweed, .broccoli, .pea, .mushroom] {
            #expect(WiltStyle.shape(for: g) == veg, "\(g.rawValue)는 잎채소 처짐이어야 한다")
        }
    }

    @Test func produceSoftensMoreThanProtein() {
        // 물러짐(각 무뎌짐)은 잎채소·무른 살이 강하고 단단한 몸통은 중간 — 용기는 위 테스트대로 0.
        let leafy = WiltStyle.shape(for: .leaf)!.rounding
        let soft = WiltStyle.shape(for: .apple)!.rounding
        let firm = WiltStyle.shape(for: .meat)!.rounding
        #expect(leafy > firm)
        #expect(soft > firm)
        #expect(firm > 0)
    }

    @Test func everyGlyphHasADefinedLook() {
        // 53종 전부가 네 갈래 재질 중 하나로 떨어진다(스위치에 default가 없어 컴파일이 1차 방어).
        // 네 갈래가 전부 비어 있지 않은지도 확인한다 — 표가 통째로 한 쪽으로 쏠린 회귀를 잡는다.
        var seen: Set<String> = []
        let known = [WiltStyle.shape(for: .leaf), WiltStyle.shape(for: .apple), WiltStyle.shape(for: .meat)]
        for g in FoodGlyph.allCases {
            let s = WiltStyle.shape(for: g)
            #expect(s == nil || known.contains(s), "\(g.rawValue) 형태 처리가 재질 축 밖이다")
            seen.insert(String(describing: WiltStyle.rigidity(for: g)))
        }
        #expect(seen.count == 4, "재질 4종이 전부 쓰이지 않는다: \(seen.sorted())")
    }

    @Test func wiltStaysSubtle() {
        // "한눈에 다르지만 과하지 않게" — 아트 디렉션 범위를 벗어난 튜닝을 막는다.
        // 특히 rounding이 0.5에 가까워지면 각이 사라져 정체불명의 블롭이 된다.
        for g in FoodGlyph.allCases {
            guard let s = WiltStyle.shape(for: g) else { continue }
            #expect(s.tilt <= -4 && s.tilt >= -8)
            #expect(s.squash >= 0.93 && s.squash <= 0.97)
            #expect(s.spread >= 1.0 && s.spread <= 1.04)
            #expect(s.rounding > 0 && s.rounding <= 0.20)
        }
    }
}

/// 시듦이 **실제 픽셀에 도달하는지**를 53종 전부에 대해 확인한다.
/// 갤러리 스크린샷은 첫 화면 한 판만 볼 수 있어 아래쪽 글리프가 사각지대로 남는다 — 여기서
/// 오프스크린 래스터로 전수 검사한다. 특히 두 계약을 못 박는다:
/// 1. 모든 글리프가 신선/시듦에서 **다른 픽셀**을 낸다 → 물리 텍스처 캐시 키에 시듦 축이 반드시 필요.
/// 2. 용기류(우유갑·캔·병·단지·버터·달걀)는 **실루엣이 한 픽셀도 안 변한다**(색만 바램).
@MainActor
struct WiltRenderTests {

    /// 글리프 하나를 side×side로 래스터해 RGB와 실루엣 마스크(알파 > 127)를 뽑는다.
    /// 그림자를 끄고(`shadowed: false`) 그려 실루엣 비교가 블러에 흔들리지 않게 한다.
    private func raster(_ glyph: FoodGlyph, wilted: Bool, side: Int = 96) -> (rgb: [UInt8], mask: [Bool])? {
        let renderer = ImageRenderer(content:
            PaperSilhouette(glyph: glyph, fresh: wilted ? .urgent : .fresh, shadowed: false)
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
        // 형태 처리가 nil인 재질(용기류)은 좌표계도 패스도 안 건드리므로 실루엣이 동일해야 한다.
        for g in FoodGlyph.allCases where WiltStyle.shape(for: g) == nil {
            guard let a = raster(g, wilted: false), let b = raster(g, wilted: true) else {
                Issue.record("\(g.rawValue) 래스터 실패"); continue
            }
            let moved = zip(a.mask, b.mask).filter { $0.0 != $0.1 }.count
            #expect(moved == 0, "\(g.rawValue): 형태가 변했다(\(moved)px)")
        }
    }

    @Test func produceSilhouetteActuallyMoves() {
        // 반대 방향 계약 — 잎채소·무른 살은 처짐·퍼짐·라운딩이 실루엣에 실제로 나타나야 한다.
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

/// 텍스처 캐시 키에 **시듦 축이 실제로 들어 있는지**를 씬을 띄우지 않고 고정한다.
/// `WiltRenderTests.everyGlyphRendersDifferentlyWhenWilted`가 "픽셀이 다르다"를 증명하므로,
/// 키가 같아지는 순간 시든 칩이 신선한 칩의 텍스처를 그대로 재사용한다(날이 넘어가도 안 시든다).
struct WiltCacheKeyTests {

    private func ingredient(daysLeft: Int) -> Ingredient {
        Ingredient(name: "Spinach", category: "Veg",
                   expiresAt: Ingredient.day(offset: daysLeft), glyph: .leaf)
    }

    @Test func textureKeyChangesAcrossTheFreshnessBoundary() {
        // 같은 재료·같은 변인데 소비기한만 D-4 → D-3으로 넘어가면 키가 달라져야 한다.
        let fresh = ingredient(daysLeft: 4), soon = ingredient(daysLeft: 3), urgent = ingredient(daysLeft: 0)
        #expect(fresh.freshness == .fresh && soon.freshness == .soon && urgent.freshness == .urgent)
        let keys = [fresh, soon, urgent].map {
            IngredientDropScene.textureKey(for: $0, side: 64, shadowed: true)
        }
        #expect(Set(keys).count == 3, "시듦 단계가 캐시 키에 안 들어갔다: \(keys)")
    }

    @Test func textureKeySeparatesSideAndShadow() {
        // 같은 축을 공유하는 나머지 두 차원도 함께 고정 — 넣는 쪽/버리는 쪽이 한 식을 쓴다.
        let ing = ingredient(daysLeft: 0)
        #expect(IngredientDropScene.textureKey(for: ing, side: 64, shadowed: true)
                != IngredientDropScene.textureKey(for: ing, side: 72, shadowed: true))
        #expect(IngredientDropScene.textureKey(for: ing, side: 64, shadowed: true)
                != IngredientDropScene.textureKey(for: ing, side: 64, shadowed: false))
    }
}
