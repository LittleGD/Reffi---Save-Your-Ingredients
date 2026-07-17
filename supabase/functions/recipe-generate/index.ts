// recipe-generate — AI 레시피 생성 프록시.
//
// 클라이언트(네이티브 앱)가 보유 재료·선호를 보내면, ai_config에 설정된 프로바이더를
// 순서대로 시도해 recipes-seed.json과 동일한 스키마의 레시피를 생성해 돌려준다.
// verify_jwt는 기본값(true)을 전제한다 — 이 함수 코드는 게이트웨이가 이미 서명을
// 검증한 JWT가 온다고 가정하고, 그 안의 sub(유저 id, 익명 유저 포함)만 다시 뽑아 쓴다.
//
// 키·프롬프트·재료 내용은 절대 로그로 남기지 않는다(개인정보) — 로그는 provider 이름과
// 실패 사유 코드만.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============================================================
// 타입
// ============================================================

interface IngredientIn {
  id?: string;
  name: string;
}

interface PreferencesIn {
  cuisines: string[];
  allergies: string[];
  disliked: string[];
  favorites: string[];
}

interface ValidatedRequest {
  locale: "en" | "ko";
  count: 1 | 2 | 3;
  ingredients: IngredientIn[];
  preferences: PreferencesIn;
}

interface ProviderConfig {
  name: string;
  enabled: boolean;
  model: string;
  endpoint: string;
  secret: string;
}

interface RecipeItemOut {
  ref: null;
  en: string;
  ko?: string;
}

interface RecipeOut {
  id: string;
  name: { en: string; ko?: string };
  cuisine: string | null;
  minutes: number;
  ingredients: RecipeItemOut[];
  steps: { en: string[]; ko?: string[] };
  origin: "ai";
}

// ============================================================
// 상수
// ============================================================

const MAX_INGREDIENTS = 15;
const MAX_RECIPE_INGREDIENTS = 12;
const MIN_MINUTES = 5;
const MAX_MINUTES = 180;
const PROVIDER_TIMEOUT_MS = 10_000;

// ============================================================
// 엔트리포인트
// ============================================================

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    // CORS는 필요 없다(네이티브 앱 전용) — 프리플라이트만 통과시킨다.
    return new Response(null, { status: 200 });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
    console.log("[recipe-generate] fatal: missing supabase env vars");
    return jsonResponse({ error: "unavailable" }, 503);
  }

  // 요청자 JWT로 스코프한 클라이언트 — 서명은 게이트웨이가 이미 검증했으므로 여기서는
  // sub(유저 id)를 신뢰성 있게 뽑아내는 용도로만 auth.getUser()를 쓴다(익명 유저도 포함).
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  const userId = userData.user.id;

  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_body" }, 400);
  }

  const validated = validateBody(rawBody);
  if (!validated.ok) {
    return jsonResponse({ error: "invalid_body", detail: validated.reason }, 400);
  }
  const { locale, count, ingredients, preferences } = validated.value;

  // 이후 전부 service role 클라이언트로만 접근한다(ai_config/ai_usage는 클라이언트 접근 정책이 없음).
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: configRow, error: configErr } = await admin
    .from("ai_config")
    .select("providers, daily_cap")
    .eq("id", 1)
    .single();

  if (configErr || !configRow) {
    console.log("[recipe-generate] fatal: ai_config load failed");
    return jsonResponse({ error: "unavailable" }, 503);
  }

  const dailyCap = typeof configRow.daily_cap === "number" ? configRow.daily_cap : 5;

  const { data: allowed, error: capErr } = await admin.rpc("ai_try_consume", {
    p_user: userId,
    p_cap: dailyCap,
  });

  if (capErr) {
    console.log("[recipe-generate] fatal: ai_try_consume rpc failed");
    return jsonResponse({ error: "unavailable" }, 503);
  }
  if (!allowed) {
    return jsonResponse({ error: "daily_cap", cap: dailyCap }, 429);
  }

  const providers: ProviderConfig[] = Array.isArray(configRow.providers)
    ? (configRow.providers as ProviderConfig[])
    : [];
  const forbidden = [...preferences.allergies, ...preferences.disliked];
  const { system, user } = buildPrompt({ locale, count, ingredients, preferences });

  const recipes = await tryProviders(providers, system, user, forbidden, count);
  if (!recipes) {
    return jsonResponse({ error: "unavailable" }, 503);
  }

  return jsonResponse({ recipes });
});

// ============================================================
// 요청 검증
// ============================================================

function isNonEmptyString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

function asStringArray(v: unknown): string[] | null {
  if (v === undefined) return [];
  if (!Array.isArray(v)) return null;
  if (!v.every((x) => typeof x === "string")) return null;
  return v.map((x) => (x as string).trim()).filter((x) => x.length > 0);
}

