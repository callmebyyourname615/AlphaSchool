# AGENT.md

Guidance for agents working on the AlphaSchool Flutter project.

## Project Overview

AlphaSchool is a Flutter school/parent mobile app. It is currently a UI-heavy app with a small shared network layer and a few live API integrations.

The app starts at `YearPickerPage`, then goes to `LoginPage`, then routes by user role:

- `Parents` role goes to the existing parent flow: `StudentsCardListPage` and then `HomeShellPage`.
- Any non-parent role goes to `ScanQrCodePage`.

The app supports light/dark themes through `AppTheme.mode` and uses shared page shells/components under `lib/core`.

## Tech Stack

- Flutter/Dart
- Material UI
- `http` for REST calls
- `flutter_dotenv` for environment config
- `shared_preferences` for lightweight local login preferences
- `mobile_scanner` for QR scanning
- UI packages include `font_awesome_flutter`, `google_fonts`, `flutter_animate`, `convex_bottom_bar`, `remixicon`, and Syncfusion calendar packages

## Environment And API Rules

All API calls must use the shared network layer:

- `lib/core/network/api_config.dart`
- `lib/core/network/api_client.dart`
- `lib/core/network/api_exception.dart`

The API base URL must come from `.env` only:

```text
API_BASE_URL=<your-api-base-url>
```

Do not hardcode the API base URL in Dart files, README files, tests, or feature services. Do not add `String.fromEnvironment` or a fallback URL for API base config.

`ApiConfig.baseUrl` throws a `StateError` if `API_BASE_URL` is missing or empty. This is intentional, so missing environment setup fails clearly.

Use relative API paths with `ApiClient`:

```dart
final api = ApiClient();
final data = await api.get('/appointments');
```

Do not call full URLs from feature pages or services.

## App Entry Point

`lib/main.dart`:

- Calls `WidgetsFlutterBinding.ensureInitialized()`
- Loads `.env` with `dotenv.load(fileName: '.env', isOptional: true)`
- Starts `CConnectApp`
- Registers `/homeShell`
- Uses `YearPickerPage` as `home`
- Supports `en`, `lo`, and `th` locales

Although `.env` loading is optional at startup, network calls still require `API_BASE_URL` through `ApiConfig.baseUrl`.

## Directory Structure

Important directories:

- `lib/core/localization`: lightweight localization helper.
- `lib/core/network`: shared REST client and API config.
- `lib/core/theme`: app colors and light/dark theme.
- `lib/core/widgets`: shared UI widgets and QR scanner.
- `lib/features/auth`: login page and auth service.
- `lib/features/students`: student selection flow.
- `lib/features/home`: home shell, tabs, and feature pages.
- `lib/shared/models`: shared simple models.

Feature pages are currently mostly presentation-layer Flutter widgets. Only add service/model files where a feature needs API data or shared parsing.

## Authentication Flow

Auth lives in:

- `lib/features/auth/data/auth_service.dart`
- `lib/features/auth/presentation/pages/login_page.dart`

`AuthService.login()` checks two endpoints with OR semantics — admin and
parent accounts live in separate backend tables, so either may hold the
matching login. `GET /admins` is tried first; if no active account matches,
`GET /parents` is tried next; the first match wins:

```text
GET /admins
GET /parents
```

Expected response for either endpoint can be:

- A direct array of records
- `{ "data": [...] }`
- `{ "admins": [...] }` / `{ "parents": [...] }`
- `{ "results": [...] }`

The login field matches either `username` or `email` (case-insensitive) on
whichever endpoint is being checked. Active-status is read from `is_active`
(admins, snake_case) or `isActive` (parents, camelCase) — missing/null counts
as active, matching the previous behavior.

Password behavior:

