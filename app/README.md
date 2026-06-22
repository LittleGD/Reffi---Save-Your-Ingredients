# Reffi (iOS)

> 냉장고 속 재료가 버려지기 전에 "오늘 먹을 수 있게" 행동을 유도하는 앱.
> 영수증을 스캔하면 신선한 재료가 자동으로 쌓이고, 유통기한이 색으로 카운트다운된다.

네이티브 iOS 앱. SwiftUI + SwiftData, **최소 iOS 26.0**.

## 구조

```
reffi-ios/
  project.yml              XcodeGen 설정 → Reffi.xcodeproj 생성
  Reffi/
    ReffiApp.swift         @main · SwiftData 컨테이너
    DesignSystem/          색·타이포·간격·곡률·그림자 토큰 (정본 DS 이식)
    Models/                Ingredient(@Model) · Freshness · SampleData
    Features/Home/         카드 스택 홈 화면
    Resources/             Assets.xcassets · Fonts
```

디자인 시스템 정본: `Heejae92/Reffi---Save-Your-Ingredients` 레포의 `design_system.md`
(OKLCH 파스텔 Fresh/Soon/Urgent + Reffi Blue, Pretendard 한글 / Story Script·Google Sans Flex 영문).

## 처음 여는 법

```bash
# 1) (최초 1회) 커맨드라인 도구를 Xcode로 전환 — 비밀번호 필요
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 2) 프로젝트 생성 (project.yml 수정 시마다)
cd reffi-ios
xcodegen generate

# 3) 열기
open Reffi.xcodeproj
```

Xcode에서 시뮬레이터(iPhone, iOS 26)를 선택하고 ⌘R로 실행하면
샘플 식재료가 든 카드 스택 홈 화면이 뜬다.

## 다음 단계 (셋업 이후)
- Pretendard / Story Script / Google Sans Flex 폰트 투입 (`Resources/Fonts/README.md`)
- 카드 탭 → 상세 바텀시트, 스와이프 삭제 (§8.4)
- 영수증 스캔(카메라/Vision) → 재료 자동 등록
- 유통기한 촬영 → 카운트다운 시작
- 남은 재료 기반 AI 레시피 추천
