#!/usr/bin/env bash
# 추천 요리 이미지를 OpenAI(gpt-image-1)로 생성해 Assets.xcassets에 넣는다.
# 사용법 (키는 이 명령에만 인라인으로 — 디스크/기록에 남지 않음):
#   OPENAI_API_KEY=sk-... bash reffi-ios/tools/gen-recipe-images.sh
set -euo pipefail

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "ERROR: OPENAI_API_KEY가 없습니다. 다음처럼 키를 인라인으로 넣어 실행하세요:"
  echo "  OPENAI_API_KEY=sk-... bash reffi-ios/tools/gen-recipe-images.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS="$SCRIPT_DIR/../Reffi/Resources/Assets.xcassets"
SIZE="1024x1536"   # 세로형 — 카드 비율에 맞춤
MODEL="gpt-image-1"

# key|한국어 요리명|영문 프롬프트
RECIPES=(
  "recipe_tofu_egg|두부 계란조림|Korean home-cooked braised soft tofu with egg (dubu gyeran-jorim), glossy savory sauce, garnished with scallion"
  "recipe_chicken_veg|닭가슴살 채소볶음|Korean stir-fried chicken breast with carrot and spinach, in a pan, fresh and healthy"
  "recipe_potato_soup|감자 우유수프|Creamy potato and milk soup in a ceramic bowl, warm and comforting, light steam"
)

gen_one() {
  local key="$1" kor="$2" en="$3"
  local dir="$ASSETS/$key.imageset"
  mkdir -p "$dir"
  echo "▶ 생성: $kor ($key) ..."

  local prompt="$en. Appetizing food photography, top-down 3/4 view, warm natural light, shallow depth of field, on a rustic ceramic plate, cream paper background, no text, no watermark, vertical composition."

  # 응답(base64)을 파일로
  curl -sS https://api.openai.com/v1/images/generations \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.argv[1],'size':'$SIZE','n':1}))" "$prompt")" \
    -o "$dir/_resp.json"

  # b64 → png (에러면 메시지 출력)
  python3 - "$dir" <<'PY'
import json, base64, sys, os
d = sys.argv[1]
resp = json.load(open(os.path.join(d, "_resp.json")))
if "error" in resp:
    print("  ! OpenAI 에러:", resp["error"].get("message")); sys.exit(2)
b64 = resp["data"][0]["b64_json"]
open(os.path.join(d, "image.png"), "wb").write(base64.b64decode(b64))
json.dump({"images":[{"filename":"image.png","idiom":"universal"}],
           "info":{"author":"xcode","version":1}},
          open(os.path.join(d, "Contents.json"), "w"), indent=2)
os.remove(os.path.join(d, "_resp.json"))
print("  ✓ 저장:", os.path.join(d, "image.png"))
PY
}

for r in "${RECIPES[@]}"; do
  IFS='|' read -r key kor en <<< "$r"
  gen_one "$key" "$kor" "$en"
done

echo "완료. 이제 Claude에게 '이미지 생성됐어'라고 알려주면 빌드·확인합니다."
