import SwiftUI

/// 재료 추가 시트 — 중앙 ＋의 목적지. **영수증 스캔이 추가 플로우의 주역이다**
/// (사용자 결정 2026-08-01: 일러스트 사전 픽커·검색 폼은 주 플로우에서 제거됐다.
/// 지금 냉장고에 재료가 없는데 뭔가 사려는 상황을 상정하지 않는다 — 장 본 뒤 영수증으로
/// 한 번에 등록하는 사용 패턴에 집중한다).
/// 직접 입력은 그 아래 조용한 링크 한 줄로만 남는다(사용자 결정 2026-08-19) — 주역을 흐리지 않되
/// 영수증이 없는 날의 탈출구는 열어 둔다.
///
/// 얇은 래퍼로 유지한다 — 호출부(MainView·RootTabView·`-previewAdd`)가 여전히
/// `AddIngredientSheet()`를 시트로 열면 되게끔, 실제 내용은 `ReceiptScanView`에 전부 위임한다.
/// presentationDetents 등 시트 설정은 `ReceiptScanView` 내부에서 적용한다(호출부 중복 금지).
struct AddIngredientSheet: View {
    var body: some View {
        ReceiptScanView()
    }
}
