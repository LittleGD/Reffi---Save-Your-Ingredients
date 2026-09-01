import Testing
import SwiftUI
import Foundation
@testable import Reffi

/// "Alert time" 시트(`NotifyTimeSheet`, §2.1.2)의 선택 동작 — 51차 종이컷 리스트 → 56차 종이컷
/// 다이얼 교체 회귀 가드. SSOT는 `ExpiryNotifier.hourKey`(`@AppStorage`, `ProfileView` 토글과 같은
/// 키) — 다이얼이 스냅하면 `alertHour = hour`로 그 키에 직접 쓰인다. `ReffiFeedbackTests`와 같은
/// 문법으로 시트를 띄우지 않고 저장소 계약만 고정한다(다이얼 위치는 이 값을 읽기만 하는 파생
/// 상태라 별도로 잠글 것이 없다).
///
/// **56차 — 다이얼의 순수 로직**(시간 목록·포맷·스냅 인덱스·원근·접근성 스텝)은 뷰 렌더 없이
/// 호출 가능한 `static` 함수로 뷰에서 분리돼 있다(`hourLabel`이 이미 51차부터 같은 문법이었다 —
/// 새 규칙이 아니라 그 규율을 다이얼 계산으로 넓힌 것). 아래 뒷부분이 그 계산들을 잠근다.
///
/// `UserDefaults.standard`를 실제로 만지므로 직렬 실행 + 각 케이스가 끝에 키를 원복한다.
@Suite(.serialized)
struct NotifyTimeSheetTests {

    private func withKey(_ key: String, _ body: () -> Void) {
        let saved = UserDefaults.standard.object(forKey: key)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        body()
    }

    /// 행을 탭하는 것 = `alertHour = hour`(`@AppStorage`) = 그 키에 직접 쓰기. 선택이 SSOT에
    /// 그대로 반영되는지가 이 시트의 유일한 데이터 계약이다.
    @Test func selectingHourReflectsIntoStorage() {
        withKey(ExpiryNotifier.hourKey) {
            UserDefaults.standard.set(14, forKey: ExpiryNotifier.hourKey)
            #expect(ExpiryNotifier.alertHour == 14)
        }
    }

    /// 다른 행을 다시 탭하면(마음을 바꾸면) 새 값이 이전 선택을 이긴다 — 체크박스가 한 번에
    /// 하나만 켜져 있어야 하는 단일 선택 계약(§13.5 상태 채널은 하나)의 저장소 쪽 절반.
    @Test func reselectingHourOverridesPreviousChoice() {
        withKey(ExpiryNotifier.hourKey) {
            UserDefaults.standard.set(6, forKey: ExpiryNotifier.hourKey)
            #expect(ExpiryNotifier.alertHour == 6)
            UserDefaults.standard.set(21, forKey: ExpiryNotifier.hourKey)
            #expect(ExpiryNotifier.alertHour == 21)
        }
    }

    /// 미설정이면 `ExpiryNotifier.defaultHour`(9)로 떨어진다 — 리스트가 뜨는 순간 스크롤할 행
    /// (`.task { proxy.scrollTo(alertHour, ...) }`)이 첫 실행에도 목록 범위 안의 유효한 행이어야 한다.
    @Test func unsetFallsBackToDefaultHour() {
        withKey(ExpiryNotifier.hourKey) {
            UserDefaults.standard.removeObject(forKey: ExpiryNotifier.hourKey)
            #expect(ExpiryNotifier.alertHour == ExpiryNotifier.defaultHour)
        }
    }

    /// 라벨은 로케일 짧은 시각 포맷이다 — 경계 두 시(06·21)와 기본값(9)이 서로 다른 문자열로
    /// 갈려야 목록에서 각 행이 구별된다(휠 시절과 같은 포맷터를 그대로 물려받는다).
    @Test func hourLabelsAreDistinctAcrossRange() {
        let labels = Set([6, 9, 21].map { NotifyTimeSheet.hourLabel($0) })
        #expect(labels.count == 3)
    }

    // MARK: - 56차 다이얼 순수 로직

