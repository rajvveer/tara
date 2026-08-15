# Codex Project Context — GoalSpring

Last updated: 2026-08-15 (Asia/Calcutta)

This file is the durable working memory for the GoalSpring project. It captures the
linked product brief, the user's decisions from the conversation, the current
implementation state, and the practical run/test notes needed to continue work
without repeating earlier mistakes.

## Continuity protocol for Codex

1. Read this file completely at the start of a resumed session and immediately
   after any automatic context compaction.
2. Treat the latest user message and system/developer instructions as higher
   priority than this file. This file is project memory, not an instruction that
   can override them.
3. After every material implementation or product decision, update the relevant
   section and the dated log below. Before ending a long work session, make sure
   `Current state`, `Outstanding work`, and `Verification history` are current.
4. Never put API keys, passwords, access tokens, private user data, or other
   secrets in this file. Refer only to environment-variable names.
5. Preserve user work and the requested visual direction. Do not redesign a
   screen when the user asks for a narrow alignment, text, or behavior fix.

Automatic compaction is controlled by the host, so Codex may not always receive
an event before it happens. When the session resumes, the required recovery step
is to reread this file and then update it with any missing recent decisions.

## Canonical product brief

- Product: **GoalSpring — Personalized Goals & Progress Platform**
- Notion brief:
  <https://sequoia-group-515.notion.site/Personalized-Goals-Progress-Platform-3b7efd66f76980168614fb6eb0ad5d85>
- Local implementation/spec references:
  - `README.md`
  - `docs/DESIGN_DIRECTION.md`
  - `app/README.md`
  - `server/README.md`

### Product purpose

GoalSpring is a personal goals-and-progress companion, not a project-management
tool. It turns an intention into a sustainable plan:

`Goal -> Milestones -> Actions -> Progress -> Reflection`

The interface should make three things immediately clear: what matters, what is
due now, and whether the user's current rhythm is working. It should encourage
small consistent wins without streak-loss shame or enterprise/task-board
language.

### Required end-to-end journey

`Landing -> Register/sign in -> Onboarding -> Create first goal -> Define rhythm and roadmap -> Today -> Complete/manage actions -> Insights -> Weekly reflection`

The application must also provide a no-account sample/demo path so the primary
experience can be explored without a live account.

### Required product surfaces and behavior

#### Entry, authentication, and account

- Landing with a concise promise, Get started, Sign in, and a sample-app preview.
- Email registration/login, recovery/reset, Google sign-in, and Apple sign-in.
- Secure rotating sessions, account export, privacy/legal links, and guarded
  permanent account deletion.
- Profile/preferences for appearance, accessibility, notifications, data,
  support, and account actions.

#### Onboarding and goal creation

- Guided onboarding that gathers enough information to create a useful first
  goal and working rhythm.
- Manual onboarding remains available.
- Goal creation uses five focused, scroll-safe steps:
  **Direction -> Finish line -> Meaning -> Schedule -> Plan**.
- Capture category, title/outcome, motivation, dates, frequency/cadence,
  preferred days/time, milestones, and concrete actions.
- Templates may accelerate entry but must remain editable and functional.

#### Today

- Today-first home surface with profile/date, compact week strip, weekly
  progress, Goals/Actions mode, and time-grouped action rows.
- Full action lifecycle: start, complete, skip, miss, reopen, edit, and delete as
  appropriate.
- The next useful action should be easier to find than secondary totals.

#### Goals and goal detail

- Goals list with Active, Paused, and Complete filtering.
- Category-colored rows with readable full titles and compact progress.
- Goal detail with category identity, progress/status summaries, schedule,
  milestones, actions, and a clear next action.
- Goal progress is not percentage-only. It must account for completion,
  timeframe/cadence expectation, and adherence to work that was already due.
- Supported status outcomes: `AHEAD`, `ON_TRACK`, `NEEDS_ATTENTION`, `BEHIND`,
  and `COMPLETED`.

#### Schedule, insights, and reflection

