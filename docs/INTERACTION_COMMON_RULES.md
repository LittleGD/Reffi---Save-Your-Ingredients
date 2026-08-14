# Reffi 인터랙션 커먼 룰 (v1)

> 2026-07-21 · `design_system.md`의 동반 스펙.
> 목표: 화면마다 제각각으로 조립되던 **닫기·헤더·저장·피드백·전환** 인터랙션을, "다름에 이유가 있는" 커먼 룰로 수렴한다.
> 이 문서는 3축 인터랙션 감사(시트/모달 · 내비게이션 · 버튼/피드백) 결과와, 그에 대한 12개 설계 결정을 정본으로 기록한다.

---

## 0. 배경과 감사 시점 주의

- **2026-08-01 갱신**: 추가 플로우가 영수증 스캔 단일 경로로 단순화되며 `IngredientPickerSheet`(픽커·검색·FREQUENT)·`CustomItemSheet`·스캔 카드가 삭제됐다. 아래 룰에서 이 심볼들을 가리키는 `file:line`과 액션 아이템은 **해소(대상 소멸)로 처리**한다 — 감사 이력 보존을 위해 본문은 남긴다.
- **2026-08-05 갱신**: 그 단일 경로에 **To buy 화면 한정 예외**가 생겼다 — 목록 하단 "Add item"이 여는 재료 검색 바텀시트(`ToBuySearchSheet`, `ShoppingListView.swift`)는 재고 추가가 아니라 **장보기 메모**라서다(근거·범위는 `design_system.md` §13.5). 아래 시트 룰(②③④·§14.5 detent)을 그대로 따르는 선택 시트이며, 탭마다 확정되므로 미저장 보호(룰⑨)는 해당 없다.
- **감사 대상**: HEAD 커밋(`1cfa1de`) 스냅샷의 `Reffi/` 소스 55개.
- **주의**: 저장소가 OneDrive 클라우드 폴더에 있어, 감사 도중 working tree가 HEAD보다 앞서 있었다. HEAD 기준으로 참이던 발견 일부(특히 `IngredientEditView`의 시스템 Form)는 이미 종이 문법으로 리팩터링되어 있었다. 아래 룰의 `file:line`은 **정의 시점(2026-07-21) working tree 기준으로 재검증한 값**이다. 구현 착수 시 실제 파일 상태를 다시 확인한다.
- **근본 원인**: 편차 대부분의 뿌리는 하나 — "닫기 헤더"와 "편집 시트 셸"이 컴포넌트로 추출되지 않아, 매 화면이 종이 X·타이틀·detent·커밋 버튼을 손으로 다시 조립했다. `PaperButton`·`PaperIconButton`처럼 추출된 곳은 편차가 0이다. 문서 규칙이 틀린 게 아니라, **규칙을 강제하는 컴포넌트가 없어** 드리프트가 생겼다.

---

## A. 닫기(Close) 시스템

### 룰 ① — 닫기 버튼 = `PaperCloseButton` 단일 컴포넌트
- **현행 편차**: 종이 X 버튼이 4가지 스펙으로 파편화.
  - 34 · `ReffiColor.paper` · seed 4 — `AddIngredientSheet.swift:144`, `:441`, `ReceiptScanView.swift:74`, `:374`
  - 40 · `.white.opacity(0.9)` · seed 1 — `HistoryView.swift:259`(CoverHeader), `CookingStepsView.swift:138`, `RecipeMemoCarousel.swift:164`
  - 40 · `ReffiColor.oklch(0.99, 0.006, 90)` · seed 4 — `FridgeView.swift:161`(doneBar)
  - 44 · `ReffiColor.paper` · seed 4 — `ProfilePreferenceSheets.swift:44`(SheetShell)