function validateBody(
  body: unknown,
): { ok: true; value: ValidatedRequest } | { ok: false; reason: string } {
  if (typeof body !== "object" || body === null) {
    return { ok: false, reason: "body_not_object" };
  }
  const b = body as Record<string, unknown>;

  if (b.locale !== "en" && b.locale !== "ko") {
    return { ok: false, reason: "locale" };
  }
  const locale = b.locale;

  if (b.count !== 1 && b.count !== 2 && b.count !== 3) {
    return { ok: false, reason: "count" };
  }
  const count = b.count;

  if (!Array.isArray(b.ingredients) || b.ingredients.length < 1) {
    return { ok: false, reason: "ingredients" };
  }
  const ingredients: IngredientIn[] = [];
  for (const raw of b.ingredients) {
    if (ingredients.length >= MAX_INGREDIENTS) break; // 최대 15개로 클램프 — 나머지는 무시.
    if (typeof raw !== "object" || raw === null) {
      return { ok: false, reason: "ingredients" };
    }
    const it = raw as Record<string, unknown>;
    if (!isNonEmptyString(it.name)) {
      return { ok: false, reason: "ingredients" };
    }
    const entry: IngredientIn = { name: it.name.trim() };
    if (isNonEmptyString(it.id)) entry.id = it.id.trim();
    ingredients.push(entry);
  }

  const prefsRaw = b.preferences === undefined ? {} : b.preferences;
  if (typeof prefsRaw !== "object" || prefsRaw === null) {
    return { ok: false, reason: "preferences" };
  }
  const p = prefsRaw as Record<string, unknown>;
  const cuisines = asStringArray(p.cuisines);
  const allergies = asStringArray(p.allergies);
  const disliked = asStringArray(p.disliked);
  const favorites = asStringArray(p.favorites);
  if (cuisines === null || allergies === null || disliked === null || favorites === null) {
    return { ok: false, reason: "preferences" };
  }

  return {
    ok: true,
    value: { locale, count, ingredients, preferences: { cuisines, allergies, disliked, favorites } },
  };
}

// ============================================================
// 프롬프트 구성
// ============================================================

function buildPrompt(input: ValidatedRequest): { system: string; user: string } {
  const system = `You are Reffi's recipe generator. Reffi helps people cook with ingredients already in their fridge before they spoil, using real, commonly cooked dishes.
Respond with ONLY a single JSON object — no prose, no markdown code fences — matching exactly this shape:
{"recipes":[{"id":"kebab-case-slug","name":{"en":"...","ko":"..."},"cuisine":"a cuisine name or null","minutes":integer,"ingredients":[{"ref":null,"en":"...","ko":"..."}],"steps":{"en":["step 1","step 2"],"ko":["단계 1","단계 2"]}}]}
Rules:
- Always set every ingredient's "ref" to null.
- steps.en and steps.ko must have the same number of steps, in the same order.
- Fill every text field in BOTH natural English and natural Korean, regardless of the user's app language.
- Never use any ingredient on the forbidden list below, in any form or disguise.
- Only real, commonly cooked dishes — no invented or fantasy food.
- Prefer dishes built around the ingredients on hand; you may assume basic pantry staples (salt, oil, water, sugar) are available even if not listed.
- Generate exactly ${input.count} recipe(s).`;

  const ingredientList = input.ingredients.map((i) => i.name).join(", ") || "(none specified)";
  const cuisines = input.preferences.cuisines.join(", ") || "any";
  const forbidden = [...input.preferences.allergies, ...input.preferences.disliked].join(", ") || "none";
  const favorites = input.preferences.favorites.join(", ") || "none";

  const user = `On hand: ${ingredientList}
Preferred cuisines: ${cuisines}
Forbidden ingredients (never include, in any recipe): ${forbidden}
Liked dishes for inspiration (optional, do not copy verbatim): ${favorites}
User's app language: ${input.locale}
Generate exactly ${input.count} recipe(s) as the JSON object described above.`;

  return { system, user };
}

// ============================================================
// 프로바이더 호출 — enabled 순서대로 시도, 실패 시 다음으로.
// ============================================================

async function tryProviders(
  providers: ProviderConfig[],
  systemPrompt: string,
  userPrompt: string,
  forbidden: string[],
  count: number,
): Promise<RecipeOut[] | null> {
  for (const provider of providers) {
    if (!provider?.enabled) continue;

    const apiKey = Deno.env.get(provider.secret);
    const accountId = provider.name === "cloudflare" ? Deno.env.get("CF_ACCOUNT_ID") : undefined;
    if (!apiKey || (provider.name === "cloudflare" && !accountId)) {
      console.log(`[recipe-generate] provider=${provider.name} skip reason=missing_secret`);
      continue;
    }

    const url = provider.name === "cloudflare"
      ? `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/v1/chat/completions`
      : provider.endpoint;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: provider.model,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
          response_format: { type: "json_object" },
          temperature: 0.7,
          max_tokens: 1800,
        }),
        signal: controller.signal,
      });

      if (!res.ok) {
        console.log(`[recipe-generate] provider=${provider.name} fail http_status=${res.status}`);
        continue;
      }

      const data = await res.json();
      const content: unknown = data?.choices?.[0]?.message?.content;
      if (!isNonEmptyString(content)) {
        console.log(`[recipe-generate] provider=${provider.name} fail reason=empty_content`);
        continue;
      }

      const parsed = extractJson(content);
      if (!parsed || !Array.isArray((parsed as Record<string, unknown>).recipes)) {
        console.log(`[recipe-generate] provider=${provider.name} fail reason=bad_json`);
        continue;
      }

      const rawRecipes = (parsed as Record<string, unknown>).recipes as unknown[];
      const sanitized = rawRecipes
        .map((r) => sanitizeRecipe(r, forbidden))
        .filter((r): r is RecipeOut => r !== null)
        .slice(0, count);

      if (sanitized.length === 0) {
        console.log(`[recipe-generate] provider=${provider.name} fail reason=validation_empty`);
        continue;
      }

      console.log(`[recipe-generate] provider=${provider.name} success count=${sanitized.length}`);
      return sanitized;
    } catch (e) {
      const reason = e instanceof DOMException && e.name === "AbortError" ? "timeout" : "fetch_error";
      console.log(`[recipe-generate] provider=${provider.name} fail reason=${reason}`);
      continue;
    } finally {
      clearTimeout(timer);
    }
  }

  return null;
}