- Schedule/calendar views for planned actions and recurring routines.
- Insights with Progress/All goals modes, weekly summaries, completion calendar,
  a restrained trend view, per-goal progress, and weekly reflection.
- Missed/skipped work remains honest and visible; future actions do not reduce
  current adherence.

#### Notifications, offline behavior, and data

- Reminder preferences, quiet hours, unread state, device registration, and
  scheduled reminder/weekly-summary/reflection notifications.
- Cached reads during poor connectivity and queued authenticated writes replayed
  with stable IDs when connectivity returns.
- PostgreSQL is authoritative. The Flutter client never talks directly to the
  database.
- User-owned data must always be scoped by authenticated user ID.
- Planning history should remain recoverable through progress records and soft
  deletion where designed.

### Visual and accessibility requirements

- The UI direction is bright, compact, calm, and encouraging in light and dark
  themes, using Work Sans and an original Onward identity.
- The authenticated app follows the user-supplied Anova Figma screen
  composition: pale blue canvas, crisp white bordered cards, blue selected
  capsules, circular gauges, fixed 2x2 signal modules, grouped profile rows,
  and a five-item Home / Activity / Tara / Progress / Profile dock with Tara
  raised in the center. Landing,
  signup, get-started, and onboarding retain their approved existing design.
- Useful reference patterns include compact calendars, circular progress rings,
  white metric cards, segmented modes, and a raised selected navigation control.
- Use borders, spacing, and tonal elevation for hierarchy. In dark mode, do not
  place bright glow halos behind cards.
- Important titles wrap rather than being clipped. Status is never communicated
  by color alone.
- Minimum practical touch target is 48 dp; provider buttons remain equal and
  prominent.
- Layouts must remain usable at 360x800 and 320x700, including 200% text.
- Avoid generic dashboard walls, copied reference artwork, vanity metrics,
  excessive decoration, and shame-based streak behavior.

## User-directed additions beyond the original product brief

### AI voice onboarding

- Add a second onboarding choice after character selection: manual onboarding
  or AI voice onboarding.
- The AI asks onboarding questions one at a time, understands the answers,
  prepares a reviewable goal draft, and lets the existing onboarding flow save
  the goal.
- Language handling is automatic. There must be no language selector. If the
  user speaks Hindi, the assistant should understand and answer naturally in
  Hindi; the same principle applies to other supported languages and code-mixing.
- Reply language is resolved from the transcription's Unicode script before
  trusting Sarvam's sometimes-wrong per-turn language label. Latin transcripts
  reply in English; Devanagari replies in Hindi (or Marathi when Sarvam agrees);
  Bengali, Punjabi, Gujarati, Odia, Tamil, Telugu, Kannada, and Malayalam scripts
  map to their matching TTS language. This prevents random English-to-Hindi or
  Hindi-to-Bengali jumps while retaining automatic language switching.
- The server also validates the generated reply's Unicode script before sending
  text or TTS audio. Stored answers are explicitly forbidden from influencing
  the current reply language. If GPT returns the wrong script anyway, one
  constrained Groq correction rewrites only the reply while preserving the
  extracted answers, meaning, names, numbers, tone, and single question.
- Use **Groq GPT-OSS 120B** for reasoning/conversation/goal extraction.
- Use **Sarvam only for speech-to-text and text-to-speech**, not as the reasoning
  model. The current implementation documents Saaras v3 STT and Bulbul v3 TTS.
- Bulbul v3 no longer uses `ritu` for every language. TTS selects Sarvam's
  production-recommended female speaker per language (`ishita` for English,
  `priya` for Hindi/Telugu/Marathi/Gujarati, `roopa` for Bengali/Punjabi,
  `pooja` for Odia/Malayalam, and `ishita` for Kannada/Tamil) at natural 1.0
  pace and warm companion-style 0.75 temperature.
- Voice credentials must stay server-side in `server/.env` using
  `GROQ_API_KEY` and `SARVAM_API_KEY`.
