-- 행동 계측(64차) — 클라이언트가 올리는 이벤트 원장 한 테이블 + 지표 뷰(analytics 스키마).
-- 정본 문서: docs/ANALYTICS.md (이벤트 사전·지표 정의·적용 절차). 재실행 안전(idempotent).
--
-- 보안 모델(요약)
--   · public.analytics_events: RLS 켬, 정책은 INSERT 하나(자기 uid). anon/authenticated는 SELECT 권한 없음 —
--     클라이언트는 쓰기만 하고 읽지 못한다. user_id는 서버 기본값 auth.uid()로 채우고 클라이언트는 그 컬럼에
--     INSERT 권한이 없어 위조가 불가능하다.
--   · analytics.*: PostgREST에 노출되지 않는 스키마(exposed schemas는 public/graphql_public뿐). 대시보드
--     SQL Editor·service role만 읽는다. 뷰는 security_invoker라 만에 하나 노출돼도 RLS가 그대로 적용된다.
--   · 익명 유저 정리(auth.users 삭제)가 코호트를 지우지 않도록 user_id에 FK를 걸지 않는다.
--     사용자 삭제 요청은 analytics.delete_user(uuid)로 처리한다.

-- ============================================================
-- 1. 원장 — public.analytics_events
-- ============================================================
create table if not exists public.analytics_events (
  id           bigint      generated always as identity primary key,
  user_id      uuid        not null default auth.uid(),
  install_id   uuid        not null,
  session_id   uuid        not null,
  seq          bigint      not null,
  name         text        not null,
  props        jsonb       not null default '{}'::jsonb,
  occurred_at  timestamptz not null,
  received_at  timestamptz not null default now(),
  app_version  text,
  build        text,
  os_version   text,
  device_model text,
  locale       text,
  language     text,
  channel      text        not null default 'release',
  constraint analytics_events_install_seq unique (install_id, seq),
  constraint analytics_events_name_shape  check (name ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint analytics_events_props_size  check (pg_column_size(props) <= 4096),
  constraint analytics_events_channel     check (channel in ('release', 'debug'))
);

comment on table  public.analytics_events is
  '행동 이벤트 원장. 클라이언트(Reffi/Data/Analytics.swift)가 INSERT만 한다. 이벤트 사전은 docs/ANALYTICS.md.';
comment on column public.analytics_events.user_id is
  'Supabase Auth uid(익명 세션 포함). 서버 기본값 auth.uid() — 클라이언트는 이 컬럼에 쓸 권한이 없다. FK 없음(익명 유저 정리로 코호트가 지워지지 않게).';
comment on column public.analytics_events.install_id is
  '앱이 만든 설치 식별자. "Erase this device"·재설치로 바뀐다. (install_id, seq)가 재전송 중복 제거 키.';
comment on column public.analytics_events.seq is '설치별 단조 증가 시퀀스.';
comment on column public.analytics_events.session_id is '30분 무활동 규칙으로 클라이언트가 자른 세션.';
comment on column public.analytics_events.occurred_at is '기기 시각. received_at(서버 시각)과 크게 어긋나면 기기 시계 문제.';
comment on column public.analytics_events.channel is
  'release | debug. DEBUG 빌드(시뮬레이터·개발)는 debug로 올라오고 analytics.* 뷰는 release만 집계한다.';

create index if not exists analytics_events_user_time on public.analytics_events (user_id, occurred_at);
create index if not exists analytics_events_name_time on public.analytics_events (name, occurred_at);
create index if not exists analytics_events_time      on public.analytics_events (occurred_at);

alter table public.analytics_events enable row level security;

drop policy if exists analytics_events_insert_own on public.analytics_events;
create policy analytics_events_insert_own on public.analytics_events
  for insert to authenticated
  with check (user_id = auth.uid());
-- SELECT/UPDATE/DELETE 정책은 의도적으로 없다 — 클라이언트는 자기 이벤트도 읽을 수 없다.

revoke all on table public.analytics_events from anon, authenticated;
grant insert (install_id, session_id, seq, name, props, occurred_at,
              app_version, build, os_version, device_model, locale, language, channel)
  on public.analytics_events to authenticated;

-- ============================================================
-- 2. 지표 — analytics 스키마(파생물만. 마이그레이션이 통째로 재생성한다 — 여기에 직접 만든 객체를 두지 말 것)
-- ============================================================
drop schema if exists analytics cascade;
create schema analytics;
revoke all on schema analytics from public, anon, authenticated;
comment on schema analytics is
  '행동 지표 뷰. PostgREST 미노출 — 대시보드 SQL Editor/service role 전용. 정의는 docs/ANALYTICS.md §4.';

-- 일 경계는 서울 기준(이 앱의 주 사용권). 바꾸려면 이 함수 하나만 고친다.
create function analytics.local_day(ts timestamptz) returns date
language sql stable parallel safe
set search_path = ''
as $$ select (ts at time zone 'Asia/Seoul')::date $$;

-- 2.1 기본 이벤트 뷰 — release 채널만, 일/주 파생 컬럼 포함. 아래 모든 뷰의 유일한 원천.
create view analytics.events with (security_invoker = true) as
select e.id, e.user_id, e.install_id, e.session_id, e.seq, e.name, e.props, e.occurred_at,
       analytics.local_day(e.occurred_at)                            as day,
       (date_trunc('week', analytics.local_day(e.occurred_at)))::date as week,
       e.app_version, e.build, e.os_version, e.device_model, e.locale, e.language
from public.analytics_events e
where e.channel = 'release';

-- 2.2 활동 단위 — 어떤 이벤트든 하나 있으면 그날/그주 활동으로 친다.
create view analytics.active_days with (security_invoker = true) as
select distinct user_id, day from analytics.events;

create view analytics.active_weeks with (security_invoker = true) as
select distinct user_id, week from analytics.events;

create view analytics.first_seen with (security_invoker = true) as
select user_id,
       min(day)                              as first_day,
       (date_trunc('week', min(day)))::date  as first_week
from analytics.events
group by user_id;

-- 2.3 활성 사용자 — DAU / WAU / MAU / 끈끈함(stickiness = 평균 DAU ÷ MAU)
create view analytics.dau with (security_invoker = true) as
select a.day,
       count(*)                                        as dau,
       count(*) filter (where a.day = f.first_day)     as new_users
from analytics.active_days a
join analytics.first_seen f using (user_id)
group by a.day
order by a.day desc;

create view analytics.wau with (security_invoker = true) as
select a.week,
       count(*)                                        as wau,
       count(*) filter (where a.week = f.first_week)   as new_users
from analytics.active_weeks a
join analytics.first_seen f using (user_id)
group by a.week
order by a.week desc;

create view analytics.mau with (security_invoker = true) as
select (date_trunc('month', day))::date as month,
       count(distinct user_id)          as mau
from analytics.active_days
group by 1
order by 1 desc;

create view analytics.stickiness_monthly with (security_invoker = true) as
with d as (
  select (date_trunc('month', day))::date as month, dau from analytics.dau
)
select m.month, m.mau,
       round(avg(d.dau), 1)                                   as avg_dau,
       round(100.0 * avg(d.dau) / nullif(m.mau, 0), 1)        as stickiness_pct
from analytics.mau m
join d using (month)
group by m.month, m.mau
order by m.month desc;

-- 2.4 리텐션 — 일 코호트(D1/D3/D7/D14/D30: 정확히 그날 복귀) + 무제한(D7+/D30+: 그날 이후 언제든 복귀)
-- cohort_age_days보다 큰 N의 값은 아직 관측이 끝나지 않은 것이다(0으로 읽지 말 것).
create view analytics.retention_daily with (security_invoker = true) as
with x as (
  select f.user_id, f.first_day, (a.day - f.first_day) as n
  from analytics.first_seen f
  join analytics.active_days a using (user_id)
), c as (
  select first_day                                        as cohort_day,
         count(distinct user_id)                          as cohort_size,
         count(distinct user_id) filter (where n = 1)     as d1,
         count(distinct user_id) filter (where n = 3)     as d3,
         count(distinct user_id) filter (where n = 7)     as d7,
         count(distinct user_id) filter (where n = 14)    as d14,
         count(distinct user_id) filter (where n = 30)    as d30,
         count(distinct user_id) filter (where n >= 7)    as d7_plus,
         count(distinct user_id) filter (where n >= 30)   as d30_plus
  from x
  group by first_day
)
select cohort_day,
       analytics.local_day(now()) - cohort_day as cohort_age_days,
       cohort_size, d1, d3, d7, d14, d30, d7_plus, d30_plus,
       round(100.0 * d1  / cohort_size, 1)       as d1_pct,
       round(100.0 * d3  / cohort_size, 1)       as d3_pct,
       round(100.0 * d7  / cohort_size, 1)       as d7_pct,
       round(100.0 * d14 / cohort_size, 1)       as d14_pct,
       round(100.0 * d30 / cohort_size, 1)       as d30_pct,
       round(100.0 * d7_plus  / cohort_size, 1)  as d7_plus_pct,
       round(100.0 * d30_plus / cohort_size, 1)  as d30_plus_pct
from c
order by cohort_day desc;

-- 주 코호트(W1~W8: 첫 주 이후 N번째 주에 활동) — 냉장고 앱은 주 단위 리듬이라 이 표가 일 코호트보다 읽기 쉽다.
create view analytics.retention_weekly with (security_invoker = true) as
with x as (
  select f.user_id, f.first_week, ((a.week - f.first_week) / 7) as n
  from analytics.first_seen f
  join analytics.active_weeks a using (user_id)
), c as (
  select first_week                                     as cohort_week,
         count(distinct user_id)                        as cohort_size,
         count(distinct user_id) filter (where n = 1)   as w1,
         count(distinct user_id) filter (where n = 2)   as w2,
         count(distinct user_id) filter (where n = 3)   as w3,
         count(distinct user_id) filter (where n = 4)   as w4,
         count(distinct user_id) filter (where n = 8)   as w8,
         count(distinct user_id) filter (where n >= 4)  as w4_plus
  from x
  group by first_week
)
select cohort_week,
       (((date_trunc('week', analytics.local_day(now())))::date - cohort_week) / 7) as cohort_age_weeks,
       cohort_size, w1, w2, w3, w4, w8, w4_plus,
       round(100.0 * w1 / cohort_size, 1)      as w1_pct,
       round(100.0 * w2 / cohort_size, 1)      as w2_pct,
       round(100.0 * w3 / cohort_size, 1)      as w3_pct,
       round(100.0 * w4 / cohort_size, 1)      as w4_pct,
       round(100.0 * w8 / cohort_size, 1)      as w8_pct,
       round(100.0 * w4_plus / cohort_size, 1) as w4_plus_pct
from c
order by cohort_week desc;

-- 2.5 세션 — 길이는 app_background.seconds의 최댓값, 알림 기여 여부, 핵심 루프 도달 여부
create view analytics.sessions with (security_invoker = true) as
select session_id, user_id,
       min(occurred_at)                                                     as started_at,
       analytics.local_day(min(occurred_at))                                as day,
       (date_trunc('week', analytics.local_day(min(occurred_at))))::date    as week,
       coalesce(max(case when name = 'app_background'
                         then (props->>'seconds')::int end), 0)             as seconds,
       bool_or(name = 'notification_open')                                  as from_notification,
       bool_or(name = 'session_start' and (props->>'cold')::boolean)        as cold,
       count(*) filter (where name = 'screen_view')                         as screens,
       bool_or(name = 'deck_open')                                          as opened_deck,
       bool_or(name = 'ticket_fire')                                        as fired,
       bool_or(name = 'cook_finish')                                        as finished,
       count(*)                                                             as events
from analytics.events
group by session_id, user_id;

create view analytics.sessions_weekly with (security_invoker = true) as
select week,
       count(*)                                                           as sessions,
       count(distinct user_id)                                            as users,
       round(count(*)::numeric / nullif(count(distinct user_id), 0), 2)   as sessions_per_user,
       round((percentile_cont(0.5) within group (order by seconds))::numeric, 0) as median_seconds,
       round(100.0 * count(*) filter (where from_notification) / count(*), 1) as from_notification_pct,
       round(100.0 * count(*) filter (where opened_deck) / count(*), 1)       as opened_deck_pct,
       round(100.0 * count(*) filter (where fired) / count(*), 1)             as fired_pct
from analytics.sessions
group by week
order by week desc;

-- 2.6 핵심 루프(주간) — 넣기 → 덱 → 발주 → 완료 → 판정. 낭비율은 앱 History와 같은 정의:
--   tossed ÷ (ate_direct + ate_by_cooking + tossed). 조리 완료로 소비된 재료(cook_finish.used)도 '먹음'이다.
create view analytics.core_loop_weekly with (security_invoker = true) as
with w as (
  select week,
         count(distinct user_id)                                                    as active_users,
         count(distinct user_id) filter (where name = 'ingredient_add')             as users_added,
         count(distinct user_id) filter (where name = 'deck_open')                  as users_opened_deck,
         count(distinct user_id) filter (where name = 'ticket_fire')                as users_fired,
         count(distinct user_id) filter (where name = 'cook_finish')                as users_finished,
         count(*) filter (where name = 'ingredient_add')                            as adds,
         coalesce(sum(case when name = 'ingredient_add'
                           then (props->>'count')::int end), 0)                     as ingredients_added,
         coalesce(sum(case when name = 'ingredient_add'
                           then (props->>'known')::int end), 0)                     as ingredients_known,
         count(*) filter (where name = 'deck_open')                                 as deck_opens,
         count(*) filter (where name = 'ticket_pass')                               as passes,
         count(*) filter (where name = 'ticket_fire')                               as fires,
         count(*) filter (where name = 'cook_finish')                               as finishes,
         count(*) filter (where name = 'cook_cancel')                               as cancels,
         count(*) filter (where name = 'ingredient_decide'
                            and props->>'outcome' = 'ate')                          as ate_direct,
         coalesce(sum(case when name = 'cook_finish'
                           then (props->>'used')::int end), 0)                      as ate_by_cooking,
         count(*) filter (where name = 'ingredient_decide'
                            and props->>'outcome' = 'tossed')                       as tossed,
         count(*) filter (where name = 'ingredient_freeze')                         as frozen,
         count(*) filter (where name = 'undo')                                      as undos
  from analytics.events
  group by week
)
select *,
       round(100.0 * tossed / nullif(ate_direct + ate_by_cooking + tossed, 0), 1)  as waste_rate_pct,
       round(100.0 * ingredients_known / nullif(ingredients_added, 0), 1)          as lexicon_hit_pct,
       round(100.0 * finishes / nullif(fires, 0), 1)                               as finish_pct,
       round(fires::numeric / nullif(active_users, 0), 2)                          as fires_per_active_user
from w
order by week desc;

-- 2.7 퍼널(주간, 사용자 기준) — 활동 → 덱 열기 → 발주 → 조리 완료
create view analytics.funnel_weekly with (security_invoker = true) as
with u as (
  select week, user_id,
         bool_or(name = 'deck_open')   as opened,
         bool_or(name = 'ticket_fire') as fired,
         bool_or(name = 'cook_finish') as finished
  from analytics.events
  group by week, user_id
)
select week,
       count(*)                                     as active_users,
       count(*) filter (where opened)               as opened_deck,
       count(*) filter (where fired)                as fired,
       count(*) filter (where finished)             as finished,
       round(100.0 * count(*) filter (where opened)   / nullif(count(*), 0), 1)                          as opened_pct,
       round(100.0 * count(*) filter (where fired)    / nullif(count(*) filter (where opened), 0), 1)    as fired_of_opened_pct,
       round(100.0 * count(*) filter (where finished) / nullif(count(*) filter (where fired), 0), 1)     as finished_of_fired_pct
from u
group by week
order by week desc;

-- 2.8 화면(주간) — 어느 표면이 얼마나 열리는가
create view analytics.screens_weekly with (security_invoker = true) as
select week, props->>'screen' as screen,
       count(*)                as views,
       count(distinct user_id) as users
from analytics.events
where name = 'screen_view'
group by week, props->>'screen'
order by week desc, views desc;

-- 2.9 영수증 스캔 품질(주간) — 후보 대비 사전 매칭·실제 등록 비율
create view analytics.receipt_weekly with (security_invoker = true) as
with w as (
  select week,
         count(*) filter (where name = 'receipt_scan')                                       as scans,
         count(distinct user_id) filter (where name = 'receipt_scan')                        as users,
         coalesce(sum(case when name = 'receipt_scan' then (props->>'candidates')::int end), 0) as candidates,
         coalesce(sum(case when name = 'receipt_scan' then (props->>'matched')::int end), 0)    as matched,
         coalesce(sum(case when name = 'ingredient_add' and props->>'source' = 'receipt'
                           then (props->>'count')::int end), 0)                              as accepted
  from analytics.events
  group by week
)
select *,
       round(100.0 * matched  / nullif(candidates, 0), 1) as matched_pct,
       round(100.0 * accepted / nullif(candidates, 0), 1) as accepted_pct
from w
order by week desc;

-- 2.10 무엇이 버려지는가(주간·글리프별) — 버릴 때 며칠 남았었나는 알림 리드타임의 근거
create view analytics.waste_by_glyph_weekly with (security_invoker = true) as
select week, props->>'glyph' as glyph,
       count(*) filter (where props->>'outcome' = 'ate')     as ate,
       count(*) filter (where props->>'outcome' = 'tossed')  as tossed,
       round(avg(case when props->>'outcome' = 'tossed'
                      then (props->>'days_left')::int end), 1) as avg_days_left_when_tossed
from analytics.events
where name = 'ingredient_decide'
group by week, props->>'glyph'
order by week desc, tossed desc;

-- 2.11 이벤트 카운트(일) — 계측이 살아 있는지, 새 빌드에서 어떤 이벤트가 사라졌는지 보는 표
create view analytics.events_daily with (security_invoker = true) as
select day, name,
       count(*)                as events,
       count(distinct user_id) as users
from analytics.events
group by day, name
order by day desc, events desc;

-- ============================================================
-- 3. 운영 함수 — 삭제 요청·디버그 정리(service role/대시보드 전용)
-- ============================================================
create function analytics.delete_user(p_user uuid) returns bigint
language plpgsql security definer
set search_path = ''
as $$
declare n bigint;
begin
  delete from public.analytics_events where user_id = p_user;
  get diagnostics n = row_count;
  return n;
end
$$;
comment on function analytics.delete_user(uuid) is
  '사용자 삭제 요청 처리 — 그 uid의 이벤트 전부 삭제, 지운 행 수 반환. 계정 삭제 Edge Function이 부를 자리.';
revoke all on function analytics.delete_user(uuid) from public, anon, authenticated;

create function analytics.purge_debug(older_than interval default interval '30 days') returns bigint
language plpgsql security definer
set search_path = ''
as $$
declare n bigint;
begin
  delete from public.analytics_events
   where channel = 'debug' and received_at < now() - older_than;
  get diagnostics n = row_count;
  return n;
end
$$;
comment on function analytics.purge_debug(interval) is 'debug 채널(개발 빌드) 이벤트 정리. 지표에는 애초에 안 잡힌다.';
revoke all on function analytics.purge_debug(interval) from public, anon, authenticated;