    /// 다이얼이 훑는 시간 목록 — 06~21시 16행. §2.1.2 "정시에만 발화" 계약의 UI 쪽 절반.
    @Test func hoursSpanSixToTwentyOneInclusive() {
        #expect(NotifyTimeSheet.hours.first == 6)
        #expect(NotifyTimeSheet.hours.last == 21)
        #expect(NotifyTimeSheet.hours.count == 16)
    }

    /// 인덱스 매핑 — 다이얼 행 하나가 정확히 그 시간을 가리켜야 원근·스냅 계산이 어긋나지 않는다.
    /// 범위 밖 시각은 `nil`(방어적 — 저장된 값이 다이얼 밖일 이유는 없지만 크래시하지 않는다).
    @Test func indexOfHourMatchesPosition() {
        #expect(NotifyTimeSheet.index(ofHour: 6) == 0)
        #expect(NotifyTimeSheet.index(ofHour: 21) == 15)
        #expect(NotifyTimeSheet.index(ofHour: 9) == 3)
        #expect(NotifyTimeSheet.index(ofHour: 5) == nil)
    }

    /// 스냅 인덱스 — 연속 스크롤 오프셋을 가장 가까운 행으로 반올림한다. 이 값이 바뀔 때만
    /// `alertHour`를 쓰고 선택 햅틱을 낸다 — 다이얼의 유일한 커밋 판정.
    @Test func snapIndexRoundsToNearestRow() {
        let rowHeight = NotifyTimeSheet.rowHeight
        #expect(NotifyTimeSheet.snapIndex(forOffset: 0, rowHeight: rowHeight, count: 16) == 0)
        // 21/44 ≈ 0.477 → 0행에 더 가깝다.
        #expect(NotifyTimeSheet.snapIndex(forOffset: 21, rowHeight: rowHeight, count: 16) == 0)
        // 23/44 ≈ 0.523 → 1행이 더 가깝다.
        #expect(NotifyTimeSheet.snapIndex(forOffset: 23, rowHeight: rowHeight, count: 16) == 1)
        #expect(NotifyTimeSheet.snapIndex(forOffset: rowHeight, rowHeight: rowHeight, count: 16) == 1)
    }

    /// 스냅 인덱스 clamp — 관성으로 양 끝을 넘어가도 목록 범위 밖 인덱스를 내보내지 않는다.
    @Test func snapIndexClampsToValidRange() {
        let rowHeight = NotifyTimeSheet.rowHeight
        #expect(NotifyTimeSheet.snapIndex(forOffset: -200, rowHeight: rowHeight, count: 16) == 0)
        #expect(NotifyTimeSheet.snapIndex(forOffset: 10_000, rowHeight: rowHeight, count: 16) == 15)
    }

    /// 다이얼 원근 — 중심(거리 0)은 완전 불투명·원래 크기다.
    @Test func perspectiveAtCenterIsFullStrength() {
        let center = NotifyTimeSheet.dialPerspective(distance: 0)
        #expect(center.opacity == 1)
        #expect(center.scale == 1)
    }

    /// 멀어질수록 옅고 작아지며, 좌우 대칭이다(스크롤 위/아래 방향에 상관없이 같은 거리는 같은 세기).
    @Test func perspectiveFadesSymmetricallyWithDistance() {
        let near = NotifyTimeSheet.dialPerspective(distance: 1)
        let far = NotifyTimeSheet.dialPerspective(distance: 2)
        let mirrored = NotifyTimeSheet.dialPerspective(distance: -1)
        #expect(near.opacity < 1 && near.scale < 1)
        #expect(far.opacity < near.opacity)
        #expect(far.scale < near.scale)
        #expect(near.opacity == mirrored.opacity)
        #expect(near.scale == mirrored.scale)
    }

    /// 감쇠 범위 밖에서는 바닥값에서 멈춘다 — 화면 밖 먼 행이 음수 불투명도·크기로 뒤집히지 않는다.
    @Test func perspectiveFloorsBeyondRange() {
        let atRange = NotifyTimeSheet.dialPerspective(distance: 2.5)
        let beyond = NotifyTimeSheet.dialPerspective(distance: 50)
        #expect(atRange.opacity == beyond.opacity)
        #expect(atRange.scale == beyond.scale)
        #expect(beyond.opacity > 0)
        #expect(beyond.scale > 0)
    }