- The voice experience needs clear recording/processing/speaking states and a
  polished voice animation.
- The selected guide is an original human illustration, not a marketplace
  mascot. Its transparent source asset is
  `app/assets/illustrations/onward-human-guide.png`.
- `app/lib/ui/auth_onboarding.dart` rigs the guide with Flutter-native motion:
  subtle breathing, timed blinking, listening eyebrows, a thinking pose,
  completion smile, and changing mouth shapes while TTS audio is playing. The
  open mouth uses a warm lip edge, soft dark interior, upper teeth, and tongue;
  do not regress it to a solid black oval.
- The guide's face now uses almond-shaped eyelids, warm irises and catchlights,
  a softer nose line, expression-aware brows, optional cheek warmth, and
  separate upper/lower lip contours. Speaking poses use a shaped mouth path
  rather than an oval, with teeth and tongue shown only for appropriate cues.
- Her body/head pose uses restrained whole-guide motion around a bottom-center
  pivot so the shoulders stay settled while the head moves subtly left/right,
  up/down, and through an occasional nod. Speaking rotation is capped at about
  0.35 degrees; listening/thinking poses are deliberate rather than wobbly.
- Lip motion follows playback position and multilingual mouth cues (closed,
  small, open, wide, round, and teeth). Compatibility WAV replies also use the
  measured amplitude envelope; live MP3 replies use the synchronized typewriter
  position as their cue timeline. Eased poses prevent rapid mouth chatter.
- The focused voice screen shows one plain state label, the current assistant
  question, the latest transcript, and a final `Review my plan` action. It does
  not show a language selector or a manual microphone/replay button.
- Voice onboarding now uses the authenticated `WS /api/v1/realtime` channel
  end to end. The server opens Sarvam's streaming TTS WebSocket and forwards
  progressive MP3 chunks as `voice.audio_start`, `voice.audio_chunk`, and
  `voice.audio_end`; it no longer sends reply text several seconds before the
  sound. Flutter plays the incomplete stream with `just_audio` and starts a
  grapheme-safe typewriter only when playback actually enters the ready/playing
  state. The older REST voice endpoints remain a compatibility fallback.
- The conversation is hands-free: after the guide finishes speaking the client
  starts listening automatically, detects speech energy in the 16 kHz PCM
  stream, and submits after roughly 1.25 seconds of natural silence. No-speech
  timeouts retry listening automatically; turns remain capped at 25 seconds.
- The guide now greets the signed-in user by the account/Google first name and
  never asks for a name during voice setup. Its prompt is warmer, more
  conversational, lightly funny when natural, and still asks one clear question
  at a time in the user's detected language.
- AI voice onboarding skips the redundant preferences form after the
  conversation and moves directly to review, so it has four visible steps.
  Manual onboarding keeps a fifth preferences step for time, progress detail,
  and optional scheduling constraints. Neither path collects a raw profile-photo
  URL or asks the user to re-enter their name; the existing account identity and
  provider photo are preserved.
- `app/lib/data/realtime.dart` is the shared authenticated cross-platform socket
  transport used by both voice onboarding and the in-app Coach. Server input is
  validated and rate/payload limited; access tokens are sent in the first socket
  frame instead of the URL.
- Rive marketplace options were evaluated in Chrome but rejected because the
  available human characters did not fit Onward's visual identity. The Rive
  dependency and downloaded marketplace assets were removed; the final guide
  uses no new runtime dependency or third-party character license.
- Rive's editor was reopened and signed in on 2026-08-14. A private draft file
  was created with the existing blank-face guide aligned on a 260x228 artboard,
  but the beta Agent did not generate a usable face/state rig, so no `.riv` was
  exported and no runtime dependency was added. Keep the tested Flutter-native
  rig unless a real authored `.riv` with the required controls exists.

### Personalized AI chatbot

- The main shell now includes a fifth `Coach` tab. It streams Groq GPT-OSS 120B
  replies token by token over the same authenticated WebSocket as voice setup.
