# OK단단체 / OkDandan

- 제작자: OKTICON(오케이티콘 / OkFont).
- 폰트 원본 저작권: Copyright 2025. OKTICON(OkFont). all rights reserved.
- CSS 별칭: `OkDandan`. iOS PostScript 이름: `OkDanDan-Bold`.
- 사용자 지정 원본: https://cdn.jsdelivr.net/gh/projectnoonnu/2508-2@1.0/OkDanDan-Bold.woff2
- 라이선스 안내: https://noonnu.cc/font_page/1664
- 제작사 공식 다운로드: https://www.okticon.com/freefont/?bmode=view&idx=169969648

## 사용 조건

2026-09-06 확인한 배포 페이지의 OKTICON 라이선스는 개인·기업의 상업적 사용과 웹·앱 등의 임베딩을 허용한다. SIL OFL 라이선스는 아니다. 폰트 파일 자체의 유료 판매 및 직접 업로드를 통한 별도 재배포는 금지되며, 공유 시 공식 다운로드 링크를 사용한다. 무단 AI 학습 및 모델 훈련, 유사 폰트 제작과 스타일 도용도 제한된다. 폰트를 활용한 이미지는 제작사의 마케팅 콘텐츠에 활용될 수 있다. 최신 조건은 제작사 공식 채널을 따른다. 공식 페이지는 확인 시 HTTP 403으로 접근하지 못해, 위 배포 페이지에 게시된 라이선스를 근거로 기록했다.

## 앱 리소스

`OkDanDan-Bold.ttf`는 제공된 WOFF2의 압축 컨테이너만 fontTools로 해제한 TrueType 파일이다. 이름, 글리프, 자폭 및 메트릭은 변경하지 않았다. 원본 내부 weight 값은 500이며, 웹 CSS는 제공된 예시대로 normal(400)에 매핑한다. iOS는 원본 PostScript 이름으로 로드하며 합성 Bold를 추가하지 않는다. 앱 실행 중 폰트 CDN 요청은 없다.

ASCII 인쇄 문자 95자와 한글 완성형 11,172자 포함을 확인했다.

SHA-256:

- WOFF2: `ad0931ddd19f106c6f1f3b065b924b03b47a6e7263ddbf941764318568f5343e`
- TTF: `0b28e6bb4b24da2f2d66510c538ecb79f4124fa482a58a51eff5a1f17a1b2f05`

공개 저장소에는 TTF를 커밋하지 않는다. `python3 scripts/prepare-font.py`로 XcodeGen 실행 전에 준비하며, 앱 번들 임베딩에만 사용한다.
