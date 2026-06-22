import CoreGraphics

/// 스페이싱 스케일 (§4.1) — 타이포 기준 4px 그리드.
/// `6`은 의도적 예외(칩/아이콘 미세 간격), `28`은 4×7.
enum Space {
    static let s1: CGFloat = 6   // 아이콘-텍스트, 칩 내부
    static let s2: CGFloat = 8   // 작은 요소 간격, 모바일 거터
    static let s3: CGFloat = 12  // 인풋/버튼 내부 패딩
    static let s4: CGFloat = 16  // 기본 간격, 모바일 마진
    static let s5: CGFloat = 24  // 카드 패딩, 섹션 내 간격
    static let s6: CGFloat = 28  // 넓은 패딩
    static let s7: CGFloat = 32  // 섹션 간 분리
}

/// 곡률 (§4.2) — 요소 내부 패딩에 종속. 카드/필/배지의 곡률 대비가 "지갑" 무드.
enum Radius {
    static let xs: CGFloat = 6    // 칩·태그·D-day 배지
    static let sm: CGFloat = 8    // 보조 컨트롤
    static let md: CGFloat = 12   // 버튼·인풋·미니 카드
    static let lg: CGFloat = 16   // 카드
    static let xl: CGFloat = 24   // 큰 카드 · 스택 카드 · 시트 · 모달
    static let pill: CGFloat = 999 // 필 버튼·칩·내비·아바타
}
