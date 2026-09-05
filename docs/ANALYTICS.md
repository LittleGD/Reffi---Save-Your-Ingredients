# Reffi 행동 계측·리텐션 측정 가이드

> 2026-09-05(64차). 앱이 사용자의 행동을 어떻게 데이터로 남기고, 그 데이터로 리텐션과 UX 지표를
> 어떻게 읽는지의 **정본**이다. 코드(`Reffi/Data/Analytics.swift`)·서버(`supabase/migrations/0002_analytics.sql`)와
> 어긋나면 이 문서를 먼저 고친다.

## 0. 한눈에

| 항목 | 결정 |
|---|---|
| 방식 | **1st-party.** 서드파티 SDK 없이, 이미 쓰는 Supabase에 이벤트 테이블 하나(`public.analytics_events`)로 쌓는다 |
| 사용자 식별 | Supabase Auth **uid**(익명 세션 포함). 게스트가 가입해도 같은 uid가 이어져 코호트가 끊기지 않는다 |
| 세션 | 마지막 활동 후 **30분** 무활동이면 새 세션(GA4와 같은 정의) |
| 저장·전송 | 기기 큐(JSON, 상한 1000) → 포그라운드·백그라운드·20건 누적·로그인 시점에 100건씩 업로드, 실패 시 60초 뒤 재시도 |
| 개인정보 | 재료 이름·구매처·닉네임·이메일은 **싣지 않는다**. 글리프(닫힌 enum)·건수·일수·시드 레시피 슬러그까지만 |
| 옵트아웃 | 프로필 › App › **Share usage data** 토글(기본 켬). 끄면 큐까지 비운다. "Erase this device"는 install id도 새로 발급 |
| 개발 오염 방지 | DEBUG 빌드는 `channel = 'debug'`로 올라가고 지표 뷰는 `release`만 집계. 유닛 테스트 호스트에선 아예 꺼짐(`-analyticsOff`도 동일) |
| 지표 | `analytics.*` 뷰(대시보드 SQL Editor에서 바로 조회). DAU/WAU/MAU·끈끈함, D1~D30·W1~W8 리텐션, 핵심 루프, 퍼널, 세션, 화면, 스캔 품질, 낭비 글리프 |

## 1. 왜 이렇게 측정하나

Reffi의 존재 이유는 "냉장고 속 재료를 **버리기 전에 오늘 먹게** 만드는 것"이다. 그래서 리텐션은
"앱을 다시 열었는가"만으로는 부족하고, **핵심 루프를 다시 돌았는가**로 읽어야 한다.

```
재료 넣기 ──▶ 오늘의 티켓(덱) 열기 ──▶ 발주(Cook this) ──▶ 조리 완료 ──▶ 먹음/버림 판정
 ingredient_add   deck_open            ticket_fire        cook_finish     ingredient_decide
```

측정 축 세 가지:

1. **돌아오는가** (리텐션) — 첫 활동일 기준 코호트의 D1/D7/D30, 주 코호트의 W1~W8.
2. **루프를 도는가** (핵심 루프·퍼널) — 주간 활성 사용자 중 넣기·덱·발주·완료에 닿은 비율, 발주당 완료율.
3. **덜 버리는가** (성과) — 낭비율(앱 History와 같은 정의), 버릴 때 며칠 남았었나(알림 리드타임의 근거), 글리프별 낭비.

세션 길이·화면 분포·스캔 품질·사전 적중률은 위 셋을 설명하는 **진단 지표**다.

서드파티(Firebase·Amplitude 등)를 쓰지 않은 이유: 이미 Supabase가 붙어 있어 사용자 id를 새로 만들 필요가
없고(익명→가입 승계가 그대로 코호트 연속성이 된다), 데이터가 우리 프로젝트 안에 남으며, 앱 스토어
프라이버시 신고 항목이 늘지 않는다. 필요해지면 `analytics_events`를 그대로 외부 도구로 내보내면 된다.

## 2. 식별자와 세션

| 이름 | 어디서 | 수명 |
|---|---|---|
| `user_id` | 서버가 `auth.uid()`로 채운다. 클라이언트는 이 컬럼에 쓸 권한이 없다 | 계정. 익명→가입 승계 시 유지 |
| `install_id` | 앱이 최초 실행에 생성(UserDefaults) | 설치. "Erase this device"·재설치로 교체 |
| `session_id` | 30분 규칙으로 앱이 자른다 | 세션 |
| `seq` | 설치별 단조 증가 | `(install_id, seq)`가 서버 유니크 → 재전송이 멱등 |

