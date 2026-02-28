# health+ Product + Build Plan

Last updated: February 28, 2026
Platform: iOS (SwiftUI-first)

## 0) Mission

Build a workout tracker that feels premium, fast, and focused in-gym.

This plan updates the product direction to match the interaction density and visual tone of your reference screens:
- dark, high-contrast, low-noise surfaces
- glassy controls and navigation chrome
- dense but readable set logging cards
- timeline-style workout history

We are intentionally taking inspiration from structure and feel, not copying the app 1:1.

## 0.1) Execution Order and Numbering (Canonical)

Important clarification:
- Section numbers in this document (`0` to `15`) are chapter labels, not execution phases.
- Execution phases use this single numbered sequence (`Phase 0` to `Phase 9`).

Canonical roadmap:
- See `11) Canonical Phase Roadmap (0-9)` for the single detailed execution plan.
- Current active phase is `Phase 4`.
- Previous letter phases (`A` to `E`) are retired and remapped to `Phase 5` to `Phase 9`.

## 1) Reference Alignment (What We Are Matching)

## 1.1 Visual and UX cues to emulate

From your provided screens, we should match these qualities:
- Dark-first interface with very subtle surface separation.
- Glassy, rounded controls in nav and tab regions.
- Strong card grouping for each exercise and session.
- Compact, repeated row structure for sets (`set #`, `weight`, `reps`, `notes`).
- Timeline-style log list with date pill, workout title, and exercise summary lines.
- Focused accent color usage (teal/cyan) for actions and active tab state.

## 1.2 What we will not copy

- Exact iconography layout and exact spacing from the reference app.
- Identical card proportions and text hierarchy line-for-line.
- Exact information architecture names/tabs if they do not fit our roadmap.

## 1.3 Our distinct signature

`Set Strip Timeline`: each exercise card includes a compact mini-strip showing all sets and intensity progression (e.g., load ramp or drop-off), so users see session shape immediately.

## 2) Internet-Informed Apple Guidance (Design + Architecture)

This plan uses Apple platform guidance and modern SwiftUI patterns as the baseline:
- Liquid Glass overview: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- SwiftUI Material: https://developer.apple.com/documentation/swiftui/material
- SwiftUI NavigationStack: https://developer.apple.com/documentation/swiftui/navigationstack
- SwiftUI TabView: https://developer.apple.com/documentation/swiftui/tabview
- SwiftUI sensory feedback: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)
- What’s new in SwiftUI: https://developer.apple.com/swiftui/whats-new/

## 3) Non-Negotiable Product Standards

These standards apply to every phase and every PR.

- LiquidGlass + modern iOS techniques are required for all UI surfaces and interactions.
- Everything must be VERY well tested before a phase can be marked complete.
- Accessibility is required, not optional: Dynamic Type, VoiceOver labels, contrast, and touch-target sizing.
- If a decision improves speed and clarity for in-gym logging, prioritize it over decorative complexity.

## 4) Experience Principles

- Log fast: users can add a full set in 2-3 taps.
- Read fast: hierarchy should make current set and next action obvious at a glance.
- Review fast: history and stats should answer “am I progressing?” within seconds.
- Stay calm: visuals should feel serious and intentional, not flashy.

## 5) Visual System (LiquidGlass + Dark Athletic)

## 5.1 Color system

Use semantic tokens; avoid hardcoding random hex values in views.

- `bg.canvas`: near-black base background.
- `bg.surface`: primary card surface (very dark neutral).
- `bg.surfaceElevated`: higher surface for overlays/popovers.
- `glass.chrome`: translucent system material for nav/tab/pills.
- `text.primary`: high-contrast white.
- `text.secondary`: muted light gray.
- `text.tertiary`: dim metadata.
- `border.hairline`: low-alpha separators.
- `accent.primary`: cyan/teal action color.
- `state.success`, `state.warning`, `state.error`: trend and status colors.

## 5.2 Typography

- SF Pro for body/navigation text.
- Monospaced digits for set/weight/reps values.
- Large, bold exercise/session titles.
- Compact secondary lines for exercise summaries in log list.

