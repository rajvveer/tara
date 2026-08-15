# GoalSpring

**Small steps. Visible progress.** GoalSpring is a Flutter goal-planning and
progress companion backed by a Node.js/TypeScript API and PostgreSQL. It turns
an intention into a workable rhythm:

`Goal -> Milestones -> Actions -> Progress -> Reflection`

The product is deliberately not a project-management tool. Today shows the
next useful action; each plan stays anchored to why the goal matters; and
progress rewards a sustainable weekly rhythm instead of an all-or-nothing streak.

## What is included

- Account registration, login, rotating sessions, completed password reset, safe
  JSON account export, guarded permanent deletion, onboarding, and preferences.
- Manual or multilingual AI voice onboarding with automatic spoken-language detection,
  animated recording feedback, a reviewable goal draft, and server-only Sarvam/Groq credentials.
- A guided **Goal -> Outcome -> Rhythm -> First steps** flow with prefilled
  templates, categories, cadence, preferred days, milestones, and concrete actions.
- Today, Goals, Insights, and You surfaces, including the full action lifecycle,
  milestone progress, weekly summaries/reflections, reminder preferences,
  light/dark themes, cached reads, and queued offline writes.
- A no-account sample space in the Flutter app and a seeded PostgreSQL demo
  account for testing the real client/API path.
- REST endpoints for goals, milestones, actions, routines, schedules, progress,
  reflections, notifications, and user preferences.
- PostgreSQL history for action transitions, progress records, soft-deleted
  planning data, notification state, and privacy-conscious product events.

