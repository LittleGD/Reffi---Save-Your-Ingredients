# Reffi 인증 설정 가이드

앱은 Supabase Auth를 쓴다. **이메일 가입/로그인은 추가 설정 없이 바로 동작**한다.
Apple/Google 로그인은 아래 콘솔 설정(개발자 계정 필요)을 마쳐야 실제로 성공한다 — 앱 코드는 이미 완성돼 있어 설정만 하면 켜진다.

## 프로젝트 정보
- Supabase 프로젝트: `reffi` (ref: `itianwvwbeixfarblqzy`, 리전 ap-northeast-2 서울)
- 대시보드: https://supabase.com/dashboard/project/itianwvwbeixfarblqzy
- API URL·publishable key: `Reffi/Data/AuthStore.swift`에 임베드(공개 키라 안전, 데이터 보호는 RLS로)
- OAuth 콜백 스킴: `reffi://auth-callback` (Info.plist `CFBundleURLTypes`, project.yml에서 생성)

## 1. 이메일 로그인 (완료 — 바로 동작)
- 기본값으로 **가입 확인 메일**이 켜져 있다. 가입 → 메일 링크 클릭 → 로그인 순서.
- 확인 절차 없이 즉시 로그인시키려면: Dashboard → Authentication → Sign In / Up → Email → **Confirm email 끄기**.

## 2. Apple 로그인 (콘솔 설정 필요)
앱은 네이티브 Sign in with Apple 시트(ID 토큰 + nonce)를 띄워 Supabase로 교환한다.
1. Apple Developer(유료 계정) → Identifiers → App ID `com.reffi.app`에 **Sign in with Apple** capability 추가.
2. Xcode 타깃에 Sign in with Apple entitlement 추가 + 코드사이닝 활성화
   (현재 project.yml은 `CODE_SIGNING_ALLOWED: NO` — 시뮬레이터 전용이라 실기기 배포 시 팀 설정 필요).
3. Supabase Dashboard → Authentication → Sign In / Up → Apple 활성화 →
   **Client IDs에 `com.reffi.app` 추가** (네이티브 플로우는 Service ID·Secret 불필요).

## 3. Google 로그인 (콘솔 설정 필요)
앱은 시스템 브라우저(ASWebAuthenticationSession) OAuth 플로우를 쓴다.
1. Google Cloud Console → OAuth 동의 화면 구성 → **웹 애플리케이션** OAuth Client ID 생성.
   - 승인된 리디렉션 URI: `https://itianwvwbeixfarblqzy.supabase.co/auth/v1/callback`
2. Supabase Dashboard → Authentication → Sign In / Up → Google 활성화 →
   Client ID / Client Secret 입력.
3. (선택) Dashboard → Authentication → URL Configuration → Redirect URLs에
   `reffi://auth-callback` 추가.

## 동작 확인
- 시뮬레이터: 이메일 가입/로그인, 게스트 모드는 즉시 확인 가능.
- Apple 로그인은 시뮬레이터에서 entitlement 없이는 실패할 수 있다(에러 문구로 안내됨) — 설정 후 실기기/사이닝된 시뮬레이터 빌드에서 확인.
- QA 런치 인자: `-authView`(로그인 화면 직행) · `-onboarding`(온보딩 직행) ·
  `-resetOnboarding`(온보딩 초기화) · `-skipAuth`(게스트로 게이트 통과) · `-authGate`(게스트 해제)