- The server supplies the signed-in user's active/paused goals, preferences,
  milestones, and upcoming actions; this private context never comes from the
  client prompt. Replies automatically match the latest message's language,
  including natural Hinglish, and are constrained to concise plain text.
- Chat history is session-only on the client and survives switching tabs, but is
  not saved to the database. The Coach is read-only: it may recommend an exact
  change but must not claim to have edited goals/actions without user
  confirmation.
- Demo mode shows a sign-in notice instead of attempting an unauthenticated
  socket connection. No new app dependency or chat-storage schema was added.

## Conversation decisions and visual corrections

These decisions are explicit and should not be undone without a new user request:

- Insights: restore the original card layout; only fix the misaligned text.
- Goal detail: apply the same progress-summary text alignment fix.
- Dark theme: remove glow effects behind cards across the whole app, including
  goal detail. Prefer tonal elevation and subtle borders/shadows.
- Landing: use the generated goal-journey artwork as a large/full hero with copy
  and the main CTA over the image.
- Landing: remove the two top image badges (`4 of 6 this week` and
  `4 day streak`).
- Landing buttons: Get started and Sign in use a refined liquid-glass treatment
  implemented with Flutter-native blur/translucency; avoid a dependency for a
  single button effect.
- Onboarding progress: the compact progress bar belongs at the top-right below
  the `1 of 5` text, not as a full-width bar across the page.
- Onboarding setup-mode screen: the AI card uses the same human guide
  illustration as the live voice screen on a warm translucent garden-matched
  surface with one CTA; manual setup is a compact secondary row. The former
  setup heading/subtitle, waveform orb, explanatory voice subtext, nested glass
  panels, and separate language footnote are removed.
- Character changes must be instantaneous and stable; do not cross-fade old and
  new characters or show a video-like reload/ghost frame.
- Character customization has exactly three tabs: **Head**, **Top**, and
  **Bottom**. Do not add a `Looks` tab or full-character carousel.
- Head, top, and bottom are independently mixable. Each tab currently has the
  original three choices plus seven new choices, for ten per category.
- User prefers direct implementation and visual device/emulator testing, with
  minimal discussion for small fixes and no unnecessary selectors,
  abstractions, or packages.

## Current architecture

```text
Flutter app (Android / iOS / web)
  -> HTTPS/JSON + bearer access token
Express 5 + TypeScript + Zod
  -> Prisma
PostgreSQL 17
```

- `app/`: Flutter UI, domain models, API client, secure-token storage, cache,
  offline queue, and Firebase messaging integration.
- `server/src/`: REST API, validation, auth, user scoping, AI voice integration,
  progress logic, jobs, and OpenAPI document.
- `server/prisma/`: schema, migrations, and demo seed.
- `server/tests/`: logic and API journey tests.

The REST base is `/api/v1`; local API default is port `4000`. Health is exposed
at `/health`, Swagger at `/api/docs`, and OpenAPI JSON at
`/api/openapi.json`.

## Current implementation state

### Main app/product

- Auth, onboarding, goal creation/editing, goals, milestones, actions, routines,
  Today, schedule, Insights, reflections, notifications, preferences, sample
  space, account export/deletion, offline reads/writes, and API wiring exist.
- Progress calculation uses completion, expected progress, and due-action
  adherence. Future work does not harm current adherence.
- Voice onboarding endpoints exist at:
  - `WS /api/v1/realtime` (the active Flutter transport)
  - `POST /api/v1/voice/onboarding/start`
  - `POST /api/v1/voice/onboarding/turn`
- The server uses Sarvam for speech and Groq GPT-OSS 120B for the structured
  multilingual onboarding conversation.
- The AI voice path now has the original animated human guide and a simplified
  single-question conversation screen. The generic onboarding `Next` control is
  hidden while voice setup owns the interaction and review action.