세션 규칙(`Analytics.ensureSession`):
- 이벤트를 남기려는 순간 마지막 활동으로부터 30분이 지났으면 새 `session_id`를 만들고 `session_start{cold}`를 낸다.
  `cold`는 **이 프로세스의 첫 세션**이면 true(콜드 런치), 30분 넘게 뒀다 돌아와 같은 프로세스에서 새 세션이 열리면 false.
- 백그라운드 진입마다 `app_background{seconds}`(세션 시작 후 경과 초). 한 세션이 여러 번 백그라운드를
  오갈 수 있으므로 **세션 길이 = 그 세션의 `seconds` 최댓값**이다(`analytics.sessions`).
- 세션 상태(id·시작·마지막 활동)는 UserDefaults에 남아 프로세스가 죽었다 살아나도 30분 규칙이 이어진다.
- 새 세션이 열릴 때 보고 있던 화면이 있으면 `screen_view`를 한 번 더 낸다(화면 전환 없이 돌아온 세션에도 첫 화면이 남게).

세션 없이 시작한 이벤트(로그인 전)는 큐에 쌓였다가 세션이 생기는 순간(`auth_signin`) 업로드된다.
Supabase **익명 로그인이 꺼져 있으면 로컬 게스트는 uid가 없어 영영 못 올린다** — §6의 대시보드 토글이 전제다.

## 3. 이벤트 사전

이름·속성은 `AnalyticsEvent`(닫힌 enum)와 1:1. 속성은 평평한 JSON(`props`). 문자열 API는 없다 — 새
이벤트는 enum case를 추가하고 이 표와 서버 뷰를 함께 고친다.

### 수명주기

| 이벤트 | 언제 | 속성 |
|---|---|---|
| `session_start` | 새 세션 | `cold: bool` |
| `app_background` | 백그라운드 진입 | `seconds: int` 세션 시작 후 경과 |
| `screen_view` | 표면 노출(연속 중복은 접힘) | `screen`: `home` `fridge.stock` `fridge.tobuy` `fridge.history` `profile` `onboarding` `auth` `deck` `cook` `decision` `add` `edit` `my_recipes` |
| `onboarding_complete` | 온보딩 종료(건너뛰기 포함) | `skipped: bool`, `household`(one/two/family/large), `cuisines: int`, `alerts: bool` |
| `notification_open` | 임박 알림 배너 탭 | – |
| `notification_permission` | 시스템 권한 요청 결과 | `granted: bool` |
| `alerts_toggled` | 프로필 알림 토글 | `on: bool`, `hour: int`. 권한 거부 롤백도 `on:false`로 떨어진다 — 직전 `notification_permission{granted:false}`로 가른다 |
| `language_change` | 앱 언어 변경 | `to`: system/en/ko |

### 재료

| 이벤트 | 언제 | 속성 |
|---|---|---|
| `receipt_scan` | OCR·파서가 후보를 낸 직후 | `source`: camera/photos, `pages`, `candidates`, `matched`(사전 매칭 후보 수) |
| `ingredient_add` | 재고 추가(어느 입구든) | `source`: manual/receipt/restock, `count`, `known`(캐논 키가 붙은 수 = 사전 커버리지) |
| `ingredient_edit` | 편집 저장 | `renamed: bool` |
| `ingredient_delete` | 이력 없는 삭제(정정) | – |
| `ingredient_freeze` | 냉동 구제 | `days_left`(구제 시점의 원래 여유) |
| `ingredient_pin` | 오늘 요리 핀 토글 | `on: bool` |
| `ingredient_decide` | 먹음/버림 판정 | `outcome`: ate/tossed, `surface`: badge(배지 탭 커버)/zone(홈 존 드래그)/fridge(냉장고 영수증)/other, `days_left`(유예 시계 기준), `frozen`, `glyph`(FoodGlyph rawValue) |
| `sealed_check` | 개봉 확인 답변 | `opened`, `still_sealed` |

### 티켓·조리