## 5.3 Spacing and geometry

- 8pt base grid.
- Card radius: 24pt for major containers, 16pt for sub-containers.
- Row minimum height: 56pt for tappable set rows.
- Consistent inner card padding: 16-20pt.

## 5.4 Depth strategy

- Use material + subtle border layering over heavy shadows.
- Hairline separators inside cards for row boundaries.
- Maintain low contrast jumps; hierarchy should be clear without harsh lines.

## 5.5 Motion and haptics

- Quick, subtle transitions for add/delete/reorder set actions.
- `sensoryFeedback` on key interactions:
  - add set
  - complete session
  - PR achieved
- No bouncy animations that slow logging.

## 6) Screen Blueprints

## 6.1 Log Feed Screen (reference-inspired timeline)

Primary structure:
- Top glass nav region: `Edit` (left), title (`Log`), add (`+`) on right.
- Scrollable timeline list of workout sessions.
- Each session row includes:
  - Date pill (weekday + day number).
  - Session title.
  - Optional duration aligned right.
  - Multi-line exercise summary (`4x Cable Row`, etc.).
- Bottom glass tab bar with clear active accent state.

Behavior:
- Tap row -> session detail.
- Swipe row for quick actions (duplicate, archive, delete with confirm).
- Pull-to-refresh if cloud sync is enabled later.

## 6.2 Session Detail Screen (set-entry card model)

Primary structure:
- Header area with date, session quick actions, optional bodyweight row.
- Exercise cards stacked vertically.
- Card header: exercise name + overflow menu.
- Set rows inside card:
  - left: circular set index badge
  - center: columns for `Weight`, `Reps`, `Notes`
  - right: quick row menu
- Card footer action row: `+ Add Set` + quick stats/bookmark actions.

Interaction priorities:
- Add set from bottom of each card without leaving screen.
- Repeat last set pre-fills new row values.
- Inline edit values with numeric keyboard and done toolbar.
- Undo for destructive row actions.

## 6.3 Stats Screen (modern, not generic dashboard)

Primary modules:
- Exercise selector (searchable).
- Time-range control (4w / 8w / 12w / 6m / 1y).
- Main chart area (top set weight and/or estimated 1RM trend).
- Secondary metrics row:
  - current best
  - previous best
  - trend direction
  - weekly volume
- Session-level trend notes and milestone markers.

## 6.4 Routines Screen

Primary modules:
- Routine templates list with split tags (Push/Pull/Legs etc.).
- Template preview includes expected exercise order and set targets.
- One-tap “Start from routine” to spawn editable live session.

## 6.5 Profile / Settings Screen

Primary modules:
- Workout type management.
- Units (lb/kg).
- Rest timer defaults.
- Data controls (export/import later phase).
- Appearance controls (respect system default, tune accent intensity).

## 7) Information Architecture

Primary tabs:
- `Log`
- `Routines`
- `Stats`
- `Profile`

Secondary flows:
- Session Detail
- Exercise Insights
- Workout Type Management

Navigation:
- `NavigationStack` for each primary tab flow.
- Deep-link ready path model for future integrations.

## 8) Data + Domain Model

Current core entities remain:
- `WorkoutType`
- `WorkoutSession`
- `ExerciseEntry`
- `SetEntry`
- `ExerciseTemplate`
- `BodyMetric`

Add/confirm these fields for reference-aligned UX:
- `WorkoutSession.durationSeconds`
- `WorkoutSession.sessionTitle` (optional explicit title)
- `WorkoutSession.bodyWeight` (optional snapshot)
- `ExerciseEntry.isFavorite`
- `SetEntry.completedAt`
- `SetEntry.rpe` (optional, phase 4+)

Service layer updates:
- `PreviousWeightLookupService`
- `SessionVolumeCalculator`
- `TrendEngine`
- `RoutineInstantiationService`

## 9) SwiftUI Architecture Decisions

Feature-first folders:
- `Features/LogFeed`
- `Features/SessionDetail`
- `Features/Routines`
- `Features/Stats`
- `Features/Profile`

