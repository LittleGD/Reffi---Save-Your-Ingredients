import SwiftUI
import PhosphorSwift

/// Phosphor(MIT) 아이콘 단일 진입점. 모두 SVG 라인, currentColor 상속(§5).
/// 케이스명이 바뀌면 이 파일만 고친다. 색 채운 아이콘 박스 금지(§5).
enum ReffiIcon {
    // 네비
    static var home: Ph { .house }
    static var fridge: Ph { .snowflake }   // 냉장고 = 냉기 메타포(Phosphor에 냉장고 직접 아이콘 없음)
    static var add: Ph { .plus }
    static var profile: Ph { .user }

    // 콘텐츠
    static var recipe: Ph { .cookingPot }
    static var cook: Ph { .bowlSteam }
    static var ate: Ph { .bowlSteam }
    static var toss: Ph { .trash }
    static var ai: Ph { .sparkle }
    static var go: Ph { .arrowRight }
    static var chevron: Ph { .caretRight }
    static var time: Ph { .clock }
    static var countdown: Ph { .clockCountdown }
    static var undo: Ph { .arrowCounterClockwise }
    static var youtube: Ph { .youtubeLogo }   // 조리 티켓 — 요리 예시 영상 링크(§13.6)
    static var share: Ph { .shareFat }        // 조리 티켓 — 레시피 공유, 시스템 공유 시트(§13.6)
    /// 티켓 왼쪽 플릭 예고(Pass, §13.6) — 이 티켓을 덱 뒤로 넘기고 다음 티켓을 올린다.
    /// **순환 화살표**인 이유: Pass의 실제 동작이 `advance()` = 앞 티켓이 덱 뒤로 돌아가고 다음이
    /// 올라오는 **순환**이라 기호가 동작 사실과 그대로 맞는다. 파괴(휴지통)도 거절(✕)도 아니다 —
    /// 넘긴 티켓은 사라지지 않고 덱 안에 남는다.
    /// 후보 배제 근거: `skipForward`는 미디어 "끝으로" 기호라 실사용에서 의미가 읽히지 않았고
    /// 왼쪽 플릭과 방향도 어긋난다. ✕ 계열은 같은 화면 우상단 `PaperCloseButton`과 기호가 충돌한다.
    static var pass: Ph { .arrowsClockwise }

    // 냉장고 툴바 · 리포트
    static var sort: Ph { .arrowsDownUp }
    static var compactView: Ph { .rows }
    static var stackView: Ph { .cards }
    static var report: Ph { .chartDonut }
    static var check: Ph { .check }

    // 재료 추가 시트
    static var receipt: Ph { .receipt }
    static var camera: Ph { .camera }
    static var barcode: Ph { .barcode }
    static var manual: Ph { .pencilSimple }
    static var close: Ph { .x }
    static var search: Ph { .magnifyingGlass }   // 일러스트 사전 픽커 검색 필드(§13.5)

    // 냉동(버리기 직전 구제, §13.6) — 판정 커버의 3번째 선택지.
    static var freeze: Ph { .snowflake }
    static var delete: Ph { .trashSimple }
}

extension Ph {
    /// Reffi 표준 아이콘 렌더 — 템플릿 틴트(§5 currentColor) + 정사각 사이즈.
    /// 색은 호출부에서 `.foregroundStyle(...)`로 준다(파스텔 면 위 ink / Blue 면 위 white).
    func reffi(_ size: CGFloat, _ weight: Ph.IconWeight = .regular) -> some View {
        self.weight(weight)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
