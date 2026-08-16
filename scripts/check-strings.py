#!/usr/bin/env python3
"""코드의 로컬라이즈 리터럴이 전부 Localizable.xcstrings에 등록돼 있는지 검사한다.

카탈로그는 Xcode 추출 파이프라인을 타지 않고 손으로 관리된다 — 그래서 등록 누락이
조용히 쌓인다(한국어 기기에서 그 한 줄만 영어로 나온다). 릴리스 전 이 스크립트를 돌려
'카탈로그 키 ⊇ 코드 리터럴'을 확인한다. 반대 방향(고아 키)은 --orphans로 참고 출력.

매칭은 정규화 비교다: 코드의 문자열 보간 `\\(…)`과 카탈로그의 포맷 지정자(%lld·%@·%1$lld…)를
같은 자리표시자로 치환해 맞춘다 — 보간 값의 타입을 소스에서 알 수 없기 때문이다.
Text(verbatim:)·데이터 문자열·QA 전용 화면은 번역 대상이 아니라 검사에서 뺀다.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Reffi/Resources/Localizable.xcstrings"
SOURCE = ROOT / "Reffi"
# DEBUG 전용 QA 루트 화면 — 출시 UI가 아니라 번역 대상이 아니다(RUN.md "QA 런치 인자").
SKIP_FILES = {"ButtonGalleryView.swift", "GlyphGalleryView.swift", "DishGalleryView.swift",
              "TiltLabOverlay.swift", "TitleClipLabView.swift"}

# 보간 `\(…)` — 안쪽 따옴표와 괄호 한 겹까지 삼킨다(`joined(separator: ", ")`).
ATOM = r'(?:[^()"]|"[^"]*")'
PAREN = rf'\((?:{ATOM}|\({ATOM}*\))*\)'
# 문자열 리터럴 본문 — 평범한 문자 / 보간 / 그 밖의 이스케이프.
BODY = rf'(?:[^"\\]|\\{PAREN}|\\.)*'
# 로컬라이즈 문자열을 받는 호출 형태. Text(verbatim:)·String(format:)은 대상이 아니다.
CALLS = re.compile(
    r'(?<![A-Za-z0-9_])(?:Text|Button|Label|TextField|Toggle|SheetHeader|CoverHeader)'
    rf'\(\s*(?:title:\s*|subtitle:\s*)?"({BODY})"'
    rf'|(?<![A-Za-z0-9_])String\(localized:\s*"({BODY})"'
    rf'|\.accessibility(?:Label|Hint|Value)\(\s*(?:Text\(\s*)?"({BODY})"'
)
PLACEHOLDER = " "
INTERPOLATION = re.compile(r'\\' + PAREN)
SPECIFIER = re.compile(r"%(?:\d+\$)?[-+ #0]*[\d.]*(?:ll|l|h|z)?[@dfsu%]")
HAS_LETTER = re.compile(r"[^\W\d_]", re.UNICODE)


def norm(s: str) -> str:
    s = SPECIFIER.sub(PLACEHOLDER, INTERPOLATION.sub(PLACEHOLDER, s))
    return s.replace("\\n", "\n").replace('\\"', '"').strip()


def code_literals() -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}
    for path in sorted(SOURCE.rglob("*.swift")):
        if path.name in SKIP_FILES:
            continue
        for lineno, line in enumerate(path.read_text().splitlines(), 1):
            if "verbatim:" in line:
                continue
            for match in CALLS.finditer(line):
                raw = next(g for g in match.groups() if g is not None)
                # 글자가 하나도 없는 리터럴(자리표시자·기호·숫자만)은 번역할 것이 없다.
                if not HAS_LETTER.search(norm(raw)):
                    continue
                found.setdefault(raw, []).append(f"{path.relative_to(ROOT)}:{lineno}")
    return found


def main() -> int:
    keys = set(json.loads(CATALOG.read_text())["strings"])
    registered = {norm(k) for k in keys}
    literals = code_literals()
    missing = {raw: at for raw, at in literals.items() if norm(raw) not in registered}

    for raw, at in sorted(missing.items()):
        print(f"MISSING {raw!r}  ({at[0]})")
    if "--orphans" in sys.argv:
        used = {norm(raw) for raw in literals}
        for key in sorted(k for k in keys if norm(k) not in used):
            print(f"orphan? {key!r}")

    print(f"{len(keys)} keys / {len(literals)} literals / {len(missing)} missing")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
