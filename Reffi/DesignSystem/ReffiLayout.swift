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

/// 요리 아이콘 크기(§13.3 일러스트) — 표면마다 숫자를 손으로 흩뿌리면 티켓·공유 카드·목록이
/// 조금씩 다른 크기로 어긋난다. 세 자리만 두고 호출부는 전부 여기를 경유한다.
enum ReffiDishIcon {
    /// 목록 행 리딩(내 레시피) — 두 줄 텍스트 블록과 같은 높이.
    static let row: CGFloat = 36
    /// 공유 카드(340pt 폭) 메뉴명 옆 — 티켓보다 좁은 카드라 같은 시각 비중(≈0.23×콘텐츠 폭)을 유지한다.
    static let card: CGFloat = 56
    /// 오더·조리 티켓 메뉴명 옆 — 텍스트가 주인공인 채로 요리가 읽히는 하한.
    static let ticket: CGFloat = 68
}

/// 상태 투명도(§7.2) — 디밍은 반드시 이 토큰으로. 리터럴을 호출부에 흩뿌리면
/// 컴포넌트 디밍과 곱해져(예: 0.45 × 0.5 = 0.225) CTA가 소실된다.
enum ReffiOpacity {
    static let disabled: Double = 0.45   // §7.2 disabled — 투명도만, 색 변경 X
}
