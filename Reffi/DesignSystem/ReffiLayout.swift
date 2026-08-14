import SwiftUI

/// 스페이싱 스케일(§4.1) — 타이포 기준 6·8·12·16·24·28·32.
enum ReffiSpace {
    static let s1: CGFloat = 6    // 아이콘-텍스트, 칩 내부
    static let s2: CGFloat = 8    // 작은 간격, 모바일 거터, 인접 터치 간격
    static let s3: CGFloat = 12   // 인풋/버튼 내부 패딩
    static let s4: CGFloat = 16   // 기본 간격, 모바일 마진
    static let s5: CGFloat = 24   // 카드 패딩, 섹션 내 간격
    static let s6: CGFloat = 28   // 넓은 패딩
    static let s7: CGFloat = 32   // 섹션 간 분리
}

/// 곡률(§4.2) — 요소의 내부 패딩 토큰에 종속.
enum ReffiRadius {
    static let xs: CGFloat = 6     // 칩·태그·D-day 배지
    static let sm: CGFloat = 8     // 보조 컨트롤
    static let md: CGFloat = 12    // 버튼·인풋·미니 카드
    static let lg: CGFloat = 16    // 카드
    static let xl: CGFloat = 24    // 큰 카드 · 스택 카드 · 시트
    static let pill: CGFloat = 999 // 필 버튼·칩·내비·아바타
}

/// 모바일 그리드(§9.2) — 4컬럼 / 마진 16 / 거터 8.
enum ReffiGrid {
    static let margin: CGFloat = 16
    static let gutter: CGFloat = 8
    static let columns = 4
}

/// 요리 아이콘 크기(§13.7 요리 아이콘) — 표면마다 숫자를 손으로 흩뿌리면 티켓·공유 카드·목록이
/// 조금씩 다른 크기로 어긋난다. 세 자리만 두고 호출부는 전부 여기를 경유한다.
enum ReffiDishIcon {
    /// 목록 행 리딩(내 레시피) — 두 줄 텍스트 블록과 같은 높이.
    static let row: CGFloat = 36
    /// 공유 카드(340pt 폭) 메뉴명 옆 — 티켓보다 좁은 카드라 같은 시각 비중(≈0.23×콘텐츠 폭)을 유지한다.
    static let card: CGFloat = 56
    /// 오더·조리 티켓 메뉴명 옆 — 텍스트가 주인공인 채로 요리가 읽히는 하한.
    static let ticket: CGFloat = 68
}

/// 재료 실루엣 크기(§13.3 `PaperSilhouette`) — `ReffiDishIcon`이 요리 아이콘에 푼 문제를 재료 쪽에도 푼다.
/// 토큰이 없던 시절 같은 목록 행 역할에 28·32·34·36 네 값이 공존했다(탭을 오가면 같은 성격의 행이
/// 미묘하게 다른 크기로 보인다). 다섯 자리만 두고 호출부는 전부 여기를 경유한다.
enum ReffiFoodIcon {
    /// 좁은 면 안의 행 — 조리 티켓 재료 행, 온보딩 미니 영수증 행.
    static let rowMini: CGFloat = 32
    /// 목록 행 리딩 — 장보기·이력·냉장고 간편보기. 셋은 탭 전환으로 연달아 보는 같은 성격의 행이다.
    static let row: CGFloat = 36
    /// 냉장고 카드(스택) 안 실루엣 — 이름과 나란히 서는 크기.
    static let card: CGFloat = 46
    /// 검색 그리드 타일 — 그림이 주인공이고 이름이 캡션인 배치.
    static let tile: CGFloat = 56
    /// 펼친 상세 — 한 재료만 남은 화면의 주인공.
    static let hero: CGFloat = 64
}