| 이벤트 | 언제 | 속성 |
|---|---|---|
| `deck_open` | 오늘의 티켓 덱 열림 | `tickets`, `pinned`, `at_risk` |
| `ticket_pass` | 왼쪽 플릭·Next ticket | `recipe`(시드 슬러그 또는 `custom`), `passes`(누적) |
| `ticket_fire` | Cook this(발주) | `recipe`, `used`, `missing`, `substituted`, `urgent` |
| `cook_finish` | 조리 완료 확정 | `recipe`, `used`(소비 확정 수), `leftovers`, `steps_done`, `steps_total`, `minutes`(발주 후 경과) |
| `cook_cancel` | 재료 되돌리기(조리 포기) | `recipe`, `minutes` |
| `video_open` | YouTube 검색 열기 | `source`: cook/empty_deck |
| `undo` | 되돌리기 실행 | `kind`: fired/finished/ate/tossed/removed/memo_removed |

### 장보기·레시피·데이터·계정

| 이벤트 | 언제 | 속성 |
|---|---|---|
| `tobuy_add` | 장보기 메모 담기 | `source`: memo(검색 시트)/missing(티켓의 없는 재료), `count` |
| `tobuy_remove` | 메모 빼기 | `via`: skip(✕)/swipe |
| `recipe_custom` | 내 레시피 | `action`: create/edit/delete |
| `sample_load` / `data_reset` | 샘플 냉장고 / 전체 초기화 | – |
| `auth_signin` | 세션 수립 | `provider`(email/apple/google/anonymous…), `anonymous: bool` |
| `auth_upgrade` | 익명 → 정식 계정 승계 확정 | `provider` |
| `auth_signout` | 로그아웃 | – |

모든 행에 붙는 컨텍스트 컬럼: `app_version` `build` `os_version` `device_model`(`iPhone17,3` 같은 기종 코드)
`locale` `language`(실제 표시 언어 코드) `channel`(release/debug) `occurred_at`(기기 시각) `received_at`(서버 시각).

**계측하지 않는 것(의도)**: 공유 시트 탭(`ShareLink`는 액션 콜백이 없다), 프로필 취향 칩 하나하나(온보딩 종료
시점의 요약만), 조리 단계 체크 하나하나(완료 시점의 `steps_done`만), 검색어·재료명·구매처(개인정보).

## 4. 지표 정의(서버 뷰)

전부 `analytics` 스키마의 뷰다. 대시보드 › SQL Editor에서 `select * from analytics.<뷰>;`로 본다.
일 경계는 **서울 시간**(`analytics.local_day`)이고 주는 월요일 시작(`date_trunc('week')`).
`channel = 'debug'`는 어느 뷰에도 잡히지 않는다.

| 뷰 | 무엇 | 읽는 법 |
|---|---|---|
| `dau` / `wau` / `mau` | 일·주·월 활성 사용자(+신규) | 활동 = 어떤 이벤트든 하나 |
| `stickiness_monthly` | 평균 DAU ÷ MAU | 냉장고 앱은 주 2~3회 리듬이라 20% 안팎이면 건강 |
| `retention_daily` | 첫 활동일 코호트의 D1/D3/D7/D14/D30(정확히 그날) + D7+/D30+(그날 이후 언제든) | `cohort_age_days`보다 큰 N은 아직 관측 중 — 0으로 읽지 말 것 |
| `retention_weekly` | 첫 주 코호트의 W1~W4·W8·W4+ | **주 단위가 이 앱의 기본 리텐션 표**다 |
| `sessions` | 세션별: 길이(초)·알림 기여·콜드·화면 수·덱/발주/완료 도달 | 원자료 |
| `sessions_weekly` | 세션 수, 1인당 세션, 중앙 길이, 알림 기여 %, 덱 열림 %, 발주 % | 알림이 세션을 만드는가 |
| `core_loop_weekly` | 넣기·덱·발주·완료·판정의 건수/사용자 수, `waste_rate_pct`, `lexicon_hit_pct`, `finish_pct`, `fires_per_active_user` | **북극성: `fires_per_active_user`와 `waste_rate_pct`** |
| `funnel_weekly` | 사용자 기준 활동 → 덱 → 발주 → 완료 전환율 | 어느 단이 새는가 |
| `screens_weekly` | 화면별 노출·사용자 | 안 가는 화면은 빼거나 입구를 옮긴다 |
| `receipt_weekly` | 스캔 수, 후보 대비 사전 매칭 %, 실제 등록 % | OCR·파서 개선의 근거 |
| `waste_by_glyph_weekly` | 글리프별 먹음/버림, 버릴 때 평균 남은 일수 | 어떤 재료가 왜 버려지는가 |
| `events_daily` | 이벤트별 일 건수·사용자 | 새 빌드에서 이벤트가 사라졌는지 감시 |