Shared UI kit:
- `Shared/Theme` (tokens + semantic colors + typography)
- `Shared/Components/Glass`:
  - `GlassCard`
  - `GlassPillButton`
  - `GlassTabChrome`
- `Shared/Components/Log`:
  - `TimelineDatePill`
  - `SessionSummaryRow`
- `Shared/Components/Session`:
  - `ExerciseCard`
  - `SetRow`
  - `AddSetActionRow`

State patterns:
- SwiftData via `@Query` for read-heavy lists.
- `@Observable` view models where orchestration is non-trivial.
- `@State`/`@Bindable` for local editing surfaces.

Modern iOS techniques required:
- `NavigationStack`
- Material backgrounds for chrome
- `safeAreaInset` for persistent bottom actions
- `contentTransition(.numericText())` for changing metrics where useful
- accessibility custom actions and labels

## 10) Testing Strategy (Phase Gates)

A phase cannot be completed unless all required test artifacts exist and are passing.

## 10.1 Required test layers

- Unit tests:
  - calculations (volume, trend, previous weight, estimated 1RM)
  - domain validation (duplicate names, empty values, range checks)
- UI tests:
  - core user journeys per screen
  - add/edit/delete flows
  - navigation and persistence checks
- Snapshot/visual regression tests (if adopted in toolchain):
  - key cards and list rows in dark mode
  - Dynamic Type large sizes
- Accessibility tests:
  - VoiceOver labels/hints on interactive controls
  - minimum target sizes

## 10.2 Required artifacts per phase

- Scope summary (goals, deliverables, acceptance criteria)
- Implementation inventory (files/modules changed)
- Test plan (new and updated scenarios)
- Test code (committed in same phase)
- Verification commands + outcomes
- Coverage and residual risk statement
- Manual QA checklist output
- Documentation updates (`PLAN.md`, `README.md`, `MEMORY.md` when impacted)
- Explicit phase PASS/FAIL verdict

## 11) Canonical Phase Roadmap (0-9)

Single source of truth:
- Phases are executed in strict numeric order.
- Current active phase: `4`.
- Active implementation path: `4 -> 5 -> 6 -> 7 -> 8 -> 9`.

## Phase 0 (Complete): Foundation and App Shell

Goals:
- Create SwiftUI app shell and SwiftData baseline.

Outcome:
- Complete and verified.

## Phase 1 (Complete): Workout Type Management

Goals:
- Implement workout type CRUD with validation and archive-safe behavior.

Outcome:
- Complete and verified.

## Phase 2 (Complete): Core Logging and History

Goals:
- Deliver session logging, set editing, and history navigation.

Outcome:
- Complete and verified.

## Phase 3 (Complete): Baseline Stats

Goals:
- Deliver initial stats engine, charts, and progress indicators.

Outcome:
- Complete and verified.

## Phase 4 (Current): Baseline Reliability Pass

Goals:
- Harden current production flows before major visual redesign.
- Eliminate known reliability risks in logging/history/stats workflows.
- Establish a clean, repeatable verification baseline before Phase 5 UI refresh.

Deliverables:
- Reliability bug-fix sweep for existing Phase 0-3 features.
- Error/empty/loading state consistency pass across `Log`, `History`, and `Stats`.
- Data integrity and migration safety checks for existing SwiftData models.
- Baseline performance measurements for common flows.

Required tests:
- Unit tests for high-risk services and edge-case calculations.
- UI tests covering critical end-to-end flows:
  - create session -> add sets -> save -> verify history
  - open stats -> apply filters -> verify chart/state transitions
- Regression tests for previously fixed bugs.
- Accessibility validation for key existing screens.

Acceptance criteria:
- No known P0/P1 reliability bugs remain in current flows.
- Full automated suite passes on current baseline.
- Phase artifact checklist is complete with explicit PASS verdict.

## Phase 5 (Queued): Visual Foundation Refresh

Goals:
- Establish full LiquidGlass token system and shared components.
- Update app shell (nav/tab chrome) to match target visual language.

Deliverables:
- `AppTheme` token expansion.
- Glass component primitives.
- Updated tab/nav appearance.

