import Foundation

/// 프로세스 간에 **안정적인** 문자열 해시(FNV-1a).
///
/// `String.hashValue`는 실행마다 시드가 바뀐다 — 그걸로 종이결 시드나 요리 색을 뽑으면 같은 항목이
/// 런치마다 다르게 그려지고 스크린샷 회귀 테스트가 성립하지 않는다. 시각 결정에 쓰는 해시는 전부
/// 여기 하나를 쓴다: 요리 아이콘 카탈로그(색·고명)와 장보기 검색 타일(종이결 시드)이 같은 규칙을
/// 공유하되, 냉장고 화면이 아이콘 카탈로그를 import 하는 역의존은 만들지 않기 위해 모델 층에 둔다.
enum ReffiHash {
    /// FNV-1a 64bit — 값 자체에 암호학적 의미는 없다(시드 뽑기 전용).
    static func stable(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01b3 }
        return h
    }
}
