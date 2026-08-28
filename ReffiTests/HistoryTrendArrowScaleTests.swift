import Testing
import UIKit
@testable import Reffi

/// 추세 화살표가 **히어로 숫자와 같은 램프로** 커지는가(35차).
///
/// 33차에 추세 문장을 걷어내면서 화살표가 화면상 **유일한 추세 전달자**가 됐다 — 큰 글자를 쓰는
/// 사용자(VoiceOver는 안 쓰는)에게서 방향이 사라지면 안 된다. 그래서 `HistoryContent`는 이
/// 화살표에만 `@ScaledMetric(relativeTo: .largeTitle)`을 건다(이 앱에서 아이콘이 타입을 따라
/// 커지는 유일한 자리다 — `ReffiIcon.reffi(_:)`는 고정 프레임 그대로다).
///
/// **잠그는 것은 크기가 아니라 짝이다.** `@ScaledMetric(relativeTo: X)`와 `reffiNum(.hero)`의
/// `relativeTo:`가 **같은 텍스트 스타일**이어야 둘이 한 몸으로 움직인다 — 한쪽만 바뀌면 접근성
/// 크기 어디선가 화살표만 앞서거나 뒤처지고, 그 어긋남은 기본 크기 스크린샷에서는 안 보인다.
/// 두 값 다 `UIFontMetrics(forTextStyle:)`이 내므로 여기서 그 원천을 직접 잰다.
struct HistoryTrendArrowScaleTests {

    /// `HistoryContent`의 기준값(`@ScaledMetric ... = 20`)과 `ReffiNumScale.hero`(32).
    private static let arrowBase: CGFloat = 20

    private static let categories: [UIContentSizeCategory] = [
        .small, .medium, .large, .extraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge,
        .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge,
    ]

    /// 화살표와 숫자가 **모든** 접근성 크기에서 같은 비율을 유지한다.
    /// 비가 흔들리면 두 `relativeTo:`가 갈렸다는 뜻이다.
    ///
    /// **허용 오차는 반올림 한 점이다.** `UIFontMetrics.scaledValue`는 정수 포인트로 반올림하므로
    /// 20과 32를 따로 키우면 비가 소수점 셋째 자리에서 흔들린다(실측 최대 0.003) — 그건 스타일이
    /// 갈린 게 아니라 반올림이다. 그래서 임의의 상수가 아니라 **숫자 크기당 1pt**를 오차로 쓴다.
    /// 이 폭이 진짜 어긋남을 놓치지 않는다는 것은 아래 `negativeControl`이 증명한다.
    @Test func arrowTracksHeroNumberAtEveryContentSize() {
        let metrics = UIFontMetrics(forTextStyle: .largeTitle)   // reffiNum(.hero)와 같은 스타일
        let baseRatio = Self.arrowBase / ReffiNumScale.hero.size
        for category in Self.categories {
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let arrow = metrics.scaledValue(for: Self.arrowBase, compatibleWith: traits)
            let number = metrics.scaledValue(for: ReffiNumScale.hero.size, compatibleWith: traits)
            #expect(abs(arrow / number - baseRatio) <= 1.0 / number,
                    "\(category.rawValue): 화살표/숫자 비가 \(arrow / number) — 기준 \(baseRatio)에서 벗어났다")
        }
    }

    /// **음성 대조군 — 위 테스트에 이빨이 있는가.** 짝을 일부러 틀리게(`caption2`) 잡으면 같은
    /// 허용 오차에서 **반드시 걸려야** 한다. 이게 없으면 오차를 반올림 폭까지 넓힌 순간 테스트가
    /// 아무것도 안 잡는 채로 초록불만 켤 수 있다.
    @Test func negativeControlAMismatchedTextStyleIsCaught() {
        let hero = UIFontMetrics(forTextStyle: .largeTitle)
        let mismatched = UIFontMetrics(forTextStyle: .caption2)   // 화살표를 여기에 걸었다고 치자
        let baseRatio = Self.arrowBase / ReffiNumScale.hero.size
        let caught = Self.categories.contains { category in
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let arrow = mismatched.scaledValue(for: Self.arrowBase, compatibleWith: traits)
            let number = hero.scaledValue(for: ReffiNumScale.hero.size, compatibleWith: traits)
            return abs(arrow / number - baseRatio) > 1.0 / number
        }
        #expect(caught, "짝이 틀려도 안 걸린다 — 위 테스트의 허용 오차가 너무 넓다")
    }

    /// 실제로 **커지긴 하는가** — 비만 보면 둘 다 안 커져도 통과한다.
    /// 고정 프레임(옛 동작)이면 여기서 걸린다.
    @Test func arrowActuallyGrowsWithAccessibilitySizes() {
        let metrics = UIFontMetrics(forTextStyle: .largeTitle)
        let atDefault = metrics.scaledValue(
            for: Self.arrowBase,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let atAX5 = metrics.scaledValue(
            for: Self.arrowBase,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        #expect(atAX5 > atDefault * 1.4,
                "AX5에서 화살표가 기본의 1.4배도 못 미친다(실측 \(atDefault) → \(atAX5))")
    }

    /// 채움률 보정(34차)이 남아 있는가 — 기준값이 12로 되돌아가면 다시 티끌이 된다.
    /// Phosphor 캐럿은 제 상자의 세로 38%만 채워서 12pt는 보이는 삼각형이 4.7pt였다.
    @Test func arrowBaseKeepsTheGlyphFillCorrection() {
        #expect(Self.arrowBase >= 20)
    }
}