- **확정 룰**: **시각 40pt / 히트영역 44pt / 채움 `ReffiColor.paper` 단일 토큰**. `PaperRect(cornerRadius: .md)` 면 + `paperEdge` + `.paperPress` + `accessibilityLabel("Close")`.
  - 시각과 히트를 분리한다: `PaperRect` 자체는 40, `.frame(minWidth:44, minHeight:44)` 또는 `.contentShape`로 탭 영역 44 확보(§7.3).
  - `.white.opacity(0.9)`·`oklch(0.99)` 변형은 모두 `paper`로 흡수.
- **적용**: 위 7개 인라인 구현을 `PaperCloseButton`으로 교체.

### 룰 ② — 헤더 = 커버용·시트용 2개 컴포넌트
- **현행 편차**: 공용 `CoverHeader`(`HistoryView.swift:244`)가 있는데도 `CookingStepsView`·`RecipeMemoCarousel`이 복붙. 시트 헤더는 화면마다 따로 조립.
- **확정 룰**: 헤더를 **목적별 2개 컴포넌트로 분리**하고 각각 재사용을 강제한다.
  - `CoverHeader` (풀스크린 커버용): 기존 컴포넌트 유지 + `CookingStepsView`·`RecipeMemoCarousel`이 복붙 대신 이걸 사용.
  - `SheetHeader` (하단 시트용): **신설**. 좌측 타이틀 + `PaperCloseButton`(선택) + dragIndicator 전제.
- **적용**: 복붙 2곳 → `CoverHeader` 호출로 교체. 시트 헤더 인라인들 → `SheetHeader`로 교체.

### 룰 ③ — 헤더 타이틀 정렬·타이포
- **현행 편차**: 정렬은 대부분 좌측인데 `ReceiptScanView`만 중앙(`ZStack`). 타이포는 대부분 `.heading`인데 스캔 계열 2종만 `.subhead`(`ReceiptScanView.swift:68`, `:369`).
- **확정 룰**:
  - **커버 헤더 = 중앙 타이틀**, **시트 헤더 = 좌측 타이틀**. ("2개 분리"의 의도적 차이를 정렬로 표현.)
  - 타이포는 **커버·시트 모두 `.heading` 통일**. 스캔 계열의 `.subhead` 예외 제거.
- **적용**: `ReceiptScanView`의 중앙 정렬·`.subhead`를 시트 규칙(좌측·`.heading`)으로 교정.

### 룰 ④ — 닫기 방법 (모달 종류별)
- **현행 편차**: 종이 X / 시스템 Cancel 텍스트 / 스와이프 전용 / scrim 탭 4개 idiom 혼재. `AuthView`(`:46`)·조리완료 시트는 X·dragIndicator 모두 없어 닫기 신호가 0.
- **확정 룰**:
  - **하단 시트 = dragIndicator(핸들) + 스와이프 다운**으로 닫는다. X 버튼은 선택(핸들이 주 신호).
  - **풀스크린 커버 = 우상단/좌상단 `PaperCloseButton`(X)**로 닫는다.
  - 시트는 dragIndicator **필수**(핸들 없는 시트 금지).
- **적용**: `AuthView`·`CookingStepsView` finishSheet에 dragIndicator 추가. 시스템 Cancel 텍스트로 닫던 화면은 룰 ⑤/⑥에서 종이화되며 해소.
- **프로필 시트 6종 정렬(2026-08-13)**: 닉네임·Cuisines·Favorites·Disliked·Allergies·Alert time은 `presentationDragIndicator`가 한 곳도 없어 §14.3 필수 조항을 어기고 있었다(특히 `.height(260)`·`.height(300)` 단일 detent는 automatic으로도 그래버가 뜨지 않아 확정적으로 핸들이 없다). 호출부마다 붙이면 같은 드리프트가 재발하므로 **공용 셸 `SheetShell`(`ProfilePreferenceSheets.swift`)에서 한 번 선언**해 6종을 일괄 정렬했다. 이로써 `SheetHeader`가 전제하는 "헤더 + 핸들" 계약을 셸이 함께 보증한다.

---

## B. 편집 크롬