낭비율 정의는 앱 History와 같다: `tossed ÷ (ate_direct + ate_by_cooking + tossed)`. 조리 완료로 소비된
재료(`cook_finish.used`)는 먹은 것이다.

리텐션의 "활동"을 **핵심 루프 도달**로 좁히고 싶으면 `active_days` 대신
`select distinct user_id, day from analytics.events where name in ('ticket_fire','cook_finish','ingredient_decide')`를
코호트 조인의 오른쪽에 두면 된다(그 정의의 뷰는 아직 만들지 않았다 — 표본이 쌓인 뒤 어느 정의가 더
설명력 있는지 보고 고른다).

### 자주 쓰는 질문

```sql
-- 주 코호트 리텐션(최근 8주)
select * from analytics.retention_weekly limit 8;

-- 이번 주 핵심 루프 + 낭비율
select week, active_users, users_fired, fires_per_active_user, finish_pct, waste_rate_pct, lexicon_hit_pct
from analytics.core_loop_weekly limit 4;

-- 알림이 세션을 만드는가
select week, sessions, from_notification_pct, opened_deck_pct, fired_pct, median_seconds
from analytics.sessions_weekly limit 8;

-- 온보딩을 건너뛴 사용자 vs 완주한 사용자의 W1 복귀율
with o as (
  select user_id, bool_or((props->>'skipped')::boolean) as skipped
  from analytics.events where name = 'onboarding_complete' group by 1
), r as (
  select f.user_id, bool_or((a.week - f.first_week) / 7 = 1) as w1
  from analytics.first_seen f join analytics.active_weeks a using (user_id) group by 1
)
select skipped, count(*) as users, round(100.0 * count(*) filter (where w1) / count(*), 1) as w1_pct
from o join r using (user_id) group by 1;

-- 계측 생존 확인(오늘 어떤 이벤트가 몇 건)
select * from analytics.events_daily where day = analytics.local_day(now());
```

## 5. 클라이언트 구조

- `Reffi/Data/Analytics.swift` — `AnalyticsEvent`(분류) + `Analytics`(파이프라인: 세션·큐·업로드·옵트아웃) +
  `View.analyticsScreen(_:)`(커버·시트의 onAppear 기록).
- 스토어 변이(`FridgeStore`)는 `track` 훅으로 **사실**을 올린다(판정·발주·완료·추가·핀·패스·메모·레시피·초기화).
  표면 정보(어느 화면의 판정인가, 어느 입구의 추가인가)는 호출부가 `surface:`/`source:`로 건넨다.
  메모리 스토어(프리뷰·테스트)는 no-op이고 테스트가 캡처 클로저로 갈아 끼운다(`AnalyticsTests`).
- 화면·수명주기·계정은 뷰/`ReffiApp`(scenePhase)/`AuthStore`(authStateChanges)/`NotificationPresenter`(알림 탭)가 올린다.
- 업로드는 `AuthStore.client.from("analytics_events").upsert(…, onConflict: "install_id,seq", returning: .minimal, ignoreDuplicates: true)`.
  `returning: .minimal`이어야 한다 — 이 테이블엔 SELECT 권한이 없어 representation을 요청하면 실패한다.
- QA: `-analyticsOff`(킬스위치). DEBUG 빌드는 켜져 있어도 `channel = 'debug'`. Console.app에서 서브시스템
  `com.reffi.app` 카테고리 `analytics`로 이벤트가 찍히는 것을 본다.

## 6. 서버 적용 절차

1. **프로젝트 복원.** 무료 티어는 방치되면 `INACTIVE`로 정지된다(정지 상태에선 인증도 계측도 동작하지 않는다).
   2026-09-05 복원 후 아래 3의 마이그레이션은 **적용 완료**(`20260905214920_analytics_events_and_views`).
