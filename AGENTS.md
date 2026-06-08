# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project overview

AlphaSchool (`alpha_school` in `pubspec.yaml`) is a Flutter parent/school mobile app — currently UI-heavy, with a small shared network layer and a couple of live API integrations. Product framing lives in [PRODUCT.md](PRODUCT.md) (parents choosing an academic year and signing in; "minimal, friendly, trustworthy"; avoid glassmorphism/heavy gradients/dark UI) and [DESIGN.md](DESIGN.md) (color tokens `#0756D1` family, Inter/Noto Sans Lao typography, ~480px centered column). Check both before making visual changes — note that a lot of existing feature UI (dark gradients, glass cards) predates and conflicts with these newer design docs; don't assume existing styling is the target to match for new work.

[AGENT.md](AGENT.md) is a second, more detailed agent-guidance doc covering the network layer, auth, QR scanner, and global alert system. It's mostly accurate (verified against code below), **except** its "Authentication Flow" and "Known Analyzer And Test Notes" sections — see "Where AGENT.md disagrees with the code".

## Commands

```sh
flutter pub get                  # install dependencies
flutter run                      # run on a connected device/simulator
flutter run -d chrome            # run in browser
dart format <files-or-dirs>      # format touched files
dart analyze <path>              # analyze a focused path/file (see Known issues — whole-project analyze is noisy)
flutter test                     # run tests (see Known issues — the only test is the stale counter template)
flutter build web                # production web build -> build/web (Firebase Hosting target "alphaschool-f68eb", see firebase.json)
```

There's no CI config or custom build tooling beyond the standard Flutter toolchain.

## Environment configuration

The API base URL **must** come from `.env` (gitignored; present locally as `API_BASE_URL=http://localhost:3001/api/v2`):

```
API_BASE_URL=<your-api-base-url>
```

- `ApiConfig.baseUrl` (`lib/core/network/api_config.dart`) throws `StateError` when it's missing/empty — intentional, so a broken env setup fails loudly instead of silently calling the wrong host.
- Never hardcode an API base URL, use `String.fromEnvironment`, or add a fallback URL — this applies to Dart files, README/docs, tests, and feature services alike.
- `.env` is loaded with `isOptional: true` in `main.dart`, but real network calls still require `API_BASE_URL` to resolve.

## Architecture

### Navigation flow
`lib/main.dart` builds `CConnectApp` → `MaterialApp` with `home: YearPickerPage()` and one named route, `/homeShell` → `HomeShellPage`. `navigatorKey: GlobalAlert.navigatorKey` must stay wired (the alert system shows dialogs without a local `BuildContext`); `themeMode` is pinned to `ThemeMode.light`.

Flow: `YearPickerPage` (pick academic year) → `LoginPage` → role-based routing inside `_LoginPageState._submit`:
- role `parents` (case-insensitive match via `AuthenticatedAdmin.isParent`) → `StudentsCardListPage` → `HomeShellPage`
- any other role → `ScanQrCodePage`

`HomeShellPage` is a bottom-tab shell (`lib/features/home/presentation/pages/tabs/`) wrapping, in order: `ExplorePage` (mainhomepage.dart), `ClassroomPage`, `StudyPlanPage` (score.dart), `FeePage`, `SettingsPage` — with hardcoded Lao bottom-nav labels (ໜ້າຫຼັກ / ຫ້ອງຮຽນ / ຜົນການຮຽນ / ຄ່າທຳນຽມ / ຕັ້ງຄ່າ).

