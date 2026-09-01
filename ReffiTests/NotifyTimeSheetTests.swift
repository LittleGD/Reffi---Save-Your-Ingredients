import Testing
import Foundation
@testable import Reffi

/// "Alert time" 시트(`NotifyTimeSheet`, §2.1.2)의 선택 동작 — 51차 종이컷 리스트 교체 회귀 가드.
/// SSOT는 `ExpiryNotifier.hourKey`(`@AppStorage`, `ProfileView` 토글과 같은 키) — 행을 탭하면
/// `alertHour = hour`로 그 키에 직접 쓰인다. `ReffiFeedbackTests`와 같은 문법으로 시트를 띄우지
/// 않고 저장소 계약만 고정한다(체크 표시는 이 값을 읽기만 하는 파생 상태라 별도로 잠글 것이 없다).
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
}