- The main app has a responsive `Coach` tab with suggestion prompts, a multiline
  composer, accessible streamed chat bubbles, visible transport errors, and
  light/dark theme support. Provider Markdown is discouraged server-side and
  stripped client-side before the final bubble is shown.

### Character customizer

- `app/lib/ui/avatar.dart` provides the reusable layered `OnwardCharacter`.
- `OnwardCharacter` applies per-head visible-bound normalization so switching
  heads does not make the full figure appear shorter or larger.
- `app/lib/ui/auth_onboarding.dart` exposes only Head/Top/Bottom tabs and keeps
  the two unedited selections unchanged when one category changes.
- Ten head identities: the original three plus Amara, Arjun, Mei, Leo, Zoya,
  Noor, and Sam.
- Ten top choices: the original three plus coral, mustard, mint, tangerine,
  crimson, turquoise, and cream.
- Ten bottom choices: the original three plus forest, denim, charcoal, indigo,
  sand, burgundy, and cobalt.
- Reusable transparent layers live at
  `app/assets/avatars/character-layer-<head>-{base,top,bottom}.png`.
- `server/src/schemas.ts` accepts any valid independent combination of the
  allowed head/top/bottom values.

### Important source files

- `app/lib/ui/auth_onboarding.dart` — landing/auth/onboarding/voice flow and
  character picker.
- `app/lib/ui/coach_screen.dart` — personalized streaming Coach UI and
  session-only conversation state.
- `app/lib/ui/home_shell.dart` — five-tab app shell including Coach.
- `app/lib/data/realtime.dart` — authenticated reusable WebSocket client.
- `app/lib/ui/avatar.dart` — character-layer renderer and option maps.
- `app/test/widget_test.dart` — UI regressions including the three-tab character
  picker and mixed selections.
- `server/src/sarvam.ts` — Sarvam STT/TTS plus Groq-powered onboarding turns.
- `server/src/chat.ts` — scoped goal-context query and streaming Groq Coach.
- `server/src/realtime.ts` — authenticated realtime voice and Coach protocol.
- `server/src/routes.ts` — REST routes including voice onboarding.
- `server/src/schemas.ts` — API validation, including avatar combinations.
- `server/src/goal-progress.ts` — progress-status calculation.
- `server/tests/schemas.test.ts` — avatar/schema regression coverage.
- `server/tests/chat.test.ts` — personalized context, streaming, malformed
  provider data, and bounded-history regressions.

## Runbook

### API

From `server/`:

```powershell
npm ci
npm run db:deploy
npm run dev
```

Local API: `http://localhost:4000/api/v1`

### Android emulator

Known emulator ID: `emulator-5554`