### 룰 ⑤ — 편집·목록 종이화
- **현행 편차**: `IngredientEditView`는 종이 문법으로 리팩터링됨. 그러나 `RecipeEditorView`(`MyRecipesView.swift:74-97`)와 목록(`MyRecipesView.swift:13`)은 아직 `NavigationStack { Form } .toolbar`(시스템 Cancel/Save).
- **확정 룰**: **커스텀 레시피 편집·목록을 모두 종이 문법으로 통일**한다 — 크림 캔버스(`--color-canvas`) + `SheetHeader` + 모노 섹션 라벨 + `DashedRule` + `PaperButton`. 시스템 `Form`·`NavigationStack`·글래스 툴바 제거.
- **적용**: `RecipeEditorView`를 `IngredientEditView`와 동일 문법으로 재작성. `MyRecipesView` 목록은 종이 카드 리스트로.

### 룰 ⑥ — 저장(커밋) = 성격별 2규칙
- **현행 편차**: 명시적 Cancel+Save 툴바 / 단일 Save 버튼 / 자동저장(선택 즉시 반영) 3갈래.
- **확정 룰**:
  - **편집·생성 시트**(재료·레시피·커스텀·후보): 하단 도킹 `PaperButton`(Save/Add)으로 **명시적 커밋**. 취소는 스와이프/닫기(룰 ⑨의 미저장 보호 적용).
  - **설정·선택 시트**(취향·알림시간 등 단일 선택): **자동저장** — 선택 즉시 반영, 저장 버튼 없이 닫기만.
- **적용**: `RecipeEditorView`·`CustomItemSheet`·`CandidateEditSheet`·`IngredientEditView`는 도킹 Save. `CuisinePickerSheet`·`TagEditorSheet`·`NotifyTimeSheet`는 자동저장(현행 유지, 규칙으로 명문화).
- **`NicknameEditSheet` 분류(2026-08-13)**: 어느 목록에도 이름이 없어 문서상 미분류였다. Save(`PaperButton`)로 명시 커밋하므로 **편집·생성 버킷**이고, 따라서 룰⑨ 미저장 보호가 적용된다(`IngredientEditView.requestClose()` 패턴 이식).

---

## C. 피드백·안전

### 룰 ⑦ — 햅틱 = 의미별 매핑 규칙 신설
- **현행 편차**: 같은 판정(Ate/Tossed)이 `MainView`엔 `.impact(light)` 있고 `FridgeView.remove(_:ate:)`(`:379`)엔 없음. 삭제·초기화 등 파괴 액션엔 햅틱 전무. `design_system.md`에 햅틱 조항 자체가 없음.
- **확정 룰**: `design_system.md` §7에 **햅틱 매핑 섹션을 신설**한다. 의미 → 트리거 매핑:
  - **판정·확정**(Ate/Tossed/Freeze, 발주) = `.impact`
  - **성공 완료**(저장·추가·재입고) = `.success`
  - **파괴 확인**(삭제·초기화 확정) = `.warning`
  - 같은 의미면 화면 불문 동일 햅틱.
- **적용**: `FridgeView` 판정에 `.impact` 추가. 파괴 확인(ProfileView 계정삭제·전체초기화, IngredientEditView·MyRecipesView 삭제)에 `.warning` 추가.
  - **로그아웃은 제외**: 세션만 해지하고 로컬 데이터를 지우지 않는다(룰 ⑧ 분류 참조) → 파괴 햅틱 없음.

