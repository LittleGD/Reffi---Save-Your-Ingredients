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
