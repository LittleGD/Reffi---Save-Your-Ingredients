# Reffi AI 레시피 생성 설정 가이드

> **2026-08-08 업데이트.** 인앱 AI 레시피 생성(온디바이스·클라우드 프록시 엔진 체인, 동의 토글, 일일 캡, 발주 덱의
> AI 배지)은 owner decision으로 앱 표면에서 전면 제거됐다 — 단서 카드 방향으로 정리하면서 생성형 레시피가
> 불필요해졌다(`design_system.md` §11 참고). 이 문서가 설명하는 Supabase `recipe-generate` Edge Function과
> 아래 설정 절차는 **향후 재활성화를 위해 그대로 유지**한다 — 지금 앱은 이 함수를 호출하지 않는다.

앱은 보유 재료로 만들 수 있는 레시피를 AI로 생성해 시드 레시피를 보완한다. 이 기능은 **완전히 선택적**이다 —
프로바이더 키를 하나도 설정하지 않아도 앱은 정상 동작하고(번들 시드 레시피만 씀), 키를 넣는 순간부터
`recipe-generate` Edge Function이 살아난다.

## 프로젝트 정보
- Supabase 프로젝트: `iwannalaunchmyapp` (ref: `bzzpmaeitfbbunsmjvmd`, 리전 ap-northeast-2 서울)
- 대시보드: https://supabase.com/dashboard/project/bzzpmaeitfbbunsmjvmd
- 함수 소스: `supabase/functions/recipe-generate/index.ts`
- 마이그레이션: `supabase/migrations/0001_ai_recipe.sql` (`ai_config`·`ai_usage` 테이블 + `ai_try_consume` RPC)

## 아키텍처 요약
- `ai_config`(싱글턴, id=1)의 `providers` jsonb 배열에 프로바이더를 **순서대로** 등록해둔다. 함수는 이 순서대로
  시도하다가 첫 성공에서 멈춘다(429/5xx/10초 타임아웃이면 다음 프로바이더로 넘어감).
- 하루 생성 횟수는 `ai_config.daily_cap`(기본 5)로 제한하고, `ai_usage` 테이블 + `ai_try_consume` RPC가
  유저별·날짜별 카운트를 원자적으로 체크·증가한다. **캡 소비는 프로바이더 시도보다 먼저 일어난다** — 즉
  모든 프로바이더가 실패해 503을 돌려주는 경우에도 그 시도는 오늘의 캡에서 차감된다(재시도 폭주 방지 목적의
  보수적 설계).
- 두 테이블 모두 RLS는 켜져 있고 **정책이 하나도 없다** — 클라이언트(anon/authenticated)는 절대 직접 못 읽고,
  Edge Function이 `SUPABASE_SERVICE_ROLE_KEY`로만 접근한다.

## 1. 프로바이더 3사 계정 만들기 → 키 발급
세 프로바이더 모두 무료 티어가 있다. 하나만 설정해도 동작하지만(폴백 체인이 하나로 줄 뿐), 가용성을 위해
셋 다 설정하는 걸 권장한다.

1. **Cerebras Cloud** — https://cloud.cerebras.ai 가입 → 좌측 메뉴 **API Keys** → 키 발급.
   - `ai_config`의 `secret` 이름: `CEREBRAS_API_KEY`
   - 컨텍스트 창이 8K로 좁으니, 이 프로바이더용 프롬프트는 함수 안에서 이미 간결하게 짜여 있다(재료 목록 +
     선호도만, 레시피 예시·긴 설명 없음) — 건드릴 때 이 제약을 유지할 것.
2. **Groq Console** — https://console.groq.com 가입 → **API Keys** 메뉴 → 키 발급.
   - `secret` 이름: `GROQ_API_KEY`
3. **Cloudflare Workers AI** — https://dash.cloudflare.com 가입/로그인.
   - 계정 ID: 대시보드 우측 사이드바(또는 아무 도메인 개요 페이지 우측)에 표시되는 **Account ID**.
   - API 토큰: **My Profile → API Tokens → Create Token** → "Workers AI" 관련 권한(또는 커스텀으로
     `Account – Workers AI – Edit`)으로 발급.
   - `secret` 이름: `CF_API_TOKEN`(토큰) + `CF_ACCOUNT_ID`(계정 ID, 별도 시크릿).
   - 참고: https://developers.cloudflare.com/workers-ai/

## 2. 시크릿 설정 (`supabase secrets set`)
발급받은 키를 프로젝트에 등록한다(로컬 저장소에는 절대 커밋하지 않는다):

```bash
supabase secrets set \
  CEREBRAS_API_KEY=csk-xxxxxxxxxxxx \
  GROQ_API_KEY=gsk_xxxxxxxxxxxx \
  CF_API_TOKEN=xxxxxxxxxxxx \
  CF_ACCOUNT_ID=xxxxxxxxxxxx \
  --project-ref bzzpmaeitfbbunsmjvmd
```

확인: `supabase secrets list --project-ref bzzpmaeitfbbunsmjvmd` (값은 안 보이고 키 이름만 나온다).

프로바이더 하나만 쓰고 싶으면 그 프로바이더의 시크릿만 설정하면 된다 — 나머지는 함수가 "키 없음"으로
자동 스킵한다(로그에 `skip reason=missing_secret`로만 남고 요청은 실패하지 않는다, 다음 프로바이더로 이어짐).