    // MARK: - 58차 원근 거리 앵커(밴드 중앙 보정)

    /// `dialDistance`가 잠그는 계약 — `topInset`(밴드 상단 여백)을 되더한 뒤에야 `scrollOffsetY`가
    /// 행 인덱스 좌표계로 돌아온다. 58차 회귀 실측값(이 다이얼의 300pt 시트 → `topInset`=76·
    /// `rowHeight`=44)을 그대로 고정한다: 그 여백에서 0번 행이 중앙이려면 오프셋이 -76이어야 하고,
    /// 1번 행이 중앙이려면 -32여야 한다 — 스크린샷(round56-notifytimesheet.png)의 실제 미스매치를
    /// 낳은 값들이다.
    @Test func dialDistanceIsZeroAtTrueBandCenter() {
        #expect(NotifyTimeSheet.dialDistance(index: 0, scrollOffsetY: -76, topInset: 76, rowHeight: 44) == 0)
        #expect(NotifyTimeSheet.dialDistance(index: 1, scrollOffsetY: -32, topInset: 76, rowHeight: 44) == 0)
    }

    /// 보정 전 회귀 재현 — `topInset`을 되더하지 않은 옛 계산(`index - scrollOffsetY/rowHeight`)은
    /// 같은 입력에서 0이 아닌 값을 낸다. 이 차이 자체가 58차 버그였다: 밴드 중앙(거리 0이어야 함)이
    /// 옛 계산으로는 위쪽 행 쪽으로 `topInset/rowHeight`만큼(≈1.7행) 쏠려 있었다.
    @Test func dialDistanceDiffersFromUncorrectedFormulaWhenTopInsetNonZero() {
        let scrollOffsetY: CGFloat = -76, topInset: CGFloat = 76, rowHeight: CGFloat = 44
        let corrected = NotifyTimeSheet.dialDistance(index: 0, scrollOffsetY: scrollOffsetY,
                                                       topInset: topInset, rowHeight: rowHeight)
        let uncorrected = Double(0) - Double(scrollOffsetY / rowHeight)
        #expect(corrected == 0)
        #expect(uncorrected != 0)
    }

    /// `topInset`이 0이면(여백이 필요 없을 만큼 큰 밴드) 되더하기가 항등 연산이 되어, 이 보정이
    /// 기존 "오프셋을 행 폭으로 나눈다"는 단순 관계를 깨지 않는다.
    @Test func dialDistanceMatchesPlainOffsetWhenTopInsetIsZero() {
        #expect(NotifyTimeSheet.dialDistance(index: 3, scrollOffsetY: 132, topInset: 0, rowHeight: 44) == 0)
        #expect(NotifyTimeSheet.dialDistance(index: 0, scrollOffsetY: 132, topInset: 0, rowHeight: 44) == -3)
    }

    /// 방어적 가드 — `rowHeight`가 0 이하면(있을 수 없는 지오메트리) 0으로 나누지 않고 0을 낸다,
    /// `snapIndex`의 같은 가드와 짝을 맞춘다.
    @Test func dialDistanceGuardsNonPositiveRowHeight() {
        #expect(NotifyTimeSheet.dialDistance(index: 3, scrollOffsetY: 10, topInset: 5, rowHeight: 0) == 0)
    }

    /// 접근성 adjustable 스텝 — 위/아래 스와이프 한 번 = 한 시간 칸.
    @Test func adjustableStepMovesOneHour() {
        #expect(NotifyTimeSheet.steppedHour(from: 9, direction: .increment) == 10)
        #expect(NotifyTimeSheet.steppedHour(from: 9, direction: .decrement) == 8)
    }

    /// 다이얼 끝(06·21시)에서는 랩어라운드하지 않고 멈춘다 — 물리적 다이얼의 끝과 같다.
    @Test func adjustableStepClampsAtDialEnds() {
        #expect(NotifyTimeSheet.steppedHour(from: 21, direction: .increment) == 21)
        #expect(NotifyTimeSheet.steppedHour(from: 6, direction: .decrement) == 6)
    }
}