2. **익명 로그인 켜기.** Dashboard › Authentication › Sign In / Up › **Allow anonymous sign-ins**.
   (`docs/AUTH_SETUP.md` 1.5 — 이게 꺼져 있으면 게스트는 uid가 없어 이벤트를 올릴 수 없다.)
3. **마이그레이션 적용.** 둘 중 하나:
   ```bash
   # CLI(프로젝트 링크가 돼 있으면)
   supabase db push --project-ref bzzpmaeitfbbunsmjvmd
   ```
   또는 `supabase/migrations/0002_analytics.sql` 전문을 대시보드 SQL Editor에 붙여 실행. 재실행 안전하다
   (`analytics` 스키마는 파생 뷰만 있어 통째로 재생성된다 — 거기에 직접 만든 객체를 두지 말 것).
4. **확인.**
   ```sql
   select count(*) from public.analytics_events;                 -- 0
   select * from analytics.events_daily limit 5;                  -- 빈 결과, 오류 없음
   select policyname, cmd from pg_policies where tablename = 'analytics_events';  -- insert 1개
   ```
   Dashboard › Advisors(security)에 `analytics_events` 관련 경고가 없어야 한다.
5. **앱에서 확인.** TestFlight(Release) 빌드로 몇 번 오가면 `analytics.events_daily`에 `session_start`가 보인다.
   DEBUG 빌드로는 `select name, count(*) from public.analytics_events where channel = 'debug' group by 1`로 본다.

## 7. 보안 모델

- `public.analytics_events`: RLS 켬. 정책은 `insert to authenticated with check (user_id = auth.uid())` 하나.
  `anon`/`authenticated`에는 컬럼 지정 INSERT만 부여하고 `user_id`는 빠져 있다(서버 기본값). SELECT/UPDATE/DELETE 없음.
- `analytics.*`: PostgREST 미노출 스키마(exposed schemas 기본값은 public/graphql_public). 뷰는 `security_invoker`라
  실수로 노출돼도 RLS가 막는다. 대시보드(postgres)·service role만 읽는다.
- 익명 로그인 키(publishable)로 누구나 **자기 uid로** 행을 넣을 수는 있다(모든 클라이언트 계측의 공통 조건).
  이름 정규식·props 4KB·채널 CHECK로 형태만 제한한다. 남용이 보이면 Edge Function 프록시(레이트리밋)로 옮긴다.
- `user_id`에 FK를 걸지 않았다 — `AUTH_SETUP.md`가 권하는 익명 유저 주기 삭제가 코호트를 지우지 않게.

## 8. 프라이버시·스토어

- **수집 항목**(App Store Connect 앱 개인정보 라벨에 반영할 것): 제품 상호작용(Product Interaction)·사용자 ID(User ID) — **사용자에게 연결됨, 추적 아님**. 이메일(로그인 기능용)은 기존과 같다.
- `Reffi/PrivacyInfo.xcprivacy`가 위 내용과 UserDefaults 접근 사유(CA92.1)를 신고한다. 추적 도메인 없음.
- 개인정보처리방침에 문장 하나가 필요하다: "앱 사용 방식(화면 이동·기능 사용 횟수)을 계정 식별자와 함께
  수집해 서비스 개선에 사용하며, 설정에서 언제든 끌 수 있습니다. 재료명 등 입력 내용은 수집하지 않습니다."
- **삭제 요청**: `select analytics.delete_user('<uid>');` — 계정 삭제 Edge Function(`AuthStore` TODO)이 생기면 거기서 함께 부른다.
- **보존 기간**: 정하지 않았다(표본이 작다). 정하면 `pg_cron`으로 `delete … where received_at < now() - interval '180 days'`.
  debug 채널은 `select analytics.purge_debug();`로 수시 정리.

## 9. 후속

- 코호트의 "활동"을 핵심 루프 도달로 좁힌 리텐션 뷰(§4 끝) — 표본이 쌓인 뒤.
- 알림 리드데이(D-N) 선택이 생기면 `alerts_toggled`에 `lead_days` 추가.
- 공유 시트 탭 계측 — `ShareLink` 대신 자체 버튼 + `UIActivityViewController`로 바꿀 때 함께.
- 외부 대시보드가 필요해지면 `analytics_events`를 그대로 내보낸다(스키마가 평평해서 어디든 붙는다).