### Directory layout (feature-first under `lib/`)
- `core/network` — `ApiClient` / `ApiConfig` / `ApiException`: the **only** sanctioned way to call the API (see below). Prefer `ApiClient` over direct `http` in feature code.
- `core/theme` — `AppTheme` (light-only `ThemeData` factory, locale-aware fonts) and `AppColors` (royal-blue palette matching DESIGN.md).
- `core/constants` — `app_colors.dart` defines `GlobalAlertColors` (⚠️ same filename as `core/theme/app_colors.dart` but a **different class**, used only by the alert dialog — don't mix up the two imports).
- `core/widgets` — shared widgets: `AppPageTemplate` (page shell: background image + animated top bar + back handling), `AppBottomNav`, `GlobalAlert`, and the QR scanner (`scanqrcode/scan_qr_code_page.dart`).
- `core/services` — `GlobalAlertService` and `SessionService` (persists the logged-in admin's id/username/email/branch id via `shared_preferences`).
- `core/localization` — `L10n`, a tiny hardcoded `en`/`th` string-lookup table; currently **unused** (no call sites). Locale-dependent behavior actually goes through `AppTheme` (Lao locale → Noto Sans Lao font) and hardcoded strings in widgets, not through `L10n` or the `assets/l10n/*.arb` files (which also have no loader).
- `features/auth` — `AuthService` (data) + `LoginPage`/`RegisterPage` (presentation).
- `features/students` — `StudentsCardListPage`.
- `features/home` — `HomeShellPage`, its 5 tabs, and most feature pages: appointment, attendance, calendar, contact, gallery, homework, news, notifications, participant, profile, report, saving, task, etc. Each non-trivial feature follows `<feature>_model.dart` / `<feature>_service.dart` / `<feature>_page.dart` (see `appointment/` for the fullest example).
- `features/demo` — `SubPageDemo` (`DemoTest.dart`): scratch/template code showing how to wrap a page in `AppPageTemplate`, not a real feature.
- `shared/models` — small cross-feature models, e.g. `StudentCardItem`.

Feature pages are mostly presentation-layer widgets. Add service/model files only where a feature needs API data or shared parsing, and keep them close to that feature unless they're genuinely shared (per AGENT.md's "Git And Editing Rules").

### Network layer
All API access goes through `ApiClient` with **relative** paths:
```dart
final api = ApiClient();
final data = await api.get('/appointments');
```
`ApiClient` resolves the path against `ApiConfig.baseUrl`, sets JSON headers, applies a 20s timeout, JSON-decodes the response, and converts failures (timeout, connection, bad JSON, non-2xx) into `ApiException` (carrying `statusCode`/`body` when available).

The backend's response shape is inconsistent, so feature services parse defensively — both `AuthService._extractAdmins` and `AppointmentService._extractItems` accept "bare array OR `{data: [...]}` OR `{<resource-name>: [...]}` OR `{results: [...]}`". Follow that pattern for new endpoints. Currently-used endpoints: `/admins`, `/appointments`, `/academic-years` (the last two used together by `AppointmentService` to resolve `branch_id`/`academic_year_id` when posting a new appointment).

### Theming
`AppTheme` (`lib/core/theme/app_theme.dart`) is effectively light-only: `AppTheme.mode`/`themeMode`/`isDarkMode` are pinned to light and `darkTheme()` just delegates to `lightTheme()`. Fonts are chosen per-locale via `google_fonts` (`Locale('lo')` → Noto Sans Lao, else Inter). `AppColors` holds the royal-blue palette (`blue100`..`blue500`, `dark`, `slate`, `gray*`).

### Global alert system
`GlobalAlert` (`lib/core/widgets/global_alert.dart` + `lib/core/services/global_alert_service.dart`) is a custom (non-package) dialog system reachable from anywhere via the app-level `navigatorKey` — use it instead of ad hoc `SnackBar`/`AlertDialog` for important user-facing feedback:
```dart
GlobalAlert.showError(title: '...', message: '...');
GlobalAlert.showSuccess(title: '...', message: '...');
final ok = await GlobalAlert.showConfirmation(title: '...', message: '...');
GlobalAlert.showLoading(message: '...');
GlobalAlert.dismiss();
```
`GlobalAlertType` is `{ success, error, warning, info, confirm, loading }`. Visuals are custom Flutter (rounded card, top radial glow, large status icon, `showGeneralDialog` fade/scale/slide) — not a dialog package.

### Auth — actual current behavior
- `AuthService.login()` (`lib/features/auth/data/auth_service.dart`) calls `GET /admins`, matches the entered login against either `username` or `email` (case-insensitive), and checks `password`/`pass`/`admin_password` only if the API actually returns one of those fields (otherwise a username/email match is treated as sufficient — a backend limitation, not a long-term design).
- Role resolves from `roles[0].name`, falling back to `role`/`role_name`; an exact lowercase match of `parents` routes to the parent flow, everything else to `ScanQrCodePage`.
- `LoginPage` has a **"Remember me" checkbox** (on by default) that persists the **plaintext** email/password to `shared_preferences` (`login_saved_email` / `login_saved_pass`) and reloads them on the next visit. There is no biometric/auto-login flow — `local_auth` and `flutter_secure_storage` are pubspec dependencies with zero references in `lib/`.
- `SessionService` separately stores the logged-in admin's id/username/email/branch id; `AppointmentService` later reuses `branchId` (and falls back to re-fetching `/admins` if it's missing) when creating appointments.

### QR scanner
`lib/core/widgets/scanqrcode/scan_qr_code_page.dart` wraps `mobile_scanner` (`DetectionSpeed.noDuplicates`, QR-only, `autoZoom: true`, back camera) with a custom full-screen overlay (cutout window, animated scan line, corner frame, floating back/torch/switch-camera buttons). On detection it drives `GlobalAlert` (`showLoading` → `showSuccess`/`showError`) rather than popping the result back via `Navigator.pop(code)` — keep that behavior unless explicitly asked to change it.

## Where AGENT.md disagrees with the code

AGENT.md's **"Authentication Flow"** section describes a fingerprint/Face-ID "Auto Login" feature (storing only a "last route type", explicitly never plaintext passwords, "Remember me" already "removed from the login UI") and its **"Known Analyzer And Test Notes"** mentions an unused `_setLocale` in `main.dart`. None of this matches the current code: there are no `local_auth`/`LocalAuthentication`/secure-storage references anywhere in `lib/`, the Remember-me checkbox is present and stores plaintext credentials (see Auth above), and `main.dart` has no `_setLocale` at all. Treat those specific claims as stale/aspirational and trust the code instead — the rest of AGENT.md (network rules, QR scanner config, appointment field/status mapping, global alert usage, registered assets) does check out.

## Known issues / gotchas

- `dart analyze` over the whole project surfaces many pre-existing info-level warnings (`withOpacity` deprecation, missing `const`, `WillPopScope`/`onPopInvoked` deprecations, a `flutter_localizations` analyzer-dependency warning). Don't treat these as blockers for unrelated work — scope `dart analyze` to the files/dirs you actually touched.
- `test/widget_test.dart` is still the unmodified Flutter counter-app template; it asserts on counter UI this app no longer has, so `flutter test` fails out of the box regardless of your change. Inspect it before concluding a failure means you broke something.
- `lib/features/demo/DemoTest.dart` (`SubPageDemo`) and `lib/core/localization/l10n.dart` (`L10n`, plus `assets/l10n/*.arb`) are dead/scratch code with no real call sites — don't build on them without checking first.
- Two files are both named `app_colors.dart` (`core/theme/` → `AppColors`, `core/constants/` → `GlobalAlertColors`); double-check which one you're importing.