### 룰 ⑧ — 파괴 확인 = 심각도로 구분
- **현행 편차**: `.alert`(로그아웃·계정삭제·알림안내)와 `.confirmationDialog`(샘플로드·초기화·조리취소·재료삭제)가 파괴성 동등한데 혼용(`ProfileView.swift:99,103,118,123,132`).
- **확정 룰**: 판정 축은 "undo 버튼이 있느냐"가 아니라 **확정 후 데이터를 되돌릴 수 있느냐**다.
  - **복구 불가능**(계정삭제·전체초기화·**샘플로드**) = `.alert` (중앙 고정, 실수 방지).
  - **국소·되돌리기 가능**(재료삭제·조리취소) = `.confirmationDialog` (트리거 근처). `FridgeStore.pendingUndo` 기반 undo 토스트가 떠서 dialog로 충분.
  - **데이터를 지우지 않는 상태 전환**(**로그아웃**) = `.confirmationDialog`. 세션만 해지하고 냉장고·이력·프로필은 이 기기에 남는다. 소유자 키(`data.ownerUserID`)가 직전 계정 id로 유지되고 뒤이어 붙는 익명 게스트 세션은 소유자 대조 대상이 아니라(`AuthStore.accountUserID`가 nil), 콜드 런치를 거쳐 같은 계정으로 재로그인해도 와이프가 없다(`ReffiApp.reconcileDataOwner` 보장 ①). 룰 ⑦ 파괴 햅틱도 해당 없음.
  - 순수 알림성(알림 꺼짐 안내)은 `.alert` 유지.
- **삭제 2종 정정(2026-08-13)**: 두 삭제가 dialog로 분류된 근거("`FridgeStore.pendingUndo` 기반 undo 토스트가 떠서 dialog로 충분")가 실제로는 비어 있었다 — `FridgeStore.remove(_:)`·`deleteUserRecipe(id:)` 어느 쪽도 `beginUndo`를 부르지 않았다. 판정 축("확정 후 되돌릴 수 있느냐")대로 각각 다르게 해소한다.
  - **재료삭제 = 전제를 채운다(확인 강도 유지)**: `remove(_:)`가 `beginUndo(.removed(name:))`를 호출해 6초 undo 토스트를 실제로 띄운다. 이 함수는 **이력 없는 삭제**라 `logIDs` 경로를 쓸 수 없다(로그를 만들면 낭비율·쇼핑리스트가 오염돼 함수의 정의가 깨진다) → `PendingUndo.restoreSnapshots`로 원본을 직접 들고 있다가 복원한다. dialog 유지.
  - **커스텀 레시피 삭제 = `.alert`로 승급**: undo 모델은 재료·이력 스냅샷 전용이라 사용자가 직접 쓴 레시피를 되살릴 장부가 없다. 억지로 얹으면 `PendingUndo`가 재료와 무관한 페이로드를 하나 더 짊어지고 토스트 카피·아이콘까지 갈라지므로, 사실대로 **복구 불가능**으로 재분류해 계정삭제·전체초기화·샘플로드와 같은 강도(`.alert` + 명시 Cancel + "This can't be undone" 카피)로 옮긴다. 호출부 2곳(`MyRecipesView` 목록 롱프레스·`RecipeEditorView` 삭제) 모두 이관.
- **샘플로드 정정(2026-07-26)**: 최초 초안은 샘플로드를 "되돌리기 가능(undo 토스트 있음)"으로 분류했으나 사실이 아니다. `FridgeStore.loadSampleData()`는 `ingredients`·`history`를 샘플로 통째 대체하기 전에 `pendingUndo = nil`로 **undo를 먼저 지운다**(`FridgeStore.swift:717`) → 확정 후 복구 불가. 따라서 `.alert`로 분류를 옮긴다.
- **적용**: 위 기준으로 각 호출부 재분류.
  - 반영 완료(2026-07-26): `ProfileView`의 샘플로드 호출부를 `.alert` + 명시 Cancel + 룰 ⑦ `.warning` 햅틱으로 이관했다(결과 명시 메시지는 유지).