- If the API returns `password`, `pass`, `admin_password`, or `passwordHash`, it must match the form password.
- If the API does not return any password field, the current code treats username/email match as enough. This matches the current backend response shape (neither `/admins` nor `/parents` currently returns a password field — `Parent.passwordHash` is `select: false` server-side), but should be replaced with a proper login endpoint (`POST /auth/login` / `POST /auth/parent/login` exist server-side with real bcrypt checks) if/when the app is wired up to use one.

Role and routing behavior:

- Role is read from `roles[0].name` first.
- Fallback role fields are `role` and `role_name`.
- An account found via `GET /parents` always routes to the parent flow — being in that table is itself the parent signal — regardless of its `roles` content (handles seed data where some parent records have an empty `roles: []`).
- An account found via `GET /admins` routes to the parent flow only when its role is a lowercase-exact match to `parents` (e.g. an admin-table test account explicitly assigned the "Parents" role).
- Parent-flow accounts route to `StudentsCardListPage`; everything else routes to `ScanQrCodePage`.
- This is exposed as `AuthenticatedUser.isParent` (`isParentRecord || roleName.toLowerCase() == 'parents'`).

Remember me:

- Removed from the login UI.

Auto Login:

- Implemented in `LoginPage` with `local_auth` and `shared_preferences`.
- When the Auto Login checkbox is enabled, the app prompts fingerprint/face authentication immediately.
- After a normal login succeeds with Auto Login enabled, the app stores only the last route type (`Parents` vs non-parent), not the username or password.
- On the next login page open, if Auto Login is enabled and a last route exists, the app prompts fingerprint/face authentication first and routes automatically on success.
- iOS requires `NSFaceIDUsageDescription` in `ios/Runner/Info.plist`.
- Android requires `android.permission.USE_BIOMETRIC` and `MainActivity` extends `FlutterFragmentActivity`.
- Never store plaintext passwords for Auto Login.

## Appointment API Integration

Appointment files:

- `lib/features/home/presentation/pages/appointment/appointment_model.dart`
- `lib/features/home/presentation/pages/appointment/appointment_service.dart`
- `lib/features/home/presentation/pages/appointment/appointment_page.dart`

Endpoint:

```text
GET /appointments
```

Expected response can be:

- A direct array
- `{ "data": [...] }`
- `{ "appointments": [...] }`
- `{ "results": [...] }`

The service filters out:

- `is_deleted == true`
- `is_active == false`

Field mapping:

- `title` -> appointment title
- `description` -> note
- `appointment_place` -> note suffix
- `date` -> appointment date
- `from_time` -> start time
- `to_time` -> end time
- `status` -> `AppointmentStatus`

If status is `RESCHEDULED` or `POSTPONED`, the UI uses:

- `rescheduled_date`
- `rescheduled_from_time`
- `rescheduled_to_time`

Supported status mapping:

- `CONFIRMED`, `APPROVED`, `ACCEPTED` -> confirmed
- `CANCELLED`, `CANCELED`, `DECLINED` -> cancelled
- `RESCHEDULED`, `POSTPONED` -> postponed
- Anything else -> pending

The appointment page shows loading, retry, and empty states. If today has no appointments but the API returns appointments for another day, the page selects the first appointment date automatically.

## QR Scanner

QR scanner file:

- `lib/core/widgets/scanqrcode/scan_qr_code_page.dart`

It uses `mobile_scanner`.

Current scanner config:

- `DetectionSpeed.noDuplicates`
- `formats: const [BarcodeFormat.qrCode]`
- `autoZoom: true`
- Back camera

The page has a custom full-screen scanner UI:

- Dark camera overlay
- Cutout scan window
- Animated scan line
- Custom QR frame corners
- Floating back, torch, and switch-camera buttons

When a QR code is detected, it uses the global alert system:

- Shows `GlobalAlert.showLoading(message: 'Validating QR code...')`
- Dismisses loading after validation
- Shows `GlobalAlert.showSuccess(...)` for valid scanned strings
- Shows `GlobalAlert.showError(...)` if validation fails

Do not change scanner behavior back to `Navigator.pop(code)` unless the user explicitly asks for scan result return flow.

