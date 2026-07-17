-- AI 레시피 생성 — 프로바이더 설정(ai_config) + 일일 사용량 캡(ai_usage) + 원자적 캡 체크 RPC.
-- 클라이언트는 이 테이블들에 직접 접근하지 않는다 — Edge Function(recipe-generate)이 service role로만 읽고 쓴다.
-- 재실행해도 안전하도록(idempotent) IF NOT EXISTS / ON CONFLICT / CREATE OR REPLACE로 작성.

-- ============================================================
-- ai_config: 싱글턴 설정 행(id=1) — 프로바이더 순서/모델/엔드포인트/시크릿 이름 + 일일 캡.
-- ============================================================
create table if not exists public.ai_config (
  id int primary key default 1,
  providers jsonb not null default '[
    {"name":"cerebras","enabled":true,"model":"gpt-oss-120b","endpoint":"https://api.cerebras.ai/v1/chat/completions","secret":"CEREBRAS_API_KEY"},
    {"name":"groq","enabled":true,"model":"openai/gpt-oss-120b","endpoint":"https://api.groq.com/openai/v1/chat/completions","secret":"GROQ_API_KEY"},
    {"name":"cloudflare","enabled":true,"model":"@cf/openai/gpt-oss-120b","endpoint":"cf","secret":"CF_API_TOKEN"}
  ]'::jsonb,
  daily_cap int not null default 5,
  constraint ai_config_singleton check (id = 1)
);

comment on table public.ai_config is
  'AI 레시피 생성 프로바이더 설정. 싱글턴(id=1). service role(Edge Function) 전용 — 클라이언트 접근 정책 없음.';
comment on column public.ai_config.providers is
  '순서대로 시도할 프로바이더 배열. 각 원소: {name, enabled, model, endpoint, secret(Deno.env 키 이름)}.';

-- 기본 설정 행 시딩(이미 있으면 스킵).
insert into public.ai_config (id) values (1)
  on conflict (id) do nothing;

alter table public.ai_config enable row level security;
-- 의도적으로 정책을 만들지 않는다 — RLS 활성화 + 정책 0개 = anon/authenticated 전부 차단,
-- service role만(RLS를 우회하는 role) 읽고 쓸 수 있다.

-- ============================================================
-- ai_usage: 사용자별 일일 생성 횟수 — 캡 강제용.
-- ============================================================
create table if not exists public.ai_usage (
  user_id uuid not null,
  day date not null,
  count int not null default 0,
  primary key (user_id, day)
);

comment on table public.ai_usage is
  'AI 레시피 생성 일일 사용량 카운터. service role(Edge Function) 전용 — 클라이언트 접근 정책 없음.';

alter table public.ai_usage enable row level security;
-- ai_config과 동일한 이유로 정책 없음 — service role(ai_try_consume 내부에서 사용)만 접근.

-- ============================================================
-- ai_try_consume: 원자적 "체크 후 증가" — upsert 단일 트랜잭션으로 캡 초과 시 증가 없이 false.
-- ============================================================
create or replace function public.ai_try_consume(p_user uuid, p_cap int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  -- 캡이 0 이하로 설정된 경우 첫 요청부터 막는다(아래 insert 분기가 이 케이스를 못 잡으므로 선행 체크).
  if p_cap <= 0 then
    return false;
  end if;

  -- 오늘 첫 사용이면 count=1로 삽입(1 <= p_cap은 위에서 보장됨).
  -- 이미 오늘 행이 있으면 count < p_cap일 때만 +1 — 캡 초과 시 WHERE가 걸려 아무 것도 갱신되지 않는다.
  insert into public.ai_usage (user_id, day, count)
  values (p_user, current_date, 1)
  on conflict (user_id, day)
  do update set count = ai_usage.count + 1
    where ai_usage.count < p_cap
  returning count into v_count;

  -- 갱신된 행이 없으면(=캡 초과) v_count는 NULL.
  return v_count is not null;
end;
$$;

comment on function public.ai_try_consume(uuid, int) is
  '일일 캡 원자적 체크+증가. true=소비 성공(카운트 증가됨), false=캡 초과(증가 없음). service role 전용.';

revoke all on function public.ai_try_consume(uuid, int) from public;
grant execute on function public.ai_try_consume(uuid, int) to service_role;
