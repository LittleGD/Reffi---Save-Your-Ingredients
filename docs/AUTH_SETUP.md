# Reffi authentication, build 25

Supabase project: `bzzpmaeitfbbunsmjvmd`, Seoul. Dashboard: https://supabase.com/dashboard/project/bzzpmaeitfbbunsmjvmd

## Launch methods

Email signup/login and local guest mode are the supported launch methods. Apple and Google are hidden until provider setup, device login and account deletion are verified. Keeping native implementations in source does not make those providers release-ready.

`AuthStore.refreshAvailability()` reads `/auth/v1/settings`. Anonymous sign-in is attempted only when enabled there; otherwise guest mode remains local. Usage events cannot upload without a server session. Analytics is optional and off by default.

## Email verification and password recovery

Add `reffi://auth-callback` to Authentication > URL Configuration > Redirect URLs. Signup, anonymous email upgrade and password recovery explicitly request this URL. Reffi handles the callback at the app root so the authentication sheet need not be open.

Verify email confirmation and recovery on a physical iPhone, including a cold launch from the email link. Production email sending/SMTP and rate limits also need verification before release.

## Account deletion

Apply `supabase/migrations/0003_account_deletion.sql` after `0002_analytics.sql`. The client calls `public.delete_own_account()` using the current session. It accepts no account ID. The database deletes the caller's analytics, legacy AI usage and auth account in one transaction. The client clears local data only after server success.

The RPC rejects Apple identities until server-side Apple token revocation is implemented. Apple/Google login remain hidden. Do not enable them by only changing a UI flag.

## Local data ownership

Fridge files and profile snapshots are kept per account on this device. First account registration transfers guest data; later logins restore that account's local data. Signing out opens separate guest storage. A damaged destination file blocks the switch and leaves the current data intact. There is no cloud fridge synchronization.

`Erase this device` removes all local account archives and signs out. `Delete account` removes the server account and the active account's local data. These are separate actions with separate confirmations.

## QA

`-authView` opens authentication directly. `-skipAuth -skipOnboarding -analyticsOff` opens an isolated simulator without authentication or telemetry. See `docs/RELEASE_READINESS.md` for validation commands and outstanding release requirements.
