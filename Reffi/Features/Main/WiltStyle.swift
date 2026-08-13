import SwiftUI

/// 시듦(wilt, §13.3) — 재료 일러스트가 **소비기한에 따라 눈에 보이게 시든다**.
/// 팔레트를 신선도색으로 갈아끼우지 않는다(당근은 끝까지 주황이어야 재료 식별이 산다):
/// 자연색 위에 **두 축**만 얹는다.
///
/// 1. **강도 축(intensity)** — 신선도 3단계(fresh/soon/urgent)로 채도·명도가 단조 감쇠하고
///    형태 강도(`shapeWeight`)가 0 → 0.5 → 1로 올라간다. D-3에서 다 써버리지 않고 D-0까지 계속 시든다.
/// 2. **재질 축(material)** — 글리프별 `Rigidity`가 형태 변화량을 가른다. 캔·갑·병은 시들지 않는다
///    (`rigidContainer` = 형태 불변, 색만 감쇠). 잎채소가 가장 많이 숙는다.
///
/// 값은 전부 순수 상수 — `PaperSilhouette`의 그리기 이음매(Canvas·`poly`) 두 곳에서만 적용해
/// 53종 글리프 함수는 손대지 않고 전부 상속시킨다. 단조성과 재질 표는 테스트로 고정한다(`WiltStyleTests`).
struct WiltStyle: Equatable {
    /// 채도 배수(1 = 원본).
    let saturation: Double
    /// 명도 배수(1 = 원본). **곱셈**이라 상수항이 없어 프리멀티플라이 알파에서도 테두리가 뜨지 않는다.
    let brightness: Double
    /// 형태 시듦 강도 0…1 — 항등에서 `Shape` 표 값까지 **선형 보간**하는 가중치다.
    /// 배율이 아니다: `squash`·`spread`는 1 주변 값이라 곱하면 글리프가 반토막 난다(`Shape.lerped`).
    let shapeWeight: CGFloat
    /// 텍스처 캐시 키 조각 — enum 보간 문자열에 의존하지 않게 상태별로 고정한다.
    let token: String

    /// D-4+ — 손대지 않는다(원본 팔레트·직립·각 그대로).
    static let freshStyle  = WiltStyle(saturation: 1.00, brightness: 1.00, shapeWeight: 0.0, token: "f")
    /// D-1~3 — 알아채되 거슬리지 않는 정도. 색이 살짝 빠지고 어깨가 처지기 시작한다.
    static let soonStyle   = WiltStyle(saturation: 0.85, brightness: 0.97, shapeWeight: 0.5, token: "s")
    /// D-0/지남 — 한눈에 시들었다. 색이 확 빠지고 옆으로 주저앉고 각이 무뎌진다.
    static let urgentStyle = WiltStyle(saturation: 0.68, brightness: 0.93, shapeWeight: 1.0, token: "u")

    static func `for`(_ f: Freshness) -> WiltStyle {
        switch f {
        case .fresh:  freshStyle
        case .soon:   soonStyle
        case .urgent: urgentStyle
        }
    }

    /// 아무것도 바꾸지 않는 상태 — 호출부에서 필터·트랜스폼 자체를 건너뛴다(렌더 비용 0).
    var isIdentity: Bool { self == .freshStyle }

    /// 채도×명도를 **하나의 선형 색행렬**로 합성. 상수항(5열)이 0이라 알파 채널과 무관하게
    /// 안전하고, 색상(hue)은 건드리지 않아 재료 정체성이 남는다.
    /// 채도는 Rec.709 휘도 가중 회색축 보간(표준 saturate 행렬).
    var colorMatrix: ColorMatrix {
        let s = saturation, b = brightness
        let lr = 0.2126, lg = 0.7152, lb = 0.0722
        var m = ColorMatrix()   // 기본값 = 항등
        m.r1 = Float(b * (lr + s * (1 - lr))); m.r2 = Float(b * (lg * (1 - s)));       m.r3 = Float(b * (lb * (1 - s)))
        m.g1 = Float(b * (lr * (1 - s)));      m.g2 = Float(b * (lg + s * (1 - lg))); m.g3 = Float(b * (lb * (1 - s)))
        m.b1 = Float(b * (lr * (1 - s)));      m.b2 = Float(b * (lg * (1 - s)));       m.b3 = Float(b * (lb + s * (1 - lb)))
        return m
    }

    // MARK: - 재질 축 (rigidity)

