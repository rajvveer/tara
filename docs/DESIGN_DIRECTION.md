# GoalSpring design direction

GoalSpring is a personal goals-and-progress app. Its interface should make three
things obvious: what matters, what is due now, and whether the current rhythm is
working. The visual direction is bright, compact, and encouraging without
turning progress into pressure.

## Primary reference and originality boundary

The user-selected main-app reference is the supplied
[Anova Figma file](https://www.figma.com/design/Dyncw297WXEi0MTYC6pFMn/Anova--Copy-?node-id=6015-367&p=f).
GoalSpring's authenticated screens deliberately follow that file's screen
composition: a pale blue canvas, crisp white cards, thin cool borders, compact
2x2 metric modules, circular progress gauges, blue selected capsules, week and
calendar views, grouped profile rows, and a five-item white dock with the AI
coach raised in the center.

GoalSpring does **not** copy Anova's health-tracking data, logo, copy, or proprietary
artwork. GoalSpring's goal content, product logic, data model, actions, and existing
character artwork remain its own. The approved landing,
signup, get-started, and onboarding experience intentionally keeps its existing
visual system; this reference governs the authenticated product only.

Supporting implementation references are:

- [Work Sans on Google Fonts](https://fonts.google.com/specimen/Work+Sans) for
  the shipped type family.
- [Material 3 navigation bars](https://m3.material.io/components/navigation-bar/overview)
  for platform-familiar navigation behavior and semantics.
- [Google sign-in branding](https://developers.google.com/identity/branding-guidelines)
  and [Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
  for provider marks, labels, prominence, and control treatment.

## Product principles

1. **Today before totals.** The next useful action appears before secondary
   reporting.
2. **Progress is visible.** Week strips, completion circles, calendars, and
   small charts make movement legible at a glance.
3. **A rhythm, not a streak.** Weekly consistency survives one missed day;
   misses are planning information, not failure.
4. **One primary choice.** Each screen has a clear selected mode or dominant
   action.
5. **Color carries category, never meaning alone.** Labels, icons, values, and
   status copy remain present.
6. **Complexity arrives when needed.** Goal setup is guided rather than exposed
   as a long database form.

## Visual system

### Color

- Authenticated light canvas `#FDFCFB`, surface `#FFFFFF`, ink `#171B25`,
  readable muted text `#697386`, and borders `#DDE5F1`.
- Primary blue `#5F86F7` for selected controls, progress, and decisive actions.
- Supporting pastels: cream `#FEF0CD`, mint `#DDF2E2`, pink `#F9E2ED`, and
  lilac `#EDE6FA`.
- Category accents: aqua `#69C9D8`, green `#7DB36A`, rose `#EFA7C8`, purple
  `#C895EC`, yellow `#F3C653`, and orange `#ED934A`.
- Dark mode uses canvas `#1C1D22`, surface `#272932`, elevated surface
  `#30323D`, border `#3A3C47`, primary text `#F7F7FA`, and muted text
  `#C8CAD4`. Category surfaces blend their accent into the elevated surface at
  low opacity rather than becoming neon blocks.

### Type, spacing, and shape

- Work Sans throughout: 22dp page headings, 18dp section headings, 16dp row
  titles, 14dp body copy, and 12dp captions/labels.
- A 4/8-point spacing rhythm with 20dp page gutters and at least 48dp touch
  targets.
- 16dp row radii, 18–20dp cards, and 22–28dp hero surfaces.
- Thin borders and spacing establish hierarchy first. One soft cool shadow is
  reserved for elevated light-mode cards; dark mode uses tonal elevation.
- Motion communicates selection, completion, step changes, and progress only.

## Component language

- **Progress gauges:** circular rings inside white metric cards with one large
  value, a category icon, and short status copy.
- **Category cards:** a stable 2x2 signal grid plus full-width rows with a
  circular icon field, flexible title, metadata, and trailing progress.
- **Week/calendar patterns:** compact weekday labels, circular selected or
  completed dates, and readable numeric states.
- **Segmented controls:** two-way or small filter choices with a filled cobalt
  selection and quiet unselected surface.
- **Navigation:** five stable destinations with Home, Activity, Tara, Progress,
  and Profile. Tara occupies the always-raised center control; the selected
  regular destination uses a quiet blue state.
- **Forms:** one contained surface, 52dp provider controls, full-width fields,
  clear legal links, and a dominant primary action.

## Screen mapping

- **Landing:** original progress orb, one short promise, Get started, Sign in,
  and Preview. Tall-screen surplus is distributed between meaningful groups;
  it is not left as a blank tail.
- **Sign up / login:** colored intro card, equally prominent Google and Apple
  controls, email flow, recovery, legal summaries, and an account-mode switch.
- **Home:** profile/greeting header, week strip, paired insight/AI cards, a fixed
  2x2 signal grid, Goals/Actions plan switch, and the center-coach dock.
- **Activity:** Active/Paused/Complete capsule, large overall progress gauge,
  quick-create row, and goal activity rows.
- **Goal detail:** Activity header, large circular goal gauge, compact done/open
  metrics, schedule pattern, next action, milestones, and history.
- **Progress:** account summary, Overview/All goals capsule, wellness-style score
  card, fixed 2x2 details, signal balance, trends, and reflection.
- **Tara AI:** assistant hero, personalized greeting, 2x2 prompt chips, composer,
  and the existing streamed conversation flow.
- **Profile / Settings:** identity and useful totals followed by grouped account,
  wellness, notification, privacy, support, and data rows.
- **Goal creation:** four scroll-safe steps — Goal, Outcome, Rhythm, and First
  steps — with plan-prefilling templates and a persistent primary action.

## Accessibility and quality gates

- Layouts must remain usable at 360×800 and at 320×700 with 200% text.
- Titles wrap instead of ellipsizing important goal identity; metadata may
  truncate only when a complete accessible label remains available.
- Provider buttons are equal-width 52dp controls and precede email fields.
- Status badges and schedule headings reflow rather than collide at large text.
- The selected navigation puck visibly protrudes above the bar and remains
  tappable without covering first-viewport content.
- Light and dark system bars match the active theme; muted text remains readable
  over every category surface.

## Anti-slop checklist

- No beige/forest/serif wellness-template styling.
- No copied people, mascots, scenery, or reference-project assets.
- No decorative sparkle language, glowing blobs, glassmorphism, or ornamental
  3D art.
- No generic dashboard wall of identical cards, fake precision, vanity charts,
  or confetti on every tap.
- No streak-loss shame or enterprise vocabulary such as backlog, sprint,
  assignee, workspace, or ticket.
- No clipped titles, dead icon-only actions, color-only status, or controls
  hidden beneath system or bottom navigation.

## Behavioral basis

The experience turns intentions into specific when/where actions and makes
progress easy to monitor. These choices are consistent with research on
[implementation intentions](https://cancercontrol.cancer.gov/sites/default/files/2020-06/goal_intent_attain.pdf)
and a meta-analysis finding that more frequent
[goal-progress monitoring](https://eprints.whiterose.ac.uk/id/eprint/91437/)
improves goal attainment.
