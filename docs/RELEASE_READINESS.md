# Release readiness, build 26

## Implemented

- Recipe matching filters actual inventory, including substitutions and concrete ingredients matched to a generic recipe line, against allergy/vegetarian restrictions. Expired stock cannot fill a recipe line. Unknown allergy names stop recommendations until corrected.
- Original and opened use-by dates both prevent expired food from becoming fresh through freezing. Previously saved invalid freezes retain the expired date.
- Email and local guest are the launch authentication methods. Unverified Apple/Google buttons are hidden. Guest mode reads server availability before requesting an anonymous session. Email verification and password recovery return to `reffi://auth-callback`.
- `0003_account_deletion.sql` provides a caller-only, transactional account deletion RPC. It deletes analytics, legacy AI usage and the auth user; auth-owned identities/sessions cascade. A foreign key and RLS stop deleted users from writing new events. Apple identities are explicitly blocked until token revocation is implemented; Apple login stays hidden.
- The privacy policy is available offline from authentication and settings. Usage sharing defaults off. Analytics captures the token for each batch, drops queues on account changes and preserves new events if an older upload finishes after identity reset.
- Local fridge and profile data are stored per account. Switching accounts preserves the previous account; signing out opens separate guest storage. First account registration transfers guest data. Corrupt destination files abort the switch without clearing the current fridge.
- Cached authentication restores the local data owner immediately, including offline launches. Analytics waits for a non-expired session before uploading.
- Background analytics uploads end their UIKit background task only once, whether expiration or completion happens first.
- The app uses 48 selected Phosphor icons in all six weights as vector PDFs. The original shapes, Swift API and MIT license are preserved in `Vendor/PhosphorSwift`; app builds no longer compile the entire upstream SVG catalog.

## Build 26 verification on 2026-09-06

- OKDandan Display and Heading use -2% tracking and no extra SwiftUI line spacing; web specimens use 115% line height. Korean and English use the same font. The font is embedded in the app, but excluded from the public Git repository; `scripts/prepare-font.py` verifies the download and converted TTF hashes before XcodeGen runs.
- 645 tests passed: 627 unit tests (608 Swift Testing and 19 XCTest) and 18 UI tests. Zero failures. UI coverage includes cooking, fridge tabs/history/sorting, onboarding, shopping, authentication, privacy, accessibility and language switching.
- Localization: 455 keys, 361 source literals, zero missing keys. Seven local account-deletion SQL checks passed.
- A clean font preparation run without a pre-existing font succeeded and produced the expected SHA-256.
- Signed Release archive and App Store distribution export succeeded for version 1.0 (26), bundle ID `com.reffi.app`, team `L3RY7X2WBC`, using Cloud Managed Apple Distribution.
- This is a TestFlight QA candidate. The server deployment and privacy publication items below remain required before public release.

## Earlier build 25 verification on 2026-09-06

- Build 25 passed 632 tests on an isolated iPhone 17 simulator running iOS 26.5: 627 unit tests (608 Swift Testing and 19 XCTest) and 5 UI tests. Zero failures or skipped tests.
- UI coverage includes firing a cooking ticket, retaining checked cooking steps, the supported authentication entry points, opening authentication from the profile, and scrolling the Korean privacy policy at accessibility text size AX5. The new authentication and privacy screens were also visually inspected in light and dark appearance during this session.
- Localization check: 419 keys, 355 source literals, zero missing keys.
- All 250 recipes and 279 ingredient entries have valid canonical references, including alternative and safety references.
- All seven local account-deletion SQL checks passed.
- A signed Release archive and a local App Store distribution export both succeeded. The exported IPA uses `Apple Distribution: Jongmin Lee (L3RY7X2WBC)` and bundle ID `com.reffi.app`.
- No TestFlight/App Store upload, production database migration, commit or push was performed.

The exported build is a verification artifact. The server and privacy items below still block public release; a successful export does not prove App Store validation or actual-device behavior.

## Server deployment required