```powershell
cd app
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

The app's development default already points to `10.0.2.2:4000/api/v1`.

### Physical Android phone over USB

Last known phone: moto g35 5G, ADB serial `ZA2237LH6L`.

```powershell
adb -s ZA2237LH6L reverse tcp:4000 tcp:4000
cd app
flutter run -d ZA2237LH6L --dart-define=API_BASE_URL=http://127.0.0.1:4000/api/v1
```

ADB reverse rules disappear after phone/USB reconnects and reboots, so rerun
the `adb reverse` command before diagnosing a phone-only connection error. A
physical phone cannot reach the computer through its own `localhost` unless the
USB reverse rule is active.

## Verification history

The following checks were reported passing after the latest character work:

- Full `flutter analyze` for the app.
- Character-picker widget regression test.
- `npx tsc -p tsconfig.json --noEmit` for the server.
- Server avatar/schema Vitest coverage.
- Android build/install and visual checks on the emulator.
- Visual character combinations checked with Arjun + coral + forest and
  Amara + blue + teal.

The following checks passed after the 2026-08-14 human voice-guide redesign:

- Full `flutter analyze` with no issues.
- Full Flutter test suite: 43 tests passed.
- Debug Android APK build and install on `emulator-5554`.
- Device-sized visual checks of idle and speaking states; the guide rendered
  transparently with no marketplace-artboard background.
- Live emulator flow: Sarvam TTS reply, microphone recording, Sarvam STT,
  Groq's next onboarding question, and the next Sarvam TTS reply.
- Funded Hindi smoke flow: `hi-IN` start and detection, non-empty transcript,
  reply audio, completed goal extraction, and populated schedule fields.
- WAV-envelope lip sync analysis and focused voice-onboarding widget coverage.
- Live replay on `emulator-5554` sampled across the spoken sentence: quiet
  frames closed the lips and voiced frames used smaller held wide/teeth/round
  poses instead of the former rapid repeated open-mouth motion.
- The refined face/head-motion pass passed full `flutter analyze`, all 43
  Flutter tests, debug APK build/install, and emulator captures of idle plus
  multiple real replay frames. The capture confirmed natural resting eyes,
  closed-lip pauses, shaped speaking lips, and no black-hole mouth regression.
- The realtime/hands-free pass passed full Flutter analysis and all 43 Flutter
  tests, full server Vitest (20 passed; integration suites skipped by their
  existing environment gate), direct TypeScript checking, a dedicated socket
  authentication/protocol test, and Sarvam progress-event tests. A debug APK was
  built/installed and the live emulator completed the authenticated socket,
  opening TTS playback, and automatic transition into listening without a tap.
- The friendlier/preloaded-name flow passed full Flutter analysis, all 43
  Flutter tests, direct TypeScript checking, and the focused Sarvam suite (4
  tests), including a regression that the personalized greeting does not ask
  for the user's name.
- The personalized Coach pass passed full Flutter analysis, all 44 Flutter
  tests, all 25 active server tests (19 environment-gated integration cases
  skipped), and direct TypeScript checking. The final debug APK was installed
  on the moto g35 5G. A live streamed reply correctly used Rajveer's new
  `Build consistent fitness` goal, Mon/Wed/Fri cadence, and evening preference.
  The smoke run completed that account's previously unfinished onboarding and
  created that goal. Raw Markdown discovered in the live reply was subsequently
  guarded in both the system prompt and final client rendering.

The repository README defines the broader release checks:

```powershell
cd app
flutter analyze
flutter test

