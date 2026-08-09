import SwiftUI

/// 시듦(wilt, §13.3) — 재료 일러스트가 **소비기한에 따라 눈에 보이게 시든다**.
/// 팔레트를 신선도색으로 갈아끼우지 않는다(당근은 끝까지 주황이어야 재료 식별이 산다):
/// 자연색 위에 **채도·명도 감쇠 + 밑변 고정 세로 스쿼시 + 기울임(전단)** 만 얹는다.
///
/// 값은 전부 순수 상수 — `PaperSilhouette`의 그리기 이음매(Canvas) 한 곳에서만 적용해
/// 52종 글리프 함수는 손대지 않고 전부 상속시킨다. 단조성(fresh→soon→urgent로 계속 시든다)은
/// 테스트로 고정한다(`WiltStyleTests`).
struct WiltStyle: Equatable {
    /// 채도 배수(1 = 원본).
    let saturation: Double
    /// 명도 배수(1 = 원본). **곱셈**이라 상수항이 없어 프리멀티플라이 알파에서도 테두리가 뜨지 않는다.
    let brightness: Double
    /// 세로 스쿼시 배수 — 밑변 고정이라 재료가 위에서 주저앉는다(바닥에서 뜨지 않는다).
    let squash: CGFloat
    /// 기울임(도) — 밑변에서 멀수록 옆으로 밀리는 전단. 축 늘어진 실루엣.
    let lean: CGFloat
    /// 텍스처 캐시 키 조각 — enum 보간 문자열에 의존하지 않게 상태별로 고정한다.
    let token: String

    /// D-4+ — 손대지 않는다(원본 팔레트·직립).
    static let freshStyle  = WiltStyle(saturation: 1.00, brightness: 1.00, squash: 1.00, lean: 0, token: "f")
    /// D-1~3 — 알아채되 거슬리지 않는 정도. 색이 살짝 빠지고 어깨가 처진다.
    static let soonStyle   = WiltStyle(saturation: 0.85, brightness: 0.97, squash: 0.97, lean: 2, token: "s")
    /// D-0/지남 — 한눈에 시들었다. 색이 확 빠지고 옆으로 주저앉는다.
    static let urgentStyle = WiltStyle(saturation: 0.68, brightness: 0.93, squash: 0.93, lean: 4, token: "u")

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

    /// 밑변(baselineY) 고정 스쿼시 + 전단. 캔버스 좌표계(y 아래로 증가) 기준이라
    /// 밑변보다 위(작은 y)일수록 오른쪽으로 밀린다.
    ///   x' = x - tan(lean)·(y - baseY),  y' = baseY + squash·(y - baseY)
    func transform(baselineY: CGFloat) -> CGAffineTransform {
        let shear = -tan(lean * .pi / 180)
        return CGAffineTransform(a: 1, b: 0, c: shear, d: squash,
                                 tx: -shear * baselineY, ty: baselineY * (1 - squash))
    }
}
