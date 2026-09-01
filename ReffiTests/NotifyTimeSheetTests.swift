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
/// **58차-b — 호스팅 프로브를 남기지 않은 이유.** 커밋 경로 버그를 실물로 잡으려고 시트를
/// `UIHostingController`+`UIWindow`에 띄워 "열기만 해도 저장값이 바뀌면 안 된다"를 관찰하는
/// 프로브를 먼저 세웠다. 버그는 실제로 잡혔지만(수정 전 9→6, 수정 후 9→7 — 같은 오프셋에서
/// 보정 전은 clamp 바닥, 보정 후는 그 오프셋의 진짜 행) 이 환경에서는 `.task`의
/// `scrollTo(_:anchor:)`가 목표 행까지 가지 못한다(디스플레이 링크가 없어 `LazyVStack` 행이
/// 게을러진 채 남는다 — 키 윈도우·5초 펌프·매 틱 강제 레이아웃까지 시도해도 같았다).
/// 그래서 "최종값 == 9"는 이 환경에서 **옳은 코드로도** 만족될 수 없고, 남기면 영구 실패하는
/// 가드가 된다. 게다가 그 계약은 지금 코드가 보증하지도 않는다: `.task`가 `scrollTo` 직후
/// 곧바로 `isInteractive = true`를 켜서 초기 센터링이 만든 지오메트리 콜백까지 커밋으로 친다
/// (실기기에서는 스크롤이 9시에 정착해 최종값이 되돌아오므로 눈에 띄지 않는다). 그 타이밍
/// 구멍은 이 변경의 범위 밖이라, 여기서는 아래 순수 기하 앵커로 커밋 좌표계만 잠근다.
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
    /// `topInset: 0`이면 되더하기가 항등이라 아래 수치는 58차-b 보정 전후로 같다
    /// (`dialDistanceMatchesPlainOffsetWhenTopInsetIsZero`와 같은 문법).
    @Test func snapIndexRoundsToNearestRow() {
        let rowHeight = NotifyTimeSheet.rowHeight
        #expect(NotifyTimeSheet.snapIndex(forOffset: 0, topInset: 0, rowHeight: rowHeight, count: 16) == 0)
        // 21/44 ≈ 0.477 → 0행에 더 가깝다.
        #expect(NotifyTimeSheet.snapIndex(forOffset: 21, topInset: 0, rowHeight: rowHeight, count: 16) == 0)
        // 23/44 ≈ 0.523 → 1행이 더 가깝다.
        #expect(NotifyTimeSheet.snapIndex(forOffset: 23, topInset: 0, rowHeight: rowHeight, count: 16) == 1)
        #expect(NotifyTimeSheet.snapIndex(forOffset: rowHeight, topInset: 0, rowHeight: rowHeight, count: 16) == 1)
    }

    /// 스냅 인덱스 clamp — 관성으로 양 끝을 넘어가도 목록 범위 밖 인덱스를 내보내지 않는다.
    @Test func snapIndexClampsToValidRange() {
        let rowHeight = NotifyTimeSheet.rowHeight
        #expect(NotifyTimeSheet.snapIndex(forOffset: -200, topInset: 0, rowHeight: rowHeight, count: 16) == 0)
        #expect(NotifyTimeSheet.snapIndex(forOffset: 10_000, topInset: 0, rowHeight: rowHeight, count: 16) == 15)
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

    // MARK: - 58차-b 스냅 인덱스 앵커(밴드 중앙 보정)

    /// `snapIndex`가 잠그는 계약 — `dialDistance`와 **같은** 좌표 보정을 쓴다. 58차는 되더하기를
    /// 렌더 소비자에만 넣고 커밋 소비자를 빠뜨렸다. 같은 실측값(`topInset`=76·`rowHeight`=44)에서
    /// 행 i가 밴드 중앙에 정착한 오프셋 `i*44 - 76`이 정확히 i로 돌아와야 한다:
    /// 0행 ⇔ -76, 1행 ⇔ -32(위 `dialDistanceIsZeroAtTrueBandCenter`와 같은 앵커), 3행(9시) ⇔ 56,
    /// 4행 ⇔ 100.
    @Test func snapIndexAnchorsToBandCenterWithTopInset() {
        #expect(NotifyTimeSheet.snapIndex(forOffset: -76, topInset: 76, rowHeight: 44, count: 16) == 0)
        #expect(NotifyTimeSheet.snapIndex(forOffset: -32, topInset: 76, rowHeight: 44, count: 16) == 1)
        #expect(NotifyTimeSheet.snapIndex(forOffset: 56, topInset: 76, rowHeight: 44, count: 16) == 3)
        #expect(NotifyTimeSheet.snapIndex(forOffset: 100, topInset: 76, rowHeight: 44, count: 16) == 4)
    }

    /// 보정 전 회귀 재현 — 옛 계산(`round(offset/rowHeight)` + clamp)은 9시(인덱스 3)가 정착한
    /// 오프셋 56에서 1을 낸다. `hours[1]`은 7시라, 시트를 열기만 해도 저장값이 9→7로 두 행
    /// 어긋났다. 그 틀린 값을 여기 박아 두어 되돌아오면 바로 걸리게 한다
    /// (`dialDistanceDiffersFromUncorrectedFormulaWhenTopInsetNonZero`와 같은 문법).
    @Test func snapIndexUncorrectedFormulaReproducesRegression() {
        let offset: CGFloat = 56, topInset: CGFloat = 76, rowHeight: CGFloat = 44
        let uncorrected = min(max(Int((offset / rowHeight).rounded()), 0), 15)
        #expect(uncorrected == 1)
        #expect(uncorrected != 3)
        #expect(NotifyTimeSheet.hours[uncorrected] == 7)   // 실제로 저장되던 값
        let corrected = NotifyTimeSheet.snapIndex(forOffset: offset, topInset: topInset,
                                                  rowHeight: rowHeight, count: 16)
        #expect(corrected == 3)
        #expect(NotifyTimeSheet.hours[corrected] == 9)     // 사용자가 실제로 보고 있던 값
    }

    /// 방어적 가드 — `rowHeight`가 0 이하면 0으로 나누지 않고 0을 낸다(`dialDistance`의 같은 가드와 짝).
    @Test func snapIndexGuardsNonPositiveRowHeight() {
        #expect(NotifyTimeSheet.snapIndex(forOffset: 10, topInset: 5, rowHeight: 0, count: 16) == 0)
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