## 3. `ai_config`로 모델/순서 바꾸기 (SQL 예시)
프로바이더 순서를 바꾸거나, 모델을 교체하거나, 특정 프로바이더를 끄고 싶으면 `providers` 컬럼을 통째로
갱신한다(대시보드 SQL Editor 또는 `supabase db query`):

```sql
-- Groq를 맨 앞으로, Cerebras는 잠시 끄기
update public.ai_config
set providers = '[
  {"name":"groq","enabled":true,"model":"openai/gpt-oss-120b","endpoint":"https://api.groq.com/openai/v1/chat/completions","secret":"GROQ_API_KEY"},
  {"name":"cerebras","enabled":false,"model":"gpt-oss-120b","endpoint":"https://api.cerebras.ai/v1/chat/completions","secret":"CEREBRAS_API_KEY"},
  {"name":"cloudflare","enabled":true,"model":"@cf/openai/gpt-oss-120b","endpoint":"cf","secret":"CF_API_TOKEN"}
]'::jsonb
where id = 1;
```

모델만 바꾸는 부분 갱신(예: Groq 모델 교체)도 가능하다:

```sql
update public.ai_config
set providers = jsonb_set(
  providers,
  '{1,model}',              -- 배열 인덱스는 0부터 — 이 예시는 두 번째 원소
  '"llama-3.3-70b-versatile"'
)
where id = 1;
```

주의: `endpoint`는 `cerebras`/`groq`처럼 OpenAI 호환 REST URL이어야 한다. `cloudflare`의 `endpoint`는
`"cf"` 그대로 둘 것 — 함수 코드가 이 값을 보고 `CF_ACCOUNT_ID`로 실제 URL을 조립하므로, 여기 다른 URL을
넣어도 무시된다.

## 4. 일일 캡 변경
```sql
update public.ai_config set daily_cap = 10 where id = 1;
```

캡을 낮추면(예: `daily_cap = 0`) 모든 요청이 즉시 `429 {"error":"daily_cap","cap":0}`을 받는다 — 기능을
잠시 완전히 끄고 싶을 때 프로바이더 시크릿을 지우는 대신 이렇게 캡만 0으로 내려도 된다(더 되돌리기 쉬움).

## 5. 함수 로컬 테스트

### 5.1. 함수를 로컬로 띄우기
로컬 실행은 원격 프로젝트의 DB/Auth를 그대로 바라보게 `.env` 파일로 시크릿을 넘긴다(`supabase secrets`는
**배포된** 함수에만 적용되고, `functions serve`는 별도 env 파일을 읽는다):

```bash
cat > supabase/.env.local <<'EOF'
CEREBRAS_API_KEY=csk-xxxxxxxxxxxx
GROQ_API_KEY=gsk_xxxxxxxxxxxx
CF_API_TOKEN=xxxxxxxxxxxx
CF_ACCOUNT_ID=xxxxxxxxxxxx
EOF

supabase functions serve recipe-generate \
  --env-file supabase/.env.local \
  --project-ref bzzpmaeitfbbunsmjvmd
```

(`supabase/.env.local`은 `.gitignore`에 걸리는지 꼭 확인하고 커밋하지 말 것.)

### 5.2. 진짜 access token 받기
`verify_jwt`가 켜져 있어서 손으로 만든 가짜 JWT는 서명 검증에서 바로 401로 막힌다 — 실제 로그인으로 발급된
토큰이 있어야 한다. 이미 확인된(이메일 인증 완료) 테스트 계정이 있다면:

```bash
curl -s -X POST "https://bzzpmaeitfbbunsmjvmd.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: sb_publishable_G0kaRfSEKwS-qW4hAOscKA_x5DXA_bV" \
  -H "Content-Type: application/json" \
  -d '{"email":"you+test@example.com","password":"testpass123"}' \
  | tee /tmp/reffi_auth.json | jq -r .access_token
```

테스트 계정이 아직 없으면 앱에서 한 번 가입하거나, `docs/AUTH_SETUP.md` 1항처럼 대시보드에서
**Confirm email을 잠시 꺼두고** `/auth/v1/signup`으로 계정을 만들면 즉시 `access_token`이 온다.

### 5.3. 로컬 함수 호출
```bash
ACCESS_TOKEN=$(jq -r .access_token /tmp/reffi_auth.json)

curl -s -X POST "http://localhost:54321/functions/v1/recipe-generate" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "locale": "ko",
    "count": 1,
    "ingredients": [{"name": "김치"}, {"name": "돼지고기"}],
    "preferences": {"cuisines": ["korean"], "allergies": [], "disliked": [], "favorites": []}
  }' | jq .
```

정상 응답은 `{"recipes":[...]}`(각 레시피에 `"origin":"ai"` 포함). 캡 초과는
`429 {"error":"daily_cap","cap":N}`, 입력 검증 실패는 `400 {"error":"invalid_body","detail":"..."}`,
프로바이더 전멸(키 없음/전부 실패)은 `503 {"error":"unavailable"}`.

## 6. 키가 하나도 없을 때의 동작
프로바이더 시크릿을 전혀 설정하지 않았거나(로컬 개발 초기 상태) 3사가 전부 실패하면, 함수는 **항상**
`503 {"error":"unavailable"}`을 반환한다 — 절대 가짜/하드코딩 레시피를 만들어내지 않는다. 이 경우 앱은
번들 시드 레시피(`Reffi/Resources/recipes-seed.json`)로 조용히 폴백해야 한다(프로젝트 규칙: 레시피는
하드코딩 금지, 동작 안 하는 위약 UI 금지 — 503을 못 받아내는 상태로 방치하지 말 것).
