import SwiftUI

/// 앱 내 언어 선택(2026-08, 38차)의 **단일 진실 소스** — `ReffiFeedback`(감각 설정)과 같은 규율로,
/// `@AppStorage` 키를 여기 모으고 뷰가 아닌 곳(`ReffiApp.init()`)에서도 읽는 정적 접근자를 둔다.
///
/// **정직한 경계**: 이 선택은 두 층에 각각 다르게 적용된다.
///   ① `.environment(\.locale, ...)`(루트, `RootGateView`) — SwiftUI 자신이 리졸브하는
///      `LocalizedStringKey` 문자열(대부분의 버튼·행 라벨이 이 형태다)은 **곧바로** 반영된다.
///   ② `AppleLanguages` 오버라이드(`applyAppleLanguagesOverride()`) — `String(localized:)`로 이미
///      문자열로 굳힌 값(보간·동적 문구 등, 83곳)은 `Bundle.main`이 다음 실행에 다시 리졸브할 때만
///      바뀐다. 이 앱 안에서 두 리졸브 경로를 실시간으로 합칠 방법이 없다(스위즐 없이는) — 그래서
///      "일부는 즉시, 나머지는 재실행 후"라고 그대로 말한다(§Language 영수증 캡션).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, ko
    var id: String { rawValue }

    static let key = "app.language"

    /// 뷰 밖에서 읽는 현재 선택.
    static var current: AppLanguage { resolve(stored: UserDefaults.standard.string(forKey: key)) }

    /// 순수 판정(2026-08, 38차) — `FridgeTab.initial(from:)`과 같은 문법. 저장값이 없거나(최초 실행)
    /// 알 수 없는 문자열이면(구버전 잔재 등) 안전하게 system으로 접는다.
    static func resolve(stored: String?) -> AppLanguage {
        stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// 표시 라벨 — `en`·`ko`는 각자 자기 언어의 엔도님이라(§로케일 스위처 통례) 번역 대상이 아니다.
    /// `system`만 진짜 번역 문자열이라 **호출부가 "지금 화면이 보여 주는 언어"를 명시적으로 넘겨야**
    /// 한다 — `PaperDropdown`은 라벨을 항상 verbatim `String`으로 굳혀 그리므로(`(Value) -> String`),
    /// `.environment(\.locale)`에 기대면(암묵적 `String(localized:)`) 픽커를 연 순간의 번들 언어에
    /// 박제돼, 방금 한국어로 바꿨는데 옵션 목록의 "System default"만 영어로 남는 불일치가 생긴다.
    ///
    /// **`String(localized:locale:)`는 여기서 쓰지 않는다** — 실측으로 확인했다: 접근성 트리 덤프로
    /// 봤을 때 `locale: Locale(identifier: "ko")`를 명시해 줘도 이 프로젝트의 `.xcstrings` 카탈로그
    /// 에서는 여전히 영어로 리졸브됐다(38차, `dropdown_after_korean_tree.txt` 캡처로 확인 —
    /// `String(localized:)`가 카탈로그 SSOT라는 원칙과 부딪히지만, 문자열이 단 하나뿐이고 API가
    /// 이 환경에서 검증 가능하게 동작하지 않아 직접 두 언어를 박아 둔다). 카탈로그에서도
    /// 이 키를 제거했다 — 남겨 두면 아무도 안 읽는 죽은 항목이 된다.
    func displayName(in locale: Locale) -> String {
        switch self {
        case .system:
            return locale.language.languageCode?.identifier == "ko" ? "시스템 기본값" : "System default"
        case .en: return "English"
        case .ko: return "한국어"
        }
    }

    /// `.environment(\.locale, ...)`에 넣는 값 — system은 기기 로케일을 그대로 따른다(오버라이드 없음).
    var resolvedLocale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .en: return Locale(identifier: "en")
        case .ko: return Locale(identifier: "ko")
        }
    }

    /// **선택 언어 번들로 즉시 조회**(42차·O28/O29) — `String(localized:)`는 `Bundle.main`(=다음 실행)에
    /// 굳지만, 선택 언어의 `.lproj` 번들을 직접 지정하면 재실행 없이 그 언어로 리졸브된다.
    /// (38차 각주의 "`String(localized:locale:)`가 안 먹더라"는 API 오해였다 — `locale:`은 복수·숫자
    /// 규칙용이고 조회 언어는 `bundle:`이 정한다. 42차 검증에서 빌드 산출물의 ko.lproj 324키 확인.)
    /// `.system`이거나 번들을 못 찾으면 `Bundle.main`으로 폴백해 종전과 동일하게 동작한다.
    static func localizedNow(_ key: String.LocalizationValue) -> String {
        let bundle: Bundle
        switch current {
        case .system: bundle = .main
        case .en, .ko:
            if let path = Bundle.main.path(forResource: current.rawValue, ofType: "lproj"),
               let b = Bundle(path: path) { bundle = b } else { bundle = .main }
        }
        return String(localized: key, bundle: bundle)
    }

    /// `String(localized:)`·`.xcstrings` 번들 리소스가 **다음 실행부터** 이 언어를 쓰게 하는 표준
    /// 오버라이드. system을 고르면 키 자체를 지워 기기 언어 목록을 그대로 따르게 한다.
    func applyAppleLanguagesOverride() {
        switch self {
        case .system: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .en, .ko: UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
