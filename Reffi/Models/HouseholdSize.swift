import Foundation
import SwiftUI

/// 가구 인원 — 레시피 양·쇼핑 수량 조절의 근거(타겟: 1인 가구·맞벌이, 명세 §1 개요).
/// rawValue는 UserDefaults 영속화용 안정 키.
enum HouseholdSize: String, CaseIterable, Identifiable, Codable {
    case one, two, family, large

    var id: String { rawValue }

    /// 칩 라벨 **키**(42차) — `SelectableChip`이 키를 받아 `\.locale` 환경으로 리졸브한다
    /// (`CuisineStyle.labelKey`와 같은 이유 — String은 조회 시점 번들에 굳는다).
    var labelKey: LocalizedStringKey {
        switch self {
        case .one:    "Just me"
        case .two:    "2 people"
        case .family: "3-4"
        case .large:  "5+"
        }
    }

    /// 칩 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
    var label: String {
        switch self {
        case .one:    AppLanguage.localizedNow("Just me")
        case .two:    AppLanguage.localizedNow("2 people")
        case .family: AppLanguage.localizedNow("3-4")
        case .large:  AppLanguage.localizedNow("5+")
        }
    }

    /// 레시피 양 계산용 대표 인원수(추천 연동 시 사용).
    var servings: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .family: 4
        case .large: 6
        }
    }

    /// 재입고 기본 수량 배율 — **개수 차원 단위(개·팩·묶음 등)에만** 적용하는 결정적 정수 배율.
    /// 인원수 그대로의 선형 스케일(1/2/4/6)이 아니라 완만한 계단(1/1/2/3)이다 — 한 탭 추가·재입고가
    /// 등록 폼 없이 즉시 반영되는 경로라, 인원이 늘어도 g/ml 같은 연속 단위나 과도한 개수로 튀지 않게
    /// 보수적으로 잡았다(실제 필요량은 재료마다 달라 이 배율은 "대략의 방향"만 맞춘다).
    var quantityMultiplier: Double {
        switch self {
        case .one: 1
        case .two: 1
        case .family: 2
        case .large: 3
        }
    }
}
