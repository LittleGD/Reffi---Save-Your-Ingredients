# Reffi 소개 사이트 (정적)

Google Labs Pomelli로 만든 앱 소개 페이지의 정적 내보내기입니다. `index.html` 한 장과 `resources/` 이미지 13장 및 Figma 워드마크 SVG, 루트의 `favicon.ico`(16·32·48, iOS식 둥근 모서리)와 `apple-touch-icon.png`(180, 정사각)로 구성되며, 두 아이콘은 앱의 `AppIcon.appiconset/reffi-icon-1024.png`에서 생성했습니다. 외부 의존은 폰트 서버 두 곳(Google Fonts의 Google Sans Flex, jsDelivr의 OK단단체)만 있습니다. 자세한 내용은 아래 "제3자 접속처와 라이선스"를 참고합니다. 스크립트는 히어로 낙하 애니메이션용 인라인 코드 하나뿐이고, 추적·분석 코드는 없습니다.

- 원본 편집: Pomelli 웹사이트 에디터(버전 V15 기준). Pomelli에서 수정하면 이 폴더를 다시 내보내야 합니다.
- 이미지: `resources/<id>.png`는 앱에서 뽑은 재료 글리프 8종(투명 PNG, 여백 트림, 긴 변 480px 이하)과 화면 스프라이트 시트 5장(4×3, 12프레임, 1208×1968)입니다. `resources/reffi-logo.svg`는 앱과 홈페이지가 공유하는 Figma 워드마크입니다. 히어로 토마토도 다른 조각과 같은 앱 글리프 렌더입니다(2026-09-10에 앱 아이콘의 토마토로 바꿔 봤지만 종이 질감이 없어 혼자 튀어 보여 글리프로 되돌림). 현재 아트워크는 main `acfbff1`(빌드 27) 기준입니다. 글리프는 `PaperSilhouette`를 `ImageRenderer`로 투명 배경 렌더한 것이고, 시트는 시뮬레이터 녹화 프레임을 격자로 합친 것입니다. 앱 일러스트가 바뀌면 같은 파일명으로 덮어쓰기만 하면 되고 `index.html`은 바꾸지 않습니다. 시트는 `.app-motion` CSS가 프레임 단위로 재생합니다.
- 배포: 정적 호스팅 어디서나 동작합니다. Vercel 프로젝트 `reffi-site`(heejae92)에서 https://reffi-site.vercel.app 으로 서빙 중이며, `vercel deploy --target preview`(미리보기) 또는 `--prod`(공개)로 올립니다.
- 문구: 2026-09-10 오너 지시로 **출시 전 기준**으로 씁니다. 베타·TestFlight 언급은 쓰지 않습니다. 주 CTA 두 개는 `Coming soon` 비활성 버튼이며, App Store URL이 확정되면 버튼을 링크로 바꾸고 출시 문구를 함께 갱신합니다. 보조 링크 "See how Reffi works"는 오너 지시로 제거했습니다(2026-09-10).
- 개인정보: `privacy.html`은 앱의 한국어와 영어 방침을 내보낸 페이지입니다. `python3 scripts/export-site-privacy.py --check`로 정본과 일치를 확인합니다. Vercel 배포는 Heejae92가 담당합니다.
- 재내보내기 시 위의 런칭 문구·CTA와 Privacy 링크를 보존하고, 인라인 스크립트가 바뀌면 `vercel.json`의 CSP 해시도 다시 계산합니다.

## 제3자 접속처와 라이선스
- 이 페이지를 열면 방문자 브라우저가 두 곳의 폰트 서버에 접속합니다: Google Fonts(`fonts.googleapis.com`, `fonts.gstatic.com` — Google Sans Flex)와 jsDelivr(`cdn.jsdelivr.net` — OK단단체 `OkDanDan-Bold.woff2`). 추적 스크립트나 분석 도구는 없습니다.
- OK단단체는 OFL이 아닌 OKTICON 무료 폰트로 임베딩은 허용되지만 파일 재배포는 제한됩니다. 그래서 저장소에 파일을 두지 않고 CDN에서 불러오며, 주소는 태그가 아니라 커밋 SHA(`284264275ba3…`)로 고정해 내용이 바뀌지 않게 했습니다(SHA-256 `ad0931dd…5343e`, 앱의 `scripts/prepare-font.py`와 동일). 고지문은 `Reffi/Resources/Fonts/OKDANDAN-NOTICE.md`를 따릅니다.
- CDN 장애 시에는 `font-display: swap`과 폴백 스택(Pretendard, Apple SD Gothic Neo, system-ui)으로 강등되어 레이아웃은 유지됩니다.