/// 영수증 톱니(§13.5 `ReceiptShape`) — 앱의 시그니처 절취 엣지. 표면마다 숫자를 손으로 적으면
/// 같은 성격의 종이가 6·7·8·9로 갈린다(온보딩 한 파일에서만 세 값이 공존했다).
/// 세 자리만 두고 `ReceiptShape(tooth:)` 호출부는 전부 여기를 경유한다.
enum ReffiTooth {
    /// 미니 조각 — 홈 스트립·온보딩 소품처럼 폭이 좁아 톱니가 커지면 종이가 잘게 보이는 면.
    static let chip: CGFloat = 6
    /// 영수증 카드 — 목록·시트·이력의 기본 카드 면.
    static let card: CGFloat = 7
    /// 오더·조리·공유 티켓 — 가장 큰 종이라 절취 리듬도 가장 굵다.
    static let ticket: CGFloat = 9
}

/// 떠 있는 캡슐 네비의 실치수와 그 파생 여백(§9.3). 네비는 콘텐츠 위에 떠 있으므로 화면들이
/// "그만큼 비워 두는" 값을 각자 적어 왔고, 같은 목적의 여백이 이미 120과 96으로 갈렸다(한 파일 안에서
/// 주석은 96을 정본처럼 적는데 다른 줄은 120이었다). 진짜 위험은 값 불일치보다 **네비 높이를 바꾸면
/// 다섯 곳이 조용히 어긋난다**는 것이라, 전부 실치수에서 파생시킨다.
enum ReffiChrome {
    /// 캡슐 네비 실측 높이(`RootTabView`).
    static let navHeight: CGFloat = 58
    /// 홈 인디케이터 쪽으로 더 내린 오프셋.
    static let navBottom: CGFloat = 2

    /// **자리 예약** — 레이아웃이 네비 몫으로 비워 두는 높이(네비 발자국 + 숨 쉴 틈).
    /// 스크롤이 아니라 정적 배치에서 쓴다(하단 스택이 없을 때의 빈 자리 등).
    static let navReserve: CGFloat = navHeight + navBottom + ReffiSpace.s6 + ReffiSpace.s2

    /// **스크롤 꼬리 여백** — 끝까지 스크롤했을 때 마지막 카드가 네비 위로 올라오게.
    /// 자리 예약보다 카드 한 단(`s5`) 더 준다: 정지 배치와 달리 손가락이 마지막 카드를 만져야 한다.
    static let navClearance: CGFloat = navReserve + ReffiSpace.s5
}

/// 판정 존 규격(§13.4) — 홈의 판정 바스켓(SpriteKit)과 캐러셀의 플릭 예고 블롭(SwiftUI)은
/// DS가 "같은 문법"이라고 못 박은 한 쌍이다. 그런데 두 파일이 각자 `private let`으로 같은 숫자를
/// 들고 있었고, 결속은 "홈 존과 같은 값"이라는 주석뿐이었다 — 주석은 다음 튜닝을 막지 못한다.
/// 두 표면이 같은 심볼을 읽게 해 한쪽만 움직이는 일을 구조적으로 막는다.
enum ReffiJudgeZone {
    /// 블롭 한 변(정사각).
    static let side: CGFloat = 86
    /// 떠 있을 때 알파 — 완전 불투명이 아니라 종이가 살짝 비친다.
    static let alpha: Double = 0.96
    /// 커밋 임박(호버·임계 60% 초과) 하이라이트 배율 — 색은 바꾸지 않고 스케일만.
    static let hotScale: CGFloat = 1.14
    /// 등장·소멸 페이드(초).
    static let fade: TimeInterval = 0.15
    /// 하이라이트 전환(초).
    static let hotDuration: TimeInterval = 0.1
}

/// 상태 투명도(§7.2) — 디밍은 반드시 이 토큰으로. 리터럴을 호출부에 흩뿌리면
/// 컴포넌트 디밍과 곱해져(예: 0.45 × 0.5 = 0.225) CTA가 소실된다.
enum ReffiOpacity {
    static let disabled: Double = 0.45   // §7.2 disabled — 투명도만, 색 변경 X
}
