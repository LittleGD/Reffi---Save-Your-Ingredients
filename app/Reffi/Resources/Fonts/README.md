# Fonts (이후 단계 투입 자리)

정본 디자인 시스템(§3)의 폰트:

| 위계 | 한글 | 영문/숫자 |
|---|---|---|
| Display | Pretendard Bold (폴백) | Story Script (weight 400) |
| 그 외 | Pretendard | Google Sans Flex |

## 투입 절차
1. 폰트 파일(.otf/.ttf)을 이 폴더에 넣는다.
   - Pretendard: https://github.com/orioncactus/pretendard (OFL)
   - Story Script / Google Sans Flex: Google Fonts
2. `project.yml`의 Reffi 타깃 `info`에 `UIAppFonts` 배열로 파일명을 등록한다.
3. `DesignSystem/ReffiTypography.swift`의 `customFamily`에 등록된 PostScript 패밀리명을 넣는다.
4. `xcodegen generate` 후 빌드.

현재 1차 셋업은 시스템 폰트(SF)로 동작한다.
