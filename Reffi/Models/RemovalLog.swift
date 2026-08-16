import Foundation

/// 소비/버림 이력 한 줄 — History·낭비율의 소스. 처리 시각은 절대 시각(`removedAt`)이 원본.
/// `snapshot`은 되돌리기(undo) 복원용 재료 원본, `via`는 레시피 발주(Fire the Ticket)로
/// 소비된 경우 그 레시피명 — History에서 "한 요리"로 묶어 보여준다.
struct RemovalLog: Identifiable, Codable {
    var id: UUID
    var name: String
    var glyph: FoodGlyph
    var canonicalID: String?    // 정본 사전 캐논 ID — removeLogging에서 재료 값을 복사(표기 무관 매칭). 레거시=nil(로드 시 승격)
    var removedAt: Date
    var wasted: Bool            // true = 버림(Tossed), false = 먹음(Ate)
    var via: String?            // 발주 레시피명(직접 판정이면 nil)
    var snapshot: Ingredient?   // undo 복원용(샘플 이력엔 없음)

    init(id: UUID = UUID(), name: String, glyph: FoodGlyph, canonicalID: String? = nil,
         removedAt: Date = Date(), wasted: Bool, via: String? = nil, snapshot: Ingredient? = nil) {
        self.id = id
        self.name = name
        self.glyph = glyph
        self.canonicalID = canonicalID
        self.removedAt = removedAt
        self.wasted = wasted
        self.via = via
        self.snapshot = snapshot
    }

    /// 상대 일수 편의 생성자(샘플) — 며칠 전 처리를 절대 시각으로 바꿔 저장.
    init(name: String, glyph: FoodGlyph, daysAgo: Int, wasted: Bool) {
        self.init(name: name, glyph: glyph, removedAt: Ingredient.day(offset: -daysAgo), wasted: wasted)
    }

    /// 재료 동일성 키 — 표기 무관(Ingredient.matchKey와 같은 규칙). 쇼핑리스트 그룹핑·재입고 조회의 기준.
    var matchKey: String { canonicalID ?? name.lowercased() }

    /// 화면에 그릴 이름 — `Ingredient.displayName`과 같은 규칙(캐논 ID가 있으면 사전에서 재해석).
    var displayName: String {
        canonicalID.flatMap { IngredientLexicon.shared.entry(id: $0)?.displayName } ?? name
    }

    /// 처리 후 경과 일수(자정 기준).
    var daysAgo: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: removedAt),
                                  to: cal.startOfDay(for: Date())).day ?? 0
    }

    var dateText: String { removedAt.formatted(date: .abbreviated, time: .omitted) }
}