## Global Alert System

Global alert files:

- `lib/core/constants/app_colors.dart`
- `lib/core/widgets/global_alert.dart`
- `lib/core/services/global_alert_service.dart`

`MaterialApp` must keep:

```dart
navigatorKey: GlobalAlert.navigatorKey,
```

Alert types are represented by `GlobalAlertType`:

- `success`
- `error`
- `warning`
- `info`
- `confirm`
- `loading`

Use the `GlobalAlert` service from any page:

```dart
GlobalAlert.showError(
  title: 'Authentication Error',
  message: 'Please try again later.',
);

GlobalAlert.showSuccess(
  title: 'Scan Successful',
  message: 'Your QR code has been scanned successfully.',
);

final confirmed = await GlobalAlert.showConfirmation(
  title: 'Warning',
  message: 'Are you sure you want to continue?',
);

GlobalAlert.showLoading(message: 'Please wait...');
GlobalAlert.dismiss();
```

The visual design is custom Flutter, not a package dialog: dark overlay, rounded dark card, top radial glow, large circular status icon, full-width action button, and `showGeneralDialog` fade/scale/slide animation.

## UI And Design Conventions

The existing app uses a polished, animated mobile UI with:

- Strong light/dark theme support
- `AppPageTemplate` for feature pages
- `ValueListenableBuilder<ThemeMode>` around pages that need theme switching
- `flutter_animate` for entry animations
- Card-like panels with rounded corners and dark premium gradients in some areas
- Font Awesome icons in the login screen
- Material icons elsewhere

When adding UI:

- Prefer existing shared widgets from `lib/core/widgets`.
- Keep dark mode readable.
- Preserve current page-specific styling unless asked for a redesign.
- Avoid unrelated broad refactors.
- Be careful with overflow on small phones.

## Assets

Registered assets include:

- `.env`
- `assets/images/`
- `assets/l10n/`
- `assets/images/homepagewall/`
- `assets/images/homepagewall/homepagewallpaper.jpg`
- `assets/images/homepagewall/mainbg.jpeg`
- `assets/images/profile/me.jpg`

The main background used by many feature pages is:

```text
assets/images/homepagewall/mainbg.jpeg
```

## Common Commands

Install dependencies:

```sh
flutter pub get
```

Run app:

```sh
flutter run
```

Run web:

```sh
flutter run -d chrome
```

Format touched Dart files:

```sh
dart format <files-or-directories>
```

Analyze focused files:

```sh
dart analyze lib/core/network
dart analyze lib/features/auth/data/auth_service.dart
dart analyze lib/core/widgets/scanqrcode/scan_qr_code_page.dart
```

Build web:

```sh
flutter build web
```

## Known Analyzer And Test Notes

The project has many pre-existing analyzer info warnings, especially:

- `withOpacity` deprecation
- missing `const` suggestions
- `WillPopScope`/`onPopInvoked` deprecations
- an unused `_setLocale` in `lib/main.dart`
- `flutter_localizations` analyzer dependency warning

Do not treat those project-wide info warnings as blockers unless the task is specifically cleanup.

The default `test/widget_test.dart` still appears to be the Flutter counter template test and may fail because this app no longer displays the counter demo. Do not assume a failing `flutter test` means your feature change is broken until the test has been inspected.

## Git And Editing Rules For This Repo

- The worktree may contain user or prior-agent changes. Do not revert unrelated files.
- Use focused patches.
- Keep service/model additions close to their feature unless they are truly shared.
- Do not move large UI files unless the user asks.
- Do not hardcode API base URLs.
- Do not store plaintext passwords for Auto Login or any login convenience feature.
- Prefer `ApiClient` over direct `http` in feature code.

## Current Live API Endpoints Used

Feature services currently use these relative endpoints:

```text
/admins
/parents
/appointments
```

All are resolved against `.env` `API_BASE_URL` by `ApiClient`.
