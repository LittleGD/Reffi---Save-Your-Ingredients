import Testing
import SwiftUI
import UIKit
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
/// 그래서 **"최종값 == 9"형 가드**는 이 환경에서 **옳은 코드로도** 만족될 수 없고, 남기면 영구
/// 실패한다 — 그 형태의 프로브는 지금도 금지다.
///
/// **58차-c — 그 타이밍 구멍은 닫혔다(위 문단의 "범위 밖" 서술은 여기서 만료된다).** 프로브가
/// 드러낸 원인은 `.task`가 `scrollTo` 직후 곧바로 `isInteractive = true`를 켜서 초기 센터링이
/// 만든 지오메트리 콜백까지 커밋으로 쳤다는 것이었다. 그 불리언은 **기대 목표 인덱스 게이트**
/// (`pendingScrollTarget` + 순수 판정 `dialCommitDecision`)로 대체됐다: `init()`이 목표 행으로
/// 무장하고, 스크롤이 그 행에 도착할 때 비로소 풀린다. 새 불변식은 프로브 환경에서도 참인
/// 형태다 — "열기만 하면 값이 **아예 안 바뀐다**"(`scrollTo`가 목표에 못 닿으면 게이트가 안 열려
/// 커밋 0회, 닿으면 해제만 되고 무변화). 최종값이 아니라 **기록 궤적이 비어 있음**을 보는
/// 계약이라 도착 여부에 의존하지 않는다. 아래 "58차-c 커밋 게이트" 절이 그 판정을 순수 함수로
/// 잠근다.
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

    /// 전행 스윕 — 4행 표본이 아니라 16행 전부: 행 i 정착 오프셋(`i*44 - 76`)이 정확히 i로 돌아온다.
    /// 위 앵커 테스트가 고른 네 점만 맞고 나머지가 어긋나는 보정(예: 부호만 맞은 변형)을 막는다.
    @Test func snapIndexRoundTripsEveryRowSettleOffset() {
        for i in NotifyTimeSheet.hours.indices {
            #expect(NotifyTimeSheet.snapIndex(forOffset: CGFloat(i) * 44 - 76, topInset: 76,
                                              rowHeight: 44, count: 16) == i)
        }
    }

    /// 커밋 소비자(`snapIndex`)와 렌더 소비자(`dialDistance`)의 교차 불변식 — 커밋으로 고른 행은
    /// 원근 좌표계로도 밴드 중앙에서 반 행 이내다. 58차-b가 갈라진 두 소비자를 다시 묶은 계약
    /// 그 자체라, 한쪽 보정만 또 바뀌면 여기서 갈린다. 스윕은 첫·마지막 행 정착 오프셋 사이
    /// (clamp 미개입 구간), 타이 지점에선 양쪽 다 0.5라 어느 쪽을 골라도 성립한다.
    @Test func snapIndexAgreesWithDialDistanceAcrossOffsets() {
        for offset in stride(from: CGFloat(-76), through: 584, by: 4) {
            let picked = NotifyTimeSheet.snapIndex(forOffset: offset, topInset: 76, rowHeight: 44, count: 16)
            let distance = NotifyTimeSheet.dialDistance(index: picked, scrollOffsetY: offset,
                                                         topInset: 76, rowHeight: 44)
            #expect(abs(distance) <= 0.5 + 1e-9)
        }
    }

    /// clamp × 보정 결합 — 관성 오버슛이 보정 후에도 목록 범위를 안 벗어난다. 위 clamp 테스트는
    /// `topInset` 0만 다뤄 되더하기가 clamp 경계를 옮기는지 잠그지 못했다:
    /// (-200+76)/44 ≈ -2.82 → -3 → 0, (10000+76)/44 = 229 → 15.
    @Test func snapIndexClampsWithNonZeroTopInset() {
        #expect(NotifyTimeSheet.snapIndex(forOffset: -200, topInset: 76, rowHeight: 44, count: 16) == 0)
        #expect(NotifyTimeSheet.snapIndex(forOffset: 10_000, topInset: 76, rowHeight: 44, count: 16) == 15)
    }

    // MARK: - 60차 다이얼 hero 전이(선택 행 확대, §3.4 — 오너 판정)

    /// 중심(거리 0)은 완전 hero(1)다 — §3.4가 hero를 위해 남겨 둔 "화면당 하나"의 자리를
    /// 선택된 시각이 차지한다는 판정의 순수 로직 절반.
    @Test func heroBlendAtCenterIsFullyHero() {
        #expect(NotifyTimeSheet.dialHeroBlend(distance: 0) == 1)
    }

    /// 인접 행이 밴드 중앙에 온 순간(거리 1)엔 이 행이 완전히 body로 넘어가 있다 — 두 행이
    /// 동시에 hero로 보이는 "이중 히어로" 순간을 만들지 않는 대칭 핸드오프.
    @Test func heroBlendReachesZeroAtAdjacentRow() {
        #expect(NotifyTimeSheet.dialHeroBlend(distance: 1) == 0)
        #expect(NotifyTimeSheet.dialHeroBlend(distance: -1) == 0)
    }

    /// 절반 지점(거리 0.5)에서 정확히 절반씩 섞인다 — 두 이웃 행이 대칭으로 크로스페이드하는지,
    /// 스크롤 방향에 상관없이 같은 거리는 같은 세기인지(`dialPerspective`의 대칭 계약과 같은 결).
    @Test func heroBlendIsLinearAndSymmetric() {
        #expect(NotifyTimeSheet.dialHeroBlend(distance: 0.5) == 0.5)
        #expect(NotifyTimeSheet.dialHeroBlend(distance: -0.5) == 0.5)
    }

    /// 감쇠 범위 밖(먼 행)에서는 음수로 뒤집히지 않고 0에서 멈춘다 — `dialPerspective`의 바닥
    /// 가드와 짝을 맞춘다.
    @Test func heroBlendFloorsBeyondRange() {
        #expect(NotifyTimeSheet.dialHeroBlend(distance: 2.5) == 0)
        #expect(NotifyTimeSheet.dialHeroBlend(distance: -50) == 0)
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

    // MARK: - 58차-c 커밋 게이트(기대 목표 인덱스)

    /// 실측 좌표 계약(300pt 시트 → `topInset`=76·`rowHeight`=44)으로 오프셋을 스냅 인덱스로 바꾼다.
    /// 이 절이 원시 인덱스를 손으로 적는 대신 이 어댑터를 통과시키는 이유는, 게이트 계약을 58차·
    /// 58차-b가 잠근 **실제 기하**에 묶어 두기 위해서다 — 좌표 계약이 흔들리면 게이트 테스트도 함께
    /// 무너져 알려 준다(원시 인덱스로 적었다면 조용히 서로 어긋난 채 둘 다 초록일 수 있다).
    private func snap(_ offset: CGFloat) -> Int {
        NotifyTimeSheet.snapIndex(forOffset: offset, topInset: 76, rowHeight: 44, count: 16)
    }

    /// 무접촉 오픈 — 시트를 **열기만** 했을 때 커밋이 한 번도 일어나지 않는다. 이 시퀀스가 통째로
    /// 58차-c의 목표다: 커밋 0회 = `@AppStorage` 쓰기 0회 = `ExpiryNotifier.reschedule` 0회 =
    /// 선택 햅틱 0회.
    ///
    /// 저장값 9시(인덱스 3)로 열면 `init()`이 게이트를 3으로 무장한다. 프리젠테이션이 만드는 과도
    /// 콜백은 원시 오프셋 -76~22 부근(스냅 0~2)에서 관측됐는데, 그 전부가 목표와 다르므로 침묵이다.
    /// `.task`의 `scrollTo`가 3행 정착 오프셋 56에 닿아야 게이트가 풀리고, 풀리는 그 순간에도 커밋은
    /// 없다 — 값은 이미 9시로 옳기 때문이다.
    ///
    /// 표본에 **-32(스냅 1)** 가 들어 있는 이유(58차-c 리뷰 MINOR-2): RED 프로브가 실제로 잡은
    /// 유일한 오기록이 스냅 1(`trajectory [7]` = `hours[1]` = 7시)이다. -32를 빼면 이 테스트는
    /// 측정된 실패 지점을 비껴간 표본(`{0,2,2,2}`)으로 계약을 잠그게 된다.
    @Test func untouchedOpenCommitsNothingThroughSettle() {
        var pending: Int? = 3
        var committed = 3
        var commits: [Int] = []

        #expect(snap(-32) == 1, "표본이 RED가 실측한 스냅 클래스를 실제로 포함하는지 자체 확인")
        for offset in [CGFloat(-76), -32, 0, 10, 22] {
            let step = NotifyTimeSheet.dialCommitDecision(pendingTarget: pending, snapIndex: snap(offset),
                                                          committedIndex: committed)
            pending = step.pendingTarget
            if let commit = step.commit { committed = commit; commits.append(commit) }
            #expect(pending == 3, "프리젠테이션 과도 콜백(오프셋 \(offset))이 게이트를 풀면 안 된다")
        }
        #expect(commits.isEmpty, "무접촉 오픈은 커밋 경로를 한 번도 밟지 않는다")

        let arrival = NotifyTimeSheet.dialCommitDecision(pendingTarget: pending, snapIndex: snap(56),
                                                         committedIndex: committed)
        #expect(arrival.pendingTarget == nil, "3행 정착(오프셋 56)이 곧 도착 — 여기서 게이트가 풀린다")
        #expect(arrival.commit == nil, "도착은 해제 신호일 뿐 커밋이 아니다")
        #expect(committed == 3)
    }

    /// 회귀 박제 — 게이트가 없으면(58차-b까지의 `isInteractive`가 사실상 늘 열려 있던 상태) 프리젠테이션
    /// 과도 오프셋 22가 스냅 2를 내고 그게 그대로 커밋된다. `hours[2]`는 8시다: 사용자가 9시로 설정해
    /// 둔 시트를 **열기만 했는데** 저장값이 8시로 바뀌고 선택 틱이 우는 것이 이 버그의 실체였다.
    ///
    /// 실기기에서는 뒤이은 정착 콜백이 9시를 되돌려 놓아 최종값으로는 눈에 띄지 않는다. 그래도
    /// 그 사이 `ExpiryNotifier.reschedule`이 헛돌고, **정착 전에 시트가 뜯기면**(플링 후 스와이프
    /// dismiss, 백그라운드 킬) 8시가 그대로 남는다 — 과도 오기록이 실제로 살아남는 유일한 경로이자
    /// 이 수정의 사용자 가시 심각도 근거다.
    @Test func absentGateCommitsPresentationTransient() {
        let ungated = NotifyTimeSheet.dialCommitDecision(pendingTarget: nil, snapIndex: snap(22),
                                                         committedIndex: 3)
        #expect(ungated.commit == 2)
        #expect(NotifyTimeSheet.hours[2] == 8)   // 열기만 해도 저장되던 값
        #expect(NotifyTimeSheet.hours[3] == 9)   // 사용자가 실제로 보고 있던 값

        // 같은 콜백을 무장한 게이트가 받으면 침묵이다 — 이 대비가 곧 58차-c 수정의 전부다.
        let gated = NotifyTimeSheet.dialCommitDecision(pendingTarget: 3, snapIndex: snap(22),
                                                       committedIndex: 3)
        #expect(gated.commit == nil)
        #expect(gated.pendingTarget == 3)
    }

    /// 도착 후에는 다이얼이 평소대로 커밋한다 — 게이트가 풀린 상태에서 사용자가 4행(10시) 정착
    /// 오프셋 100까지 굴리면 그 행이 커밋된다. 게이트가 "여는 순간만 막는" 장치이지 다이얼을
    /// 잠그는 장치가 아니라는 계약이다(이게 깨지면 증상은 "시간을 못 고른다"로 뒤집힌다).
    @Test func commitsResumeAfterGateOpens() {
        let decision = NotifyTimeSheet.dialCommitDecision(pendingTarget: nil, snapIndex: snap(100),
                                                          committedIndex: 3)
        #expect(decision.commit == 4)
        #expect(decision.pendingTarget == nil)
        #expect(NotifyTimeSheet.hours[4] == 10)
    }

    /// 사용자 개입 우선 — 센터링이 아직 비행 중이어도 손이 닿는 순간 뷰가 게이트를 강제로 비운다
    /// (`.onScrollPhaseChange`의 `.tracking`/`.interacting`). 그 뒤 콜백은 평범한 사용자 스크롤로
    /// 읽혀야 한다. 도착 판정이 게이트를 여는 1차 경로이고 이쪽은 안전망이다: 프로그램 스크롤이
    /// 병리적으로 목표에 못 닿아도 다이얼이 영영 먹통이 되지 않게 하는 두 번째 열쇠다.
    @Test func userTouchClearedGateCommitsImmediately() {
        let inflight = NotifyTimeSheet.dialCommitDecision(pendingTarget: 3, snapIndex: snap(100),
                                                          committedIndex: 3)
        #expect(inflight.commit == nil, "비행 중에는 같은 콜백이 침묵한다")
        #expect(inflight.pendingTarget == 3)

        let afterTouch = NotifyTimeSheet.dialCommitDecision(pendingTarget: nil, snapIndex: snap(100),
                                                            committedIndex: 3)
        #expect(afterTouch.commit == 4, "phase가 게이트를 비운 뒤 같은 콜백은 커밋된다")
    }

    /// a11y 스텝 보호 — VoiceOver로 3행(9시)에서 4행(10시)으로 한 칸 올리면, 액션이 값을 **먼저**
    /// 직접 쓰고(`committedIndex`=4·`alertHour`=10) 화면만 애니메이션으로 뒤따른다. 그 스윕이
    /// 지나는 구간에서는 스냅 3이 잡히는데, 게이트가 없으면 `committedIndex`가 4→3→4로 튀어
    /// `.reffiFeedback(.selection, trigger:)`가 한 스텝에 세 번 울고 `@AppStorage`가 10→9→10으로
    /// churn한다. 게이트가 목표 4를 들고 있으면 그 구간은 침묵, 도착에서 해제, 정착 재보고는 no-op —
    /// 손끝에 닿는 틱은 액션이 값을 바꾼 그 한 번뿐이다.
    ///
    /// 표본 두 점의 역할이 다르다(58차-c 리뷰 NIT-3): **56은 스윕의 출발점**(3행 정착 오프셋)이고,
    /// **70이 진짜 중간**이다(스냅이 3→4로 넘어가는 경계는 78이라 70은 아직 스냅 3). 둘 다 "목표는
    /// 4인데 스냅이 3"인 같은 계약을 잠그지만, 출발점만 표본으로 두면 "스윕 도중"을 잠갔다고 말할 수 없다.
    @Test func accessibilitySweepEmitsSingleCommit() {
        var pending: Int? = 4          // 액션이 `withAnimation` 직전에 무장한 목표
        let committed = 4              // 액션이 이미 직접 써 둔 값
        var commits: [Int] = []

        #expect(snap(56) == 3 && snap(70) == 3 && snap(78) == 4,
                "56=출발점·70=스윕 중간(둘 다 스냅 3), 78=3→4 경계")
        for offset in [CGFloat(56), 70] {
            let step = NotifyTimeSheet.dialCommitDecision(pendingTarget: pending, snapIndex: snap(offset),
                                                          committedIndex: committed)
            pending = step.pendingTarget
            if let commit = step.commit { commits.append(commit) }
            #expect(pending == 4, "스윕 구간(오프셋 \(offset), 스냅 3)이 committedIndex를 되돌리면 안 된다")
        }

        let arrival = NotifyTimeSheet.dialCommitDecision(pendingTarget: pending, snapIndex: snap(100),
                                                         committedIndex: committed)
        pending = arrival.pendingTarget
        if let commit = arrival.commit { commits.append(commit) }
        #expect(pending == nil, "목표 행 도착에서 게이트가 풀린다")

        let settle = NotifyTimeSheet.dialCommitDecision(pendingTarget: pending, snapIndex: snap(100),
                                                        committedIndex: committed)
        if let commit = settle.commit { commits.append(commit) }
        #expect(settle.commit == nil, "해제 뒤 같은 행 재보고는 no-op다")
        #expect(commits.isEmpty, "a11y 한 스텝 = 커밋 변화 1회(액션의 직접 쓰기) = 햅틱 1회")
    }

    /// 이미 중앙인 채로 열기(저장값 6시 = 0행) — `scrollTo`가 사실상 no-op이라 "도착 콜백"이 따로
    /// 오지 않을 수 있다. 그래도 게이트는 첫 콜백에서 풀린다: 0행 정착 오프셋 -76이 곧 목표 스냅 0이라
    /// 정지 위치가 이미 도착점이기 때문이다. 게이트가 영영 안 열려 다이얼이 잠기는 경우가 없다는
    /// 것이 이 설계의 안전 마진이고, 그래서 이 시트는 첫 드래그부터 정상 커밋한다.
    @Test func alreadyCenteredOpenReleasesOnFirstCallback() {
        let decision = NotifyTimeSheet.dialCommitDecision(pendingTarget: 0, snapIndex: snap(-76),
                                                          committedIndex: 0)
        #expect(decision.pendingTarget == nil)
        #expect(decision.commit == nil)
    }

    /// 도착 판정은 **정확히** 스냅 == 목표일 때만이다. 한 행 못 미쳐도(스냅 2) 한 행 지나쳐도(스냅 4)
    /// 게이트는 무장 상태를 유지한다 — "근처면 도착"으로 느슨하게 풀면 관성이 스치고 지나가는 이웃
    /// 행에서 조기에 열려, 아직 프로그램 스크롤인 나머지 구간이 커밋으로 샌다.
    @Test func arrivalRequiresExactTargetSnap() {
        #expect(snap(12) == 2 && snap(100) == 4, "표본이 정말 목표(3)의 ±1행인지 스스로 확인한다")
        for offset in [CGFloat(12), 100] {
            let decision = NotifyTimeSheet.dialCommitDecision(pendingTarget: 3, snapIndex: snap(offset),
                                                              committedIndex: 3)
            #expect(decision.pendingTarget == 3, "±1행(오프셋 \(offset))은 도착이 아니다")
            #expect(decision.commit == nil)
        }
    }

    // MARK: - 58차-c 뷰-게이트 배선 계약(리뷰 MAJOR 대응)

    /// 페이즈 → 게이트 해제 매핑, **5케이스 전수**. `ScrollPhase`가 `@frozen`이라
    /// (`SwiftUICore.swiftinterface:625`) 이 열거가 미래 SDK에서 새 케이스로 새지 않는다.
    ///
    /// **`.animating`이 false인 것이 a11y 보호의 핵심 계약이다.** adjustable 스텝은 `withAnimation` +
    /// `scrollTo`로 화면을 옮기고 그 위상이 곧 `.animating`이다. 여기서 해제하면 스윕 중간 스냅 3이
    /// 커밋 권한을 얻어 `committedIndex`가 4→3→4로 튄다 — 한 스텝에 햅틱 3연발, `@AppStorage`
    /// 10→9→10 churn. 리뷰가 지적한 뮤테이션(`.animating`을 해제 쪽으로 옮기기)이 여기서 걸린다.
    /// `.decelerating`도 같은 이유로 false다(관성 구간엔 손이 이미 떠났고 해제는 `.tracking`에서 끝났다).
    @Test func gateClearsOnlyOnUserTouchPhases() {
        #expect(NotifyTimeSheet.dialGateClears(on: .tracking))
        #expect(NotifyTimeSheet.dialGateClears(on: .interacting))
        #expect(!NotifyTimeSheet.dialGateClears(on: .animating), "a11y 스윕 보호가 여기서 무너진다")
        #expect(!NotifyTimeSheet.dialGateClears(on: .decelerating))
        #expect(!NotifyTimeSheet.dialGateClears(on: .idle))
    }

    /// a11y 한 스텝의 상태 전이 — 새 시각·인덱스·무장 목표를 한 번에 정한다.
    ///
    /// **`pendingTarget == index`가 이 함수의 핵심 계약이다.** a11y 스텝은 값을 먼저 직접 쓰고 화면만
    /// 뒤따르게 하므로, 게이트는 "방금 쓴 그 행에 화면이 도착할 때까지"만 닫혀 있어야 한다. 둘이
    /// 어긋나면 도착 판정이 영영 안 맞아 게이트가 안 열리거나(선택 유실), 엉뚱한 행에서 열려 스윕
    /// 중간 커밋이 샌다. 9시(3행) → 10시(4행)는 58차-b 리뷰가 "옛 공식이 8시를 저장하고 있었다"고
    /// 확인한 바로 그 경로다.
    @Test func accessibilityStepArmsGateAtItsOwnTargetRow() {
        let step = NotifyTimeSheet.dialAccessibilityStep(fromHour: 9, direction: .increment)
        #expect(step?.hour == 10)
        #expect(step?.index == 4)
        #expect(step?.pendingTarget == 4)
        #expect(step?.pendingTarget == step?.index, "무장 목표는 방금 쓴 행과 같아야 한다")
        #expect(NotifyTimeSheet.hours[4] == 10)

        let down = NotifyTimeSheet.dialAccessibilityStep(fromHour: 9, direction: .decrement)
        #expect(down?.hour == 8 && down?.index == 2 && down?.pendingTarget == 2)
    }

    /// 다이얼 끝에서는 전이가 없다 — `nil`이라 호출부가 그대로 빠져나가고 게이트도 건드리지 않는다.
    /// 경계에서 헛무장하면 도착이 이미 지나간 뒤라 게이트가 안 열려 다음 진짜 스크롤이 먹힌다.
    /// 목록 밖 시각(저장값 손상 등)도 같은 이유로 `nil`이다.
    @Test func accessibilityStepIsNoOpAtDialEndsAndOutsideRange() {
        #expect(NotifyTimeSheet.dialAccessibilityStep(fromHour: 21, direction: .increment) == nil)
        #expect(NotifyTimeSheet.dialAccessibilityStep(fromHour: 6, direction: .decrement) == nil)
        #expect(NotifyTimeSheet.dialAccessibilityStep(fromHour: 3, direction: .increment) == nil)
        #expect(NotifyTimeSheet.dialAccessibilityStep(fromHour: 99, direction: .decrement) == nil)
        // 경계 안쪽으로는 정상 동작한다 — 위 nil이 "경계에서만"인지 확인(전면 무력화 뮤테이션 방지).
        #expect(NotifyTimeSheet.dialAccessibilityStep(fromHour: 21, direction: .decrement)?.hour == 20)
        #expect(NotifyTimeSheet.dialAccessibilityStep(fromHour: 6, direction: .increment)?.hour == 7)
    }

    // MARK: - 58차-c 호스팅 프로브(실물 무접촉 오픈)

    /// **실물 프로브 — 시트를 진짜로 띄워 놓고 아무것도 만지지 않는다.** 위 결정 함수 테스트들이
    /// 잠그는 것은 "판정이 옳다"이고, 이 프로브가 잠그는 것은 "그 판정이 실제 뷰의 커밋 경로에
    /// 연결돼 있다"다 — 게이트를 뷰에서 떼어 내도(예: `pendingScrollTarget`을 안 읽는 리팩터링)
    /// 순수 테스트는 전부 초록으로 남지만 이건 빨개진다.
    ///
    /// **불변식은 "최종값 유지"가 아니라 "값이 아예 안 바뀐다"다.** 58차-b가 기록했듯 이 환경에는
    /// 디스플레이 링크가 없어 `.task`의 `scrollTo`가 목표 행까지 못 갈 수 있다. 그래서 "펌프가
    /// 끝나면 9시로 정착해 있어야 한다"류 가드는 **옳은 코드로도** 실패한다. 새 게이트의 계약은
    /// 그 도착 여부에 의존하지 않는다: 목표에 못 닿으면 게이트가 영영 안 열려 커밋이 0회이고,
    /// 닿으면 해제만 되고 값은 그대로다. 어느 쪽이든 **쓰기 궤적이 비어 있다**.
    ///
    /// 시드를 9시(인덱스 3)로 두는 것이 핵심이다. 6시(인덱스 0)로 두면 정지 위치가 곧 목표라
    /// 첫 콜백에서 즉시 해제돼 게이트가 일한 적이 없고, 프로브는 아무것도 증명하지 못한다.
    /// 9시는 정지 위치(스냅 0~2 부근)와 목표(3)가 달라, 게이트가 없던 시절 정확히 그 간극에서
    /// 과도 오기록이 새어 나왔다.
    ///
    /// **궤적은 하한이다(58차-c 리뷰 MINOR-3).** 20ms 폴링은 한 프레임(≈16.7ms) 안에서 쓰였다
    /// 곧바로 되돌아가는 값을 놓칠 수 있고, 그 "쓰기→되돌리기"가 정확히 실기기에서의 과도 형태다
    /// (정착 콜백이 바로 따라붙는다). 이 프로브가 RED에서 `[7]`을 잡은 것은 폴링이 revert를
    /// 포착해서가 아니라, 이 환경에서 스크롤이 스톨해 **틀린 값이 안정적으로 머물렀기** 때문이다.
    /// 따라서 이 프로브를 실기기형 과도 검출기로 신뢰하지 말 것 — 프레임 내 과도의 **부재**를
    /// 지는 것은 위 순수 결정 함수 테스트들이다. 이 프로브가 지는 것은 "뷰가 게이트에 배선돼
    /// 있다"는 배선 계약뿐이다.
    ///
    /// **RED 재자격 검증 절차(58차-c 리뷰 MINOR-4).** 이 프로브의 판별력은 "호스팅 환경이 목표와
    /// 다른 지오메트리 콜백을 최소 한 번은 낸다"는 전제 위에 있다. SDK·호스트가 바뀌어 콜백이
    /// 아예 안 나오면 게이트를 통째로 떼도 초록이다(조용한 위음성). 그러니 이 프로브나 호스트를
    /// 손댈 땐 확인하라: **옛 게이트 코드(`isInteractive` 불리언 + `.task`에서 동기 켜기)로
    /// 되돌려 돌리면 `trajectory [7]`로 실패해야 한다**(2026-09-02 확인,
    /// `probe-RED-20260902-220345.xcresult`). 실패하지 않으면 판별력을 잃은 것이니 초록을
    /// 신뢰하지 말 것.
    @Test @MainActor func untouchedOpenNeverWritesStorage() {
        withKey(ExpiryNotifier.hourKey) {
            UserDefaults.standard.set(9, forKey: ExpiryNotifier.hourKey)

            let host = UIHostingController(rootView: NotifyTimeSheet())
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 300))
            window.rootViewController = host
            window.makeKeyAndVisible()
            // 위생(58차-c 리뷰 NIT-4) — 숨기는 것만으로는 rootViewController가 남는다. 스위트가
            // `.serialized`라 관측된 영향은 없었지만, 호스팅 잔여물을 다음 케이스로 흘리지 않는다.
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }

            // 매 틱 강제 레이아웃 + 런루프 펌프 — `.task`·프리젠테이션 지오메트리 콜백이 도는 창.
            // 틱마다 저장값을 훑는다(위 주석의 하한 단서 참조).
            var trajectory: [Int] = []
            for _ in 0..<40 {
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                let seen = UserDefaults.standard.integer(forKey: ExpiryNotifier.hourKey)
                if seen != 9, trajectory.last != seen { trajectory.append(seen) }
            }

            #expect(trajectory.isEmpty,
                    "무접촉 오픈이 저장값을 건드렸다(궤적 \(trajectory)) — 게이트가 커밋 경로에서 떨어졌다")
            #expect(UserDefaults.standard.integer(forKey: ExpiryNotifier.hourKey) == 9)
        }
    }
}