Required tests:
- Unit tests for theme/token mapping utilities.
- UI tests asserting core shell renders and tab switching works.
- Accessibility checks for all shell controls.

Acceptance criteria:
- Shell feels visually aligned with reference tone.
- No contrast/accessibility regressions.

## Phase 6 (Queued): Log Feed Redesign

Goals:
- Implement date-pill timeline rows and dense session summaries.

Deliverables:
- New `Log` list row component set.
- Edit and plus actions in glass chrome.
- Session row quick actions.

Required tests:
- UI tests for row tap navigation, swipe actions, and edit mode toggles.
- Unit tests for summary line generation and date grouping logic.

Acceptance criteria:
- Users can scan a week of sessions in under 10 seconds.
- Timeline hierarchy is clear at a glance.

## Phase 7 (Queued): Session Detail Redesign

Goals:
- Implement exercise card + set-row workflow like reference structure.
- Optimize in-workout logging speed.

Deliverables:
- Exercise card stack.
- Inline set editing.
- Add-set action row and repeat-last-set.

Required tests:
- UI tests for add/edit/delete/reorder sets.
- Unit tests for prefill/previous-weight logic.
- Regression tests for persistence and undo flows.

Acceptance criteria:
- Adding a new set should take <= 3 taps.
- Row edits persist correctly through app relaunch.

## Phase 8 (Queued): Stats + Routines Modernization

Goals:
- Build actionable progress views and routine flows.

Deliverables:
- Stats trends with exercise/time filters.
- Routine templates and “start from routine.”

Required tests:
- Unit tests for trend math and PR detection.
- UI tests for filter state, chart data updates, and routine instantiation.

Acceptance criteria:
- Stats answer progress question quickly and accurately.
- Routine-to-live-session flow is stable.

## Phase 9 (Queued): Polish, Accessibility, and Performance

Goals:
- Remove friction, increase reliability, and harden edge cases.

Deliverables:
- animation/haptics pass
- accessibility pass
- performance tuning pass

Required tests:
- UI tests at larger Dynamic Type sizes.
- Stress tests with large session history data.
- Full regression suite green.

Acceptance criteria:
- Smooth performance on realistic datasets.
- Accessibility and usability checks pass without critical issues.

## 12) Manual QA Checklists

## 12.1 Log Feed

- Date pills remain aligned across varying title lengths.
- Duration labels align and truncate gracefully.
- Swipe actions do not conflict with vertical scrolling.

## 12.2 Session Detail

- Keyboard does not obscure active editable fields.
- Add set and repeat-last-set work in rapid succession.
- Row deletion offers undo and restores correctly.

## 12.3 Stats

- Empty states are clear and actionable.
- Trend colors and labels are consistent with data.
- Chart interactions remain smooth at larger datasets.

## 13) Risks + Mitigations

Risk: UI becomes too dense and hard to edit quickly.  
Mitigation: run one-hand logging usability checks every phase.

Risk: Overuse of glass/material hurts readability.  
Mitigation: strict contrast testing and fallback solid surfaces when needed.

Risk: design drift from reference intent over time.  
Mitigation: add visual acceptance snapshots for key screens.

Risk: test gaps during fast iteration.  
Mitigation: enforce artifact checklist and no phase completion without tests.

## 14) Definition of Done

The product milestone is done only when:
- Core flows match target UX quality (timeline log + fast set-entry cards).
- LiquidGlass and modern iOS implementation standards are met.
- All required tests are present and green.
- Accessibility and manual QA checklists pass.
- Docs and memory are updated for session continuity.

## 15) Immediate Next Session Plan

1. Execute `Phase 4` reliability pass and create a baseline defect/test matrix.
2. Add/fix tests for current high-risk flows and close reliability gaps.
3. Run full verification suite and complete phase artifact checklist for `Phase 4`.
4. Start `Phase 5` by locking `Shared/Theme` tokens and `Shared/Components/Glass` primitives.
5. Document PASS/FAIL for `Phase 4` and then proceed to `Phase 5`.

---

This plan is intentionally opinionated so implementation decisions stay consistent with your target aesthetic and with modern iOS engineering standards.