    /// 시들 때 **형태가 얼마나 무너지는가**로 글리프를 가르는 축. 분류 라벨(`categoryLabel`)을
    /// 재사용하지 않는다 — 그 축의 주인은 History 도넛·분석 taxonomy라, 통계 목적의 재분류가
    /// 일러스트를 조용히 다시 튜닝해 버린다(달걀을 Dairy→Protein으로 옮기면 달걀이 처지기 시작한다).
    /// 또 라벨은 `String`이라 면(面)마다 읽으면 문자열 비교 비용이 붙는다.
    enum Rigidity {
        /// 갑·캔·병·단지·껍질 — **형태 불변**. 캔은 시들지 않는다(색만 바랜다).
        case rigidContainer
        /// 단단한 몸통(뿌리채소·덩어리 단백질·해산물) — 아주 살짝 숙고, 각만 조금 무뎌진다.
        case firm
        /// 수분 많은 살(과일·토마토·오이·두부·빵·밥) — 중간으로 숙고 각이 많이 뭉툭해진다.
        case soft
        /// 잎·줄기·봉오리 — 가장 먼저 숨이 죽는다. 처짐·퍼짐·라운딩 전부 최대.
        case leafy
    }

    /// 시든 재료의 **형태** 처리(재질 축의 최대치 = `shapeWeight` 1일 때 값).
    /// - `tilt`·`squash`: 처짐(바닥 앵커) — 밑동은 그대로, 윗부분이 숙는다.
    /// - `spread`: 세로로 눌린 만큼 가로로 살짝 퍼짐 — 주저앉은 인상을 보강한다.
    /// - `rounding`: 빳빳하던 꼭짓점을 뭉툭하게 — 종이가 물을 먹어 각이 무뎌진 느낌.
    struct Shape: Equatable {
        let tilt: Double        // 기울기(도, 음수 = 반시계)
        let squash: CGFloat     // 세로 스쿼시
        let spread: CGFloat     // 가로 퍼짐
        /// 꼭짓점 라운딩 — **각 면의 짧은 변(바운딩 박스) 기준 비율**(0 = 각 그대로)이라 34pt
        /// 간편보기 행이든 70pt 갤러리든 같은 인상을 준다(절대 반경이면 작은 글리프만 뭉개진다).
        let rounding: CGFloat

        /// 항등에서 `w`만큼 **선형 보간**. `tilt`·`rounding`은 0 기준이라 곱하면 되지만
        /// `squash`·`spread`는 **1 기준**이라 반드시 1에서 보간해야 한다(그냥 곱하면 w=0.5에서
        /// 글리프가 절반 크기로 찌그러진다).
        func lerped(_ w: CGFloat) -> Shape {
            Shape(tilt: tilt * Double(w),
                  squash: 1 + (squash - 1) * w,
                  spread: 1 + (spread - 1) * w,
                  rounding: rounding * w)
        }
    }

    /// 글리프 → 재질. **default 없는 전수 스위치** — 새 글리프가 늘면 컴파일이 막아 선다.
    static func rigidity(for glyph: FoodGlyph) -> Rigidity {
        switch glyph {
        // 잎·줄기·봉오리·해조·버섯 — 가장 먼저 숨이 죽는다.
        case .leaf, .cabbage, .seaweed, .broccoli, .pea, .mushroom:
            .leafy
        // 수분 많은 살 — 과일 전종 + 물러지는 채소 + 조리·가공된 무른 것.
        case .apple, .citrus, .berry, .avocado, .banana, .grape, .watermelon, .pineapple, .mango,
             .tomato, .cucumber, .chili, .eggplant,
             .tofu, .cheese, .bread, .dumpling, .rice, .noodles, .gimbap:
            .soft
        // 갑·캔·병·단지·껍질 — 형태 불변.
        case .milk, .yogurt, .butter, .can, .sauceBottle, .honey, .egg:
            .rigidContainer
        // 단단한 몸통 — 뿌리채소·덩어리 단백질·해산물·곡물, 그리고 정체불명 블롭.
        case .root, .squash, .onion, .pepper, .potato, .garlic, .pumpkin, .sweetPotato, .ginger, .corn,
             .meat, .poultry, .fish, .shrimp, .sausage, .bacon, .crab, .squid, .clam,
             .generic:
            .firm
        }
    }

    /// 재질별 형태 처리 최대치. `nil` = 형태를 아예 안 건드린다(좌표계도 패스도 그대로).
    static func shape(for glyph: FoodGlyph) -> Shape? {
        switch rigidity(for: glyph) {
        case .rigidContainer: nil
        case .leafy:          Shape(tilt: -7.0, squash: 0.935, spread: 1.030, rounding: 0.17)
        case .soft:           Shape(tilt: -4.5, squash: 0.955, spread: 1.022, rounding: 0.15)
        case .firm:           Shape(tilt: -4.5, squash: 0.965, spread: 1.000, rounding: 0.09)
        }
    }

    /// 이 신선도 단계에서 **실제로 적용할** 형태 — 항등이면 `nil`이라 호출부가 통째로 건너뛴다.
    func stagedShape(for glyph: FoodGlyph) -> Shape? {
        guard shapeWeight > 0, let base = Self.shape(for: glyph) else { return nil }
        return base.lerped(shapeWeight)
    }
}