cd ..\server
npm test
npm run typecheck
npm run build
```

Live voice verification consumes paid provider credits and should only be run
when explicitly appropriate:

```powershell
cd server
npx tsx scripts/voice-smoke.ts
```

## Security notes

- The user supplied provider credentials in the chat. They are intentionally
  omitted from this file and must never be copied into source or documentation.
- Keep `SARVAM_API_KEY` and `GROQ_API_KEY` only in an ignored server environment
  file or secret manager.
- Because credentials appeared in conversation text, rotate them before any
  production deployment.
- Release builds must use an HTTPS API URL. Local cleartext HTTP is for debug
  development only.

## Outstanding work / next priorities

1. Keep auditing any newly changed UI/API behavior against the canonical Notion
   scope and rerun proportionate tests after each change.
2. Confirm production integrations/credentials separately: deployed HTTPS API,
   OAuth configuration, password-reset email, Firebase push credentials,
   signing, and store metadata.
3. Consider confirmation-based Coach actions (for example, proposing an action
   and opening a prefilled confirmation sheet) only after the read-only Coach is
   approved; never allow silent mutations.
4. Keep live provider smoke tests deliberate because each run consumes Sarvam
   and Groq credits; the Hindi path has now been verified once successfully.

## Decision log

- **2026-08-15:** Completely replaced every authenticated screen with the
  user-supplied Anova Figma composition while preserving all Onward data and
  interaction logic. Removed neumorphic usage from signed-in screens; rebuilt
  Home with the greeting/week/paired quick cards/fixed 2x2 signals; rebuilt
  Activity and goal detail around selected capsules and large circular gauges;
  rebuilt Tara around the centered assistant and 2x2 prompts; rebuilt Progress
  around the account summary, score card, fixed detail grid, signal balance,
  trends, and reflection; and rebuilt Profile around grouped account rows.
  Navigation is now Home / Activity / Tara / Progress / Profile with Tara raised
  in the center. The mobile dock was then refined to the inset, fully rounded
  liquid-glass reference treatment with a genuine circular center notch and a
  separately docked Tara control hovering above the curve. A dedicated
  transparent Tara head-and-shoulders portrait derived from the onboarding
  guide replaces the robot and stays legible at navbar size. Goal creation,
  schedule, reflection, settings, sheets, and
  action rows use the same flat card system. Landing, signup, Get Started, and
  onboarding remain unchanged. `flutter analyze` and all 50 Flutter tests pass,
  including 320x700 at 200% text, and the final build was visually checked and
  left running on Android emulator `emulator-5554`.
  The Home week strip now uses one Actions progress ring per day, with the
  calendar date centered inside it instead of a percentage. This change is
  confined to the week strip and does not alter the four Today signal cards
  below it.
  Completed actions are assigned to their actual completion day rather than a
  stale due date.
  Weekly consistency now merges live action status with current-week completion
  records instead of dropping valid completions whenever unrelated history
  exists. The Home Reflection card opens the weekly check-in, current-week
  reflections drive its ring, and Progress detail tiles use the same live
  Goals/Actions/Consistency/Reflection metrics instead of placeholders. A full
  emulator walkthrough covered Home, schedule, goal creation entry, Activity,
  goal detail, Tara, Progress, Profile, edit profile, notifications, and a real
  reflection save; no runtime errors appeared. The Home Daily Insight teaser
  now opens a compact reference-style daily analytics dashboard: a live
  Planned/Started/Done chart, today's completion rate, completed effort, and a
  per-goal daily breakdown. Its accent color follows today's leading goal
  category. The dashboard follows current completed action status so a reopened
  action's retained history does not inflate the live total. A next-action CTA
  appears only when today still has unfinished work.
  Navigation, live totals, CTA behavior, scrolling, and 200% text accessibility
  are covered by the Flutter suite.
  Home and Activity notification bells now open a real notification inbox
  instead of the goal wizard. The inbox loads the API-backed due notification
  feed, shows an unread badge and All/Unread filters, supports pull-to-refresh,
  mark-one/mark-all read, opens notification preferences, and deep-links goal,
  progress, and reflection notifications. The backend hides future scheduled
  reminders until due and applies the same visibility rule to read operations.

- **2026-08-14:** Added this durable context file at the user's request. It
  consolidates the Notion product scope, conversation decisions, architecture,
  current implementation, verification history, device commands, security
  boundaries, and remaining work. Future Codex sessions must reread it after
  compaction and keep it current after material changes.
- **2026-08-14:** Normalized every character head illustration to the neutral
  character's visible frame, correcting the shorter-woman/larger-man size jump
  during head selection.
- **2026-08-14:** Rebuilt onboarding step 2 around one clear AI voice hero and a
  quiet manual fallback, removed the glass-on-glass wrapper, verified the
  device-sized Android render, and passed the two affected widget tests plus a
  focused Flutter analysis.
- **2026-08-14:** Replaced the rejected stock mascot direction with an original
  warm human Onward guide. Added Flutter-native breathing, blinking,
  listening/thinking expressions, completion smile, and TTS-driven mouth
  motion; removed the temporary Rive dependency/assets; verified the real
  English emulator turn and a funded Hindi end-to-end smoke flow.
- **2026-08-14:** Refined the human guide's speaking mouth with visible upper
  teeth, tongue, a warm lip edge, and softer interior so open-mouth frames do
  not look like a flat black hole.
- **2026-08-14:** Replaced the guide's rapid character-by-character mouth loop
  with audio-envelope-driven, playback-synchronized multilingual mouth cues.
  Added eased amplitude, slower held poses, punctuation/quiet closures, and
  smaller mouth geometry; visually replayed the real Sarvam question on the
  Android emulator. Rive remains optional pending user sign-in and an authored
  rig, rather than being added as an unused runtime dependency.
- **2026-08-14:** Refined the voice guide's facial structure and expression
  system with shaped eyelids/irises, softer brows/nose, and anatomically cleaner
  lip contours. Added capped side-to-side pose, vertical lift, and an occasional
  nod around a bottom-center pivot while preserving the approved lip timing.
  The signed-in Rive draft produced no usable exported rig, so the working
  Flutter-native implementation remains dependency-free and was verified on the
  emulator.
- **2026-08-14:** Replaced Flutter's request/response voice calls with one
  authenticated, reusable realtime WebSocket channel. Added progressive
  transcript/reply events and client-side silence detection for a hands-free
  speak/listen rhythm; removed the mic and replay controls so only the final
  review action remains. Removed the generic dot/pill and sparkle treatment,
  made the guide/question surfaces translucent over the garden, and upgraded
  the resting mouth from a single stroke to filled upper/lower lips.
- **2026-08-14:** Made the voice guide friendlier, more conversational, and
  lightly humorous; personalized its opening with the existing account name;
  removed name/photo-URL collection; and made AI voice setup jump directly from
  the completed conversation to review with accurate four-step progress.
- **2026-08-14:** Fixed random voice-language switching caused by unreliable
  Sarvam language labels. The server now prioritizes the transcript's actual
  Unicode script, with regressions for English mislabeled Hindi and Hindi
  mislabeled Bengali.
- **2026-08-14:** Replaced the single `ritu` TTS voice with Sarvam's
  language-specific production-recommended female voices and raised Bulbul v3
  expressiveness to 0.75 while retaining natural 1.0 pace.
- **2026-08-14:** Hardened automatic language handling after GPT continued
  replying in the language of stored goal answers. Added a strict current-turn
  language instruction, output-script validation, an automatic correction pass
  on mismatch, and Unicode Script-property detection so shared punctuation such
  as danda cannot misclassify Bengali as Hindi.
- **2026-08-14:** Removed the text-before-voice delay by replacing full-file TTS
  delivery with Sarvam WebSocket MP3 chunks forwarded over Onward's existing
  authenticated socket. Added progressive `just_audio` playback and a
  playback-triggered, grapheme-safe typewriter. A live provider smoke test saw
  the first chunk at about 629 ms versus 1.9 s for the complete clip; the real
  emulator showed partial text while speaking, then hands-free listening, with
  no player/network errors. Flutter analysis, 43 widget tests, TypeScript, 23
  active server tests, and the Android debug build all passed; the APK was
  installed on both the emulator and physical phone.
- **2026-08-14:** Fixed the physical-phone voice flow freezing at `Ready` after
  speech. Motorola's MP3 decoder stayed in `playing + buffering` instead of
  emitting the normal completed state and later requested the live source a
  second time. The source now replays buffered chunks safely to each request,
  and an end-of-stream position-stall fallback advances immediately when audio
  has drained. Removed the per-character `AnimatedSwitcher` crossfade that made
  typewriter text blurry. Verified on the actual Motorola phone: sharp partial
  text during speech, the full sentence at completion, automatic transition to
  `Listening — speak naturally`, and no Flutter/player error. Flutter analysis,
  all 43 tests, and the phone-targeted APK build passed.
- **2026-08-14:** Added the personalized in-app Coach as a fifth tab. It uses the
  existing authenticated WebSocket to stream GPT-OSS 120B text, scopes context
  to the signed-in user's plan, follows the user's latest language, retains only
  session history, and cannot silently mutate data. No new runtime dependency
  or chat-storage schema was added.
- **2026-08-15:** Renamed the user-facing product to GoalSpring across Flutter,
  Android, iOS, backend messaging, documentation, and tests. Replaced the old
  launcher artwork with a generated flat sprout-and-progress mark. Existing
  package IDs, secure-storage keys, Firebase identifiers, Calendar event keys,
  and JWT issuer/audience values remain unchanged to preserve compatibility.