### 룰 ⑨ — 미저장 보호 = 변경 시 Discard 확인
- **현행 편차**: `interactiveDismissDisabled`가 앱 전체 0건. 편집 시트가 스와이프 실수로 닫히면 입력 유실.
- **확정 룰**: **편집·생성 시트**에서 미저장 변경이 있을 때만, 스와이프/닫기 시 "변경을 취소할까요?" `confirmationDialog`(Discard Changes 패턴). 변경 없으면 자유 닫힘. 설정·선택 시트(자동저장)는 해당 없음.
- **적용**: 편집·생성 시트에 `@State private var isDirty` 추적 + `interactiveDismissDisabled(isDirty)` + Discard 다이얼로그.
  - 반영 완료(2026-08-13): `NicknameEditSheet`가 마지막 누락이었다 — 타이핑 후 스와이프로 닫으면 경고 없이 사라졌다(감사 R4-4). 초안 비교는 **트림 후** 값으로 한다(앞뒤 공백만 다르면 커밋 결과가 같아 dirty가 아니다).

---

## D. 전환·정책

### 룰 ⑩ — 전환 기표 = 위계로 구분
- **현행 편차**: 동일 `chevron(>)`이 어디선 하단 시트, 어디선 풀스크린 커버를 엶(진짜 push는 0건). `>`만으로 전환 결과 예측 불가.
- **확정 룰**: 전환 수단을 **시각 위계**로 예고한다.
  - **몰입 커버 진입** = 눈에 띄는 CTA 버튼(요리시작 등).
  - **시트 진입** = 조용한 `chevron` 행.
  - `chevron` 자체는 양쪽에 허용하되, 위계 차이로 무게를 구분.
- **적용**: 커버를 여는 진입점은 CTA 스타일로, 시트를 여는 진입점은 chevron 행으로 정렬. (감사 대상: `FridgeView` 요약카드, `MainView` cookingNow, `ProfileView` SettingsRow, `AddIngredientSheet` scanCard.)
  - 반영 완료(2026-08-13): `MainView` **Cooking now**가 마지막 편차였다 — 풀스크린 조리 커버를 열면서 조용한 톱니 영수증 행이라, 진행 중 세션 복귀가 과소 표현됐다(감사 R3-3). `FridgeView` 요약카드와 같은 **CTA 셰입**(`PaperCutRect` + `PaperGrain` + `shadow-1`, minHeight 56)으로 올렸다. **색은 종이 면 그대로** — 셰입만 CTA급이고 blue 솔리드 면은 `Start cooking` 하나다(§2.4). 같은 슬롯의 **알림 배너는 커버를 열지 않으므로 영수증 스트립을 유지**해, 한 자리에 번갈아 뜨는 두 카드가 셰입만으로 전환 결과를 예고한다.

### 룰 ⑪ — 시트 높이(detent) = 콘텐츠 양별 3단
- **현행 편차**: `.medium` / 고정높이(`.height(260/300)`) / 미설정(풀높이)이 기준 없이 혼재. `AuthView`·`RecipeEditor` 등은 detent 없이 무조건 풀높이. — **해소(2026-08-13)**: `RecipeEditorView`는 `.medium/.large`로, `AuthView`는 `.large` 단일 단으로 이관해 미설정 시트가 0이 됐다(선언 위치는 "시트 설정은 시트 안에서" 관례대로 각 뷰 내부).
- **확정 룰**:
  - **짧은 단일 입력**(닉네임·시간) = `.height(...)` 고정.
  - **중간 목록·폼**(추가·편집) = `.medium` 진입, 키보드/긴 내용 시 `.large` 승격.
  - **긴 목록**(레시피 목록 등) = `.large`.
- **적용**: 미설정(풀높이) 시트들에 콘텐츠 분량에 맞는 detent 부여.

### 룰 ⑫ — UndoToast 위치 = 상단 유지 + 문서 수정
- **현행 편차**: `design_system.md`는 "하단 잉크 캡슐(네비 위)"로 규정하나 코드는 상단 overlay(`RootTabView.swift:37`). 코드 주석이 "하단 CTA·네비를 안 가리려 상단으로 옮겼다"고 밝힘.
- **확정 룰**: **코드 현행(상단)을 정본으로 유지**하고, `design_system.md`의 토스트 위치 문구를 **상단으로 수정**한다. (하단 CTA·네비 겹침을 이미 회피한, 동작 검증된 상태.)
- **적용**: `design_system.md` §13.6-5 및 토스트 관련 문구를 상단으로 정정. 코드 변경 없음.