The interaction and visual rationale lives in
[docs/DESIGN_DIRECTION.md](docs/DESIGN_DIRECTION.md). The user-selected visual
reference is Thu Phuong's
[Habit Land](https://www.behance.net/gallery/139913077/Habit-Land-Habit-Tracker-App-UX-UI):
GoalSpring adapts its cool canvas, cobalt selection, pastel category capsules,
calendar patterns, progress bubbles, and raised navigation rhythm while keeping
GoalSpring's branding, content, artwork, and flows original. Work Sans, accessible
contrast, scroll-safe 200% text layouts, and equally prominent Google and Apple
controls complete the system in light and dark modes.

## Architecture

```text
Flutter (Android / iOS / web)
  |  HTTPS JSON + bearer access token
  v
Express 5 + TypeScript + Zod
  |  Prisma
  v
PostgreSQL 17
```

| Path | Responsibility |
| --- | --- |
| `app/` | Flutter UI, domain mapping, API client, secure token storage, and non-secret offline cache |
| `server/src/` | REST API, validation, auth, user scoping, progress calculation, and OpenAPI document |
| `server/prisma/` | PostgreSQL schema, committed migrations, and demo seed |
| `server/tests/` | Progress/auth unit tests and the opt-in PostgreSQL API journey |
| `docs/` | Product and visual design decisions |

Each user owns goals; goals own milestones, actions, and routines; action state
changes append progress records. Reflections belong to a user and date range.
Notification preferences/records and first-party analytics events are stored in
PostgreSQL. The mobile client never connects to PostgreSQL directly.

## Prerequisites

- Node.js 20 or newer (the API container uses Node 22)
- Docker Desktop or Docker Engine with Compose v2
- Flutter with Dart 3.11.1 or newer
- Android Studio/Android SDK for Android development
- macOS with Xcode for iOS development
- Chrome for the optional Flutter web target

Run `node --version`, `docker compose version`, and `flutter doctor` before the
first setup. Resolve the platform checks reported by `flutter doctor` for the
device you intend to use.

## Local setup

### 1. Start PostgreSQL and the API

From PowerShell:

```powershell
cd server
Copy-Item .env.example .env
docker compose up -d postgres
npm ci
npm run db:deploy
npm run db:seed
npm run dev
```

On macOS/Linux, use `cp .env.example .env`; the remaining commands are the
same. The checked-in development defaults start PostgreSQL on `localhost:5432`
and the API on `http://localhost:4000`.

Verify the running stack:

- Health and database connectivity: <http://localhost:4000/health>
- Interactive Swagger UI: <http://localhost:4000/api/docs>
- OpenAPI 3.1 JSON: <http://localhost:4000/api/openapi.json>
- REST base: `http://localhost:4000/api/v1`

If host port `5432` is occupied, set `POSTGRES_PORT=5433` for Compose and change
the port in `server/.env`'s `DATABASE_URL` to `5433`. In PowerShell:

```powershell
$env:POSTGRES_PORT = "5433"
docker compose up -d postgres
```

Use `npm run db:migrate -- --name <change_name>` while developing a schema
change. Commit the generated migration and use `npm run db:deploy` everywhere
else. Do not use `prisma db push` for production.

### 2. Run Flutter

In a second terminal:

```powershell
cd app
flutter pub get
flutter devices
```

`API_BASE_URL` is a compile-time Dart definition and must include `/api/v1`.
Use the address that matches the target:

| Target | Command / API URL |
| --- | --- |
| Android emulator | `flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1` |
| Flutter web | `flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:4000/api/v1` |
| iOS Simulator | `flutter run -d <ios-simulator-id> --dart-define=API_BASE_URL=http://localhost:4000/api/v1` |
| Physical phone | Use `http://<computer-lan-ip>:4000/api/v1`; the phone and computer must share a network and the firewall must allow port 4000 |

The Android emulator URL is the app's development default, so the
`--dart-define` is optional for that target. Web is pinned to port `5173`
because it is included in the API's default CORS allowlist. A real phone cannot
use `localhost` to reach the development computer.

Local cleartext HTTP is for debug builds only. Release builds must use an HTTPS
API URL. iOS builds require macOS/Xcode; the checked-in `Debug.xcconfig` allows
local networking, while release configuration keeps App Transport Security intact.

### Demo choices

- Tap **Explore sample space** to use local sample data without the API or an
  account. Changes in that space are intentionally disposable.
- After `npm run db:seed`, use **`demo@onward.app`** /
  **`OnwardDemo123!`** to exercise the real API and PostgreSQL persistence.

The seed is for local or dedicated demo environments only.

## Configuration

Copy `server/.env.example` and keep real secrets out of version control.

| Variable | Required | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | Yes | PostgreSQL connection string used by Prisma |
| `JWT_SECRET` | Yes | Access-token signing secret; minimum 32 characters and unique per environment |
| `NODE_ENV` | No | `development`, `test`, or `production`; defaults to `development` |
| `PORT` | No | API port; defaults to `4000` |
| `JWT_ISSUER` | No | Expected JWT issuer; defaults to `onward-api` |
| `JWT_AUDIENCE` | No | Expected JWT audience; defaults to `onward-app` |
| `ACCESS_TOKEN_TTL` | No | Short access-token lifetime; defaults to `15m` |
| `REFRESH_TOKEN_DAYS` | No | Rotating refresh-session lifetime; defaults to `30` |
| `CORS_ORIGINS` | No | Comma-separated exact browser origins; native mobile requests normally have no origin |
| `POSTGRES_PORT` | No | Host port read by local Docker Compose; defaults to `5432` |
| `TEST_DATABASE_URL` | Tests only | Enables the PostgreSQL end-to-end suite |
| `API_BASE_URL` | Flutter build | REST base compiled into the client; defaults to Android emulator localhost mapping |

`APP_URL` in `.env.example` is reserved for public-link/email integration
metadata; the API does not currently consume it. Wire the final public app/deep
link URL when password-reset delivery is added.

## API contract and documentation

Successful JSON responses use `{ "data": ... }`; paginated lists also include
`meta`. Errors use `{ "error": { "code", "message", "details" }, "requestId" }`.
Authenticated routes require `Authorization: Bearer <accessToken>`. Dates are
ISO-8601, enum values are uppercase, and JSON fields are camelCase.

Swagger at `/api/docs` is the browsable route index. The source document is
served at `/api/openapi.json`, which can also be imported into Postman, Bruno,
or an OpenAPI client generator. See [server/README.md](server/README.md) for the
endpoint summary and response conventions.

## Progress status

GoalSpring does not label a goal from completion percentage alone. The calculation
uses all non-deleted actions, the goal timeframe, its cadence, and follow-through
on work that was already due:

```text
completion = completed actions / total actions
adherence  = completed due actions / all due actions
expected   = max(elapsed timeframe, expected cadence / total actions)
```

An action is due when `scheduledFor` (or, if absent, `dueDate`) is at or before
now. Future actions never reduce adherence. With no due actions, adherence is
100%. Cadence estimates one occurrence for `ONCE`, one per elapsed day for
`DAILY`, one per roughly 30 days for `MONTHLY`, and `weeklyTarget` across each
elapsed week for `WEEKLY`/`CUSTOM`. Expected action count is capped at the total
and is never lower than the number of actions already due.

Statuses are evaluated in this order:

| Status | Rule |
| --- | --- |
| `COMPLETED` | Goal is explicitly completed, or every action is completed |
| `AHEAD` | Completion is at least 10 percentage points above expected and adherence is at least 75% |
| `BEHIND` | Completion is more than 15 points below expected, or due-action adherence is below 50% |
| `NEEDS_ATTENTION` | Completion is more than 5 points below expected, or due-action adherence is below 70% |
| `ON_TRACK` | None of the conditions above apply |

Missed and skipped actions remain visible in counts and do not masquerade as
completed work. The implementation and focused tests are in
`server/src/goal-progress.ts` and `server/tests/goal-progress.test.ts`.

## Security and user isolation

- Passwords are bcrypt-hashed at cost 12 and excluded from public responses.
- Access JWTs are short-lived. Refresh tokens are high-entropy, stored in the
  database only as SHA-256 hashes, and rotated on refresh.
- Password-reset tokens are hashed, one-hour, single-use, and revoke all active
  sessions after a successful reset.
- The client stores access/refresh tokens in the platform secure store. Its
  shared-preferences cache contains display data, not auth tokens.
- Every user-owned API lookup is scoped by authenticated `userId`; unauthorized
  cross-account reads and writes return `404`. The PostgreSQL end-to-end test
  covers this boundary. This is application-level isolation, not PostgreSQL RLS.
- Zod validates trust boundaries. Helmet, allowlisted CORS, auth rate limiting,
  a 100 KB JSON limit, request IDs, foreign keys, and soft deletion provide
  additional defense and recoverability.

For production, use TLS, a least-privilege database role, encrypted managed
storage, automated backups/PITR, secret rotation, and a shared rate-limit store
before running more than one API instance.

## Analytics rationale

The API records a deliberately small first-party lifecycle stream:
`account_created`, goal/milestone/action creation, goal edits/completion, action
state changes, and `reflection_submitted`. Properties contain entity IDs and
broad categories/statuses; passwords, tokens, action descriptions, and
reflection text are not analytics properties.

These events are enough to measure whether onboarding leads to a goal, whether
goals become concrete actions, and whether reminders/reflection improve useful
follow-through. Keeping them in PostgreSQL avoids adding a third-party tracking
SDK before it is needed. Treat IDs as personal data: define retention, access,
deletion, and consent policies before exporting events to a warehouse or
analytics vendor.

## Tests and quality checks

Flutter:

```powershell
cd app
flutter analyze
flutter test
```

API unit tests, type checking, and production compilation:

```powershell
cd server
npm test
npm run typecheck
npm run build
```

The API journey is skipped unless it receives a disposable PostgreSQL URL. To
run registration, login, goal/milestone/action transitions, history, and
cross-user isolation against a separate local database:

```powershell
cd server
docker compose exec postgres createdb -U postgres set_a_goal_test
$env:DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/set_a_goal_test?schema=public"
$env:TEST_DATABASE_URL = $env:DATABASE_URL
npm run db:deploy
npm test
Remove-Item Env:DATABASE_URL, Env:TEST_DATABASE_URL
```

If the database already exists, the one-time `createdb` command can be skipped.
Do not point `TEST_DATABASE_URL` at production.

## Build the app

Build a release APK against the deployed HTTPS API:

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

The APK is written to `app/build/app/outputs/flutter-apk/app-release.apk`.
Configure the final Android application ID, release keystore/signing, and store
metadata before distribution. For Google Play, build an app bundle with the
same API definition:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Web and iOS release equivalents are `flutter build web --release` and, on
macOS, `flutter build ipa --release`, each with the production
`--dart-define=API_BASE_URL=...`.

## Deploy

### API and PostgreSQL

1. Provision managed PostgreSQL with backups and obtain its TLS connection URL.
2. Set `NODE_ENV=production`, `DATABASE_URL`, a new `JWT_SECRET`, final issuer
   and audience, and exact web origins in `CORS_ORIGINS`.
3. Build with `npm ci && npm run build`, or build `server/Dockerfile`.
4. Run `npm run db:deploy` as a release/pre-deploy step.
5. Start with `npm start`; configure the platform health check to `/health`.
6. Run `npm run db:seed` only in an isolated demo environment.

Railway, Render, Fly.io, and other container hosts can run this layout without
code changes. Keep migration execution separate from horizontally scaled app
startup so only one release job applies a migration.

### Client

Build each artifact with the final HTTPS `API_BASE_URL`. Add the deployed web
origin to `CORS_ORIGINS`; Android/iOS requests do not need a browser CORS entry.
Complete platform signing, bundle identifiers, privacy disclosures, and store
release configuration before submission. Host `build/web/` on a static HTTPS
host if shipping the web target.

### Production credentials and operations

- **Password-reset email:** configure `APP_URL`, `RESEND_API_KEY`, and
  `RESET_FROM_EMAIL`. Production startup rejects missing email configuration.
- **Push delivery:** configure `FIREBASE_SERVICE_ACCOUNT_JSON` on the API and
  supply the Firebase Dart defines documented in `app/README.md` when building
  the client. Device registration, quiet hours, queuing, delivery, and invalid
  token retirement are implemented.
- **Scheduling:** the bundled five-minute maintenance worker creates recurring
  routine actions, marks overdue work missed, queues reminders and weekly
  prompts, and dispatches due push records. Run one scheduler instance when the
  API is horizontally scaled, or invoke `runMaintenance` from a dedicated job.
- **Operations:** connect structured logs/request IDs to monitoring and error
  reporting, define analytics retention/deletion, and add alerting for failed
  health checks, jobs, and migrations.