// 코드펜스(```json ... ```)로 감싸져 오는 경우를 방어해 JSON을 뽑아낸다.
function extractJson(raw: string): unknown {
  let text = raw.trim();
  const fenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenceMatch) text = fenceMatch[1].trim();

  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return null;
  text = text.slice(start, end + 1);

  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

// ============================================================
// 응답 레시피 검증/정규화 — recipes-seed.json과 동일한 스키마로 강제.
// ============================================================

function slugify(s: string): string {
  const slug = s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "") // 악센트 결합 기호 제거(예: é -> e)
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug.length > 0 ? slug : `recipe-${crypto.randomUUID().slice(0, 8)}`;
}

function clampInt(v: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, Math.round(v)));
}

function sanitizeRecipe(raw: unknown, forbidden: string[]): RecipeOut | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;

  const nameObj = (typeof r.name === "object" && r.name !== null) ? r.name as Record<string, unknown> : undefined;
  const nameEn = isNonEmptyString(nameObj?.en) ? (nameObj!.en as string).trim() : null;
  if (!nameEn) return null;
  const nameKo = isNonEmptyString(nameObj?.ko) ? (nameObj!.ko as string).trim() : undefined;

  const id = isNonEmptyString(r.id) ? slugify(r.id) : slugify(nameEn);

  const cuisine = isNonEmptyString(r.cuisine) ? r.cuisine.trim() : null;

  const minutesRaw = typeof r.minutes === "number" ? r.minutes : Number(r.minutes);
  if (!Number.isFinite(minutesRaw)) return null;
  const minutes = clampInt(minutesRaw, MIN_MINUTES, MAX_MINUTES);

  const ingredientsRaw = Array.isArray(r.ingredients) ? r.ingredients : [];
  const ingredients: RecipeItemOut[] = [];
  for (const item of ingredientsRaw) {
    if (ingredients.length >= MAX_RECIPE_INGREDIENTS) break;
    if (typeof item !== "object" || item === null) continue;
    const it = item as Record<string, unknown>;
    if (!isNonEmptyString(it.en)) continue;
    const en = it.en.trim();
    const ko = isNonEmptyString(it.ko) ? it.ko.trim() : undefined;
    // ref는 항상 null로 강제 — 클라이언트가 자체 사전(IngredientLexicon)으로 역조회한다.
    ingredients.push(ko ? { ref: null, en, ko } : { ref: null, en });
  }
  if (ingredients.length < 1) return null;

  const stepsObj = (typeof r.steps === "object" && r.steps !== null) ? r.steps as Record<string, unknown> : undefined;
  const stepsEnRaw = Array.isArray(stepsObj?.en) ? stepsObj!.en as unknown[] : [];
  const stepsEn = stepsEnRaw.filter(isNonEmptyString).map((s) => s.trim());
  if (stepsEn.length < 1) return null;

  const stepsKoRaw = Array.isArray(stepsObj?.ko) ? stepsObj!.ko as unknown[] : [];
  const stepsKoCandidate = stepsKoRaw.filter(isNonEmptyString).map((s) => s.trim());
  const stepsKo = stepsKoCandidate.length === stepsEn.length ? stepsKoCandidate : undefined;

  // 알레르기/기피 재료가 이름·재료 텍스트 어디에든 등장하면 레시피 전체를 버린다.
  const haystack = [
    nameEn,
    nameKo ?? "",
    ...ingredients.flatMap((i) => [i.en, i.ko ?? ""]),
  ].join(" ").toLowerCase();
  if (forbidden.some((f) => f.trim().length > 0 && haystack.includes(f.toLowerCase()))) {
    return null;
  }

  return {
    id,
    name: nameKo ? { en: nameEn, ko: nameKo } : { en: nameEn },
    cuisine,
    minutes,
    ingredients,
    steps: stepsKo ? { en: stepsEn, ko: stepsKo } : { en: stepsEn },
    origin: "ai",
  };
}

// ============================================================
// 응답 헬퍼
// ============================================================

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