---

## E. 문서 위반 수정 (질문 없이 수정 — 이미 규칙이 있는데 코드가 어긴 것)

### E1 — reduced motion (§7.4 "필수")
- `AuthView.swift:181`: `ReffiMotion.gated(..., reduce: false)` 하드코딩 → `@Environment(\.accessibilityReduceMotion)` 읽어 전달.
- `ShoppingListView.swift:74`, `:91`: `withAnimation(ReffiMotion.settle)` 무조건 실행 → reduceMotion 게이팅 추가.

### E2 — disabled opacity (§7.2 = 0.45 고정)
- `MainView.swift:92`, `ReceiptScanView.swift:165`: `0.5` → `0.45`.
- (구조적 개선 후보) `PaperPressStyle`/`ReffiPressStyle`이 `@Environment(\.isEnabled)`를 읽어 자동 dimming하도록 하면 호출부 드리프트 원천 차단. — 별도 검토.

---

## F. 신설 컴포넌트 스펙

### `PaperCloseButton`
```
PaperCloseButton(seed: Int = 4, action: () -> Void)
```
- 시각 40 · 히트 44 · `ReffiColor.paper` 면 · `paperEdge` · `.paperPress` · `accessibilityLabel("Close")`.
- 커버 헤더·시트 헤더·doneBar 등 모든 종이 X를 이 컴포넌트로 대체.

### `PaperButtonLabel` (2026-08-13 추가)
```
PaperButtonLabel(title: LocalizedStringKey, kind: .primary | .secondary, fullWidth: Bool = true, seed: Int = 0)
```
- `PaperButton`의 **표면만** 떼어낸 조각. `PaperButton`은 이걸 `Button` 안에 넣어 만든다(규격이 한 곳에서 나온다).
- `Button`이 아닌 컨트롤(`PhotosPicker`·`ShareLink` 등)에 CTA 재질을 씌울 때 쓰고, 호출부가 `.buttonStyle(.paperPress)`를 함께 건다(선례: `CookingStepsView`의 ShareLink + `PaperIconLabel`).
- **금지**: 종이 CTA 면을 호출부에서 손으로 재조립하는 것 — fill 토큰·`PaperGrain`·`--shadow-1`·프레스가 갈려 secondary CTA가 두 종류로 보인다(`ReceiptScanView`의 "Choose photos"가 그 사례였다).

### `SheetHeader`
```
SheetHeader(title: LocalizedStringKey, showsClose: Bool = false, onClose: (() -> Void)? = nil)
```
- 좌측 타이틀(`.heading`, **한 줄·말줄임**) + (선택)`PaperCloseButton`. dragIndicator는 시트 프레젠테이션 측에서 `.visible`(`SheetShell`을 쓰면 셸이 보증한다).
- 하단 시트 헤더의 유일한 공급원. **예외 0(2026-08-13)** — 마지막 인라인 헤더였던 `IngredientEditView`가 "동적 타이틀 truncation 보호" 때문에 커스텀 HStack을 유지했는데, 그 보호를 컴포넌트가 흡수하며(모든 시트가 함께 안전해진다) 예외 사유가 사라졌다. 인라인으로 두면 패딩이 달라(위 s4/아래 s2 vs s5/s3) 시트 간 타이틀 기준선이 어긋난다.

### `CoverHeader` (기존, 재사용 강제)
- 중앙 타이틀(`.heading`) + `PaperCloseButton`(X). 풀스크린 커버의 유일한 공급원.
- `CookingStepsView`·`RecipeMemoCarousel`의 복붙 제거하고 이걸 호출.

---