Apply `supabase/migrations/0003_account_deletion.sql` after the existing migrations in the project `bzzpmaeitfbbunsmjvmd`. The application must not be released before this succeeds and deletion is verified using a disposable account.

Verify the Supabase Auth redirect allowlist contains `reffi://auth-callback`. Verify email delivery, verification and password recovery using the release build. No test emails have been sent by this task.

The authenticated Supabase dashboard was inspected on 2026-09-06. The project uses the Free plan with a primary database in Seoul (`ap-northeast-2`), no scheduled project backups, and database auth-audit logging disabled. It still uses the built-in email service, which is not for production and restricts recipients; configure a production SMTP provider before launch. No production migration has been applied in this implementation session yet.

The dashboard also reports disabled RLS on `public.rejection_patterns`, `public.rejection_submissions` and `public.feedback`, including an exposed `feedback.session_id` warning. These tables are not established as Reffi-owned by the current source. Confirm whether the project is shared and review grants and policies without breaking other services before release.

## Privacy publication required

The operators are Jongmin Lee and Heejae Eo; the confirmed privacy contact is lee1993ljm@gmail.com. The service targets general audiences in the US and South Korea, not children. The offline policy includes this information and is explicitly marked as a pre-release review copy. It covers the actual data categories, local processing, YouTube search terms, Gmail inquiries, rights, providers and deletion distinctions. Processing countries, recipients, legal bases and server log/backup and inquiry retention still need verification. See `docs/PRIVACY_POLICY_REVIEW.md` for the evidence and unresolved details. Publish the final policy and configure the same URL in App Store Connect before submission.

The settings-footer and expanded-policy edits were made after the verified build 25 export above. Four focused UI tests cover the English/Korean footer position, policy opening/dismissal, authentication entry and Korean accessibility text. The localization gate reports 455 keys, 361 literals and zero missing keys. That previously exported IPA does not contain these later edits.

## Validation commands

```sh
xcodegen generate
python3 scripts/check-strings.py
xcodebuild -project Reffi.xcodeproj -scheme Reffi \
  -destination 'platform=iOS Simulator,id=<isolated-device-id>' \
  -derivedDataPath /tmp/reffi-release-fixed-dd \
  -only-testing:ReffiTests \
  -only-testing:ReffiUITests/ReffiFlowUITests \
  -only-testing:ReffiUITests/CookTicketFlickUITests/testTicketDeck_RightFlick_FiresTheFrontTicket \
  -only-testing:ReffiUITests/CookTicketFlickUITests/testKitchenCopySheet_ChecksPersistAcrossOpenClose test
```

The SQL test uses an in-memory PostgreSQL build with a minimal Supabase Auth schema. It executes all three real migrations and checks anonymous denial, caller isolation, account/data deletion, retry, deleted-JWT rejection, transaction rollback and the Apple revocation guard. This does not prove live server deployment or GoTrue integration.

```sh
npm install --prefix /tmp/reffi-sql-validation --no-audit --no-fund @electric-sql/pglite@0.5.8
PGLITE_MODULE=/tmp/reffi-sql-validation/node_modules/@electric-sql/pglite/dist/index.js \
  node scripts/test-account-deletion.mjs
```

## Remaining release verification

- Installation and launch of the distribution build on an actual iPhone through TestFlight.
- Actual receipt camera scan and notification delivery on an iPhone.
- Live email signup/login/recovery/deletion and public privacy-policy publication.
- Recipe quantities and sparse-fridge usefulness remain product limitations: recommendations are meal ideas, not a measured recipe subscription.

## Dependency reproducibility

The generated Xcode project remains ignored, except for `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. This retains the versions used to validate build 25, including Supabase Swift 2.51.0.

## Display font update

Display and Heading now use OKDandan in Korean and English. The published OKTICON license permits commercial use and embedding; the former Jeju Stone Wall font and its pending permission requirement have been removed. Separate redistribution of the font file is restricted. See `Reffi/Resources/Fonts/OKDANDAN-NOTICE.md`.