## G. `design_system.md` 반영 목록
1. **햅틱 매핑 섹션 신설**(§7 하위) — 룰 ⑦.
2. **닫기 시스템 명문화** — 룰 ①②③④: `PaperCloseButton` 스펙, 헤더 2종, 정렬·타이포, 모달 종류별 닫기 방법.
3. **저장 모델 명문화** — 룰 ⑥: 편집·생성=도킹 Save / 설정·선택=자동저장.
4. **detent 정책 명문화** — 룰 ⑪: 콘텐츠 양별 3단.
5. **미저장 보호 명문화** — 룰 ⑨.
6. **파괴 확인 강도 명문화** — 룰 ⑧: 복구 불가능=`.alert` / 되돌리기 가능=`.confirmationDialog` / 데이터 미삭제 상태 전환(로그아웃)=`.confirmationDialog` / 순수 알림성=`.alert`.
7. **UndoToast 위치 정정** — 룰 ⑫: 하단 → 상단.

---

## H. 범위 밖 (YAGNI — 이번에 하지 않음)
- 다크 모드 토큰(현재 라이트 고정 — `design_system.md` §2.1).
- 시스템 push 스택(`NavigationLink`) 도입 — 앱은 의도적으로 모달+상태스위칭 아키텍처. 유지.
- 큰 플로우 전환 애니메이션(온보딩→메인, 로그아웃) — 낮음 심각도, 별도 과제.
- ~~`Menu`(sortMenu)의 눌림 피드백 — SwiftUI 플랫폼 제약, 손대지 않음.~~ **철회(2026-07-26)**: 같은 작업에서 스톡 `Menu`를 앱 커스텀 `PaperDropdown`(`Reffi/Components/PaperDropdown.swift`)으로 교체해, 눌림 피드백이 종이 문법(`.paperPress`)으로 들어왔다. 플랫폼 제약은 컴포넌트 교체로 해소됐고 이 항목은 더 이상 범위 밖이 아니다.
  - **범위 정정 + 완료(2026-08-13)**: 위 문장은 "전면 교체"라고 적었지만 실제 교체율은 1/5였다 — 냉장고 정렬 1곳만 `PaperDropdown`이고 편집 시트의 단위·보관 선택 4곳은 스톡 `.pickerStyle(.menu)`로 남아, "탭 → 옵션 목록"이 두 문법으로 갈려 있었다(감사 R4-6). 이번에 네 곳을 모두 이관해 `.pickerStyle(.menu)`가 **0**이 됐다(남은 스톡 픽커는 `NotifyTimeSheet`의 `.wheel` 하나 — 시각 선택은 목록이 아니라 다이얼이라 다른 문법이다).
  - 시트 안 앵커링은 정렬 칩과 조건이 다르다 — 시스템 팝오버와 달리 오버레이는 시트 밖으로 나갈 수 없다. 그래서 `paperDropdownOverlay(...)` 모디파이어가 **아래/위 여유를 재 뒤집고 팝업 높이를 캡**하며, 넘치면 `PaperDropdown(maxHeight:)`이 내부 스크롤한다(단위 10종). 한 화면에 트리거가 둘이므로 **열린 트리거만 앵커를 발행**해 `DropdownAnchorKey`의 "화면당 한 개" 전제를 지킨다.

---

## 구현 우선순위 (제안)
1. **`PaperCloseButton` + 헤더 2종 추출·적용** (룰 ①②③) — 편차가 가장 많고, 한 번에 여러 화면 정리.
2. **편집 크롬 종이화 + 저장/미저장 보호** (룰 ⑤⑥⑨) — 편집 언어 완전 통일.
3. **햅틱·파괴 확인·닫기 방법** (룰 ④⑦⑧) — 피드백 일관성.
4. **detent·전환 위계·문서 위반 수정** (룰 ⑩⑪ + E1·E2).
5. **`design_system.md` 반영** (§G) + UndoToast 문구 정정(룰 ⑫).
