# Workout Tracking App Plan (SwiftUI-First)

Date: February 27, 2026  
Project: `health+`  
Platform target: iOS first (SwiftUI + SwiftData), expand later to iPad/macOS if desired

## 1) Product Goal

Build a workout tracking app that is fast to log during training, structured enough to show progress, and simple enough to iterate with you session-by-session.

Core MVP outcomes:
- Organize workouts by type/muscle focus and allow custom additions.
- Log workouts with reps, sets, weight, and notes.
- Show meaningful statistics over time (graph, previous weight reference, progress indicators).
- Keep architecture clean so we can add advanced features without rework.

## 2) MVP Scope (Mapped to Your Requirements)

### 2.1 Workout Types (and add new)

Must-have:
- Pre-seeded starter types: `Back`, `Triceps`, `Biceps`, plus more common groups.
- Create custom workout types from UI.
- Edit and soft-delete types (prevent accidental data loss when historical logs exist).
- Optional color/icon per type for visual organization.

Data we store per type:
- `id`
- `name`
- `isSystemType` (seeded vs user-created)
- `isArchived`
- `createdAt`
- `sortOrder`
- `colorHex` (optional)
- `symbolName` (optional SF Symbol)

### 2.2 Track Individual Workouts

Must-have logging fields:
- Exercise name
- Sets
- Reps
- Weight
- Notes
- Timestamp
- Workout type association

Recommended structure:
- A workout session contains multiple exercise entries.
- Each exercise entry contains multiple set entries.
- Notes exist at both session and exercise-entry level.

Why this shape:
- It matches how people actually train.
- It enables cleaner statistics (per set, per exercise, per session, per type).

### 2.3 Statistics

Must-have metrics:
- Graph over time (weight, estimated strength, volume).
- Previous weight shown during logging (last set or last session reference).
- Progress indicators (up/down/flat trends).

MVP stat cards:
- Last workout date
- Best recorded weight
- 4-week trend
- Total weekly volume

### 2.4 Extra Recommendations (from me)

High-value additions right after MVP:
- Rest timer between sets.
- Quick duplicate of previous workout.
- PR markers (best set by weight/reps/estimated 1RM).
- Search + filter history by type/exercise/date.
- CSV export for backup/analysis.

## 3) Interface-Design Skill Outputs (Required Exploration)

This is the product-design direction before implementation.

### 3.1 Domain Concepts (fitness log world)

- Progressive overload
- Training split (muscle focus by day)
- Volume and intensity balance
- Form quality and fatigue notes
- Recovery windows between sessions
- Consistency streaks
- Performance plateaus and breakthroughs

### 3.2 Color World (grounded in gym/training context)

- Rubber floor charcoal
- Steel plate gray
- Chalk white
- Safety orange accents (plates/markers)
- Deep navy/graphite for calm data surfaces
- Signal colors for performance states (green up, amber flat, red down)

### 3.3 Signature Element

`Set Strip Timeline`: each exercise row shows a compact horizontal strip of logged sets (weight x reps), giving immediate "what happened in this exercise" context without opening detail screens.

Why it is unique/useful:
- It mirrors the set-by-set mental model of lifters.
- It surfaces performance shape (ramped sets, back-off sets, drop-offs) quickly.

### 3.4 Defaults to Avoid (and replacement)

Default to avoid: generic card grid dashboard with disconnected metrics.  
Replacement: timeline-first training log where metrics are anchored to recent sessions.

Default to avoid: single flat "workout form" page with long scrolling fields.  
Replacement: stepwise logging flow with quick set entry and "add another set" speed actions.

Default to avoid: random bright palette and decorative gradients.  
Replacement: restrained, athletic palette with semantic color only for state meaning.

## 4) Technical Architecture (SwiftUI + needed Apple frameworks)

## 4.1 Stack

- UI: SwiftUI
- Local persistence: SwiftData
- Charts: Swift Charts
- Concurrency: Swift Concurrency (`async/await`) where needed
- Testing: XCTest (unit + UI tests)
- Optional later: CloudKit sync via SwiftData (phase 2+)

## 4.2 App Architecture Pattern

Use a pragmatic feature-first MV pattern:
- `Features/WorkoutTypes`
- `Features/Logging`
- `Features/History`
- `Features/Stats`
- `Shared/Components`
- `Shared/Theme`
- `Core/Models`
- `Core/Services`
- `Core/Stats`

State approach:
- `@Query` for SwiftData-backed lists.
- `@State` and `@Bindable` for local editing.
- Small `@Observable` view models only where business logic is non-trivial.

Why this works:
- Minimal boilerplate.
- Easy for us to evolve while pairing.
- Clean enough for testability and refactors.

## 4.3 Data Model (SwiftData)

Main entities:

`WorkoutType`
- `id: UUID`
- `name: String`
- `isSystemType: Bool`
- `isArchived: Bool`
- `colorHex: String?`
- `symbolName: String?`
- `createdAt: Date`
- `sortOrder: Int`

`ExerciseTemplate`
- `id: UUID`
- `name: String`
- `defaultWorkoutType: WorkoutType?`
- `createdAt: Date`
- `isArchived: Bool`

`WorkoutSession`
- `id: UUID`
- `startedAt: Date`
- `endedAt: Date?`
- `workoutType: WorkoutType`
- `sessionNotes: String`
- `entries: [ExerciseEntry]`

`ExerciseEntry`
- `id: UUID`
- `session: WorkoutSession`
- `exerciseName: String`
- `orderIndex: Int`
- `entryNotes: String`
- `sets: [SetEntry]`

`SetEntry`
- `id: UUID`
- `exerciseEntry: ExerciseEntry`
- `setIndex: Int`
- `reps: Int`
- `weight: Double`
- `isWarmup: Bool`
- `setNotes: String`
- `loggedAt: Date`

`BodyMetric` (optional for phase 1, useful for later)
- `id: UUID`
- `date: Date`
- `bodyWeight: Double?`
- `bodyFatPercent: Double?`
- `notes: String`

## 4.4 Core Calculation Engine

Create pure, testable stat functions:
- `totalVolume = sum(weight * reps)` by scope (exercise/session/week)
- `previousWeight` resolver:
  - Priority 1: last set for same exercise
  - Priority 2: last session max for exercise
  - Fallback: nil
- `estimatedOneRepMax` (Epley): `weight * (1 + reps / 30)`
- Trend classifier over rolling windows:
  - Up if slope > threshold
  - Flat if within threshold band
  - Down if slope < negative threshold

## 5) Information Architecture and Screens

Recommended tab structure (MVP):
- `Log` (start workout / quick add sets)
- `History` (past sessions, filters)
- `Stats` (graphs + trends)
- `Settings` (manage workout types, units, defaults)

## 5.1 Log Tab

Primary jobs:
- Start session by selecting workout type.
- Add exercise entries quickly.
- Add/edit set rows with reps/weight/notes.
- Show previous performance inline during set entry.

UX details:
- Numeric keyboard for reps/weight.
- "Repeat last set" shortcut.
- Swipe-to-delete set with undo.
- Auto-increment set number.

## 5.2 History Tab

Primary jobs:
- Browse sessions by date.
- Filter by workout type/exercise.
- Open detailed session recap.

UX details:
- Group by week.
- Quick chips for filters.
- Session card shows total volume and exercise count.

## 5.3 Stats Tab

Primary jobs:
- Plot selected exercise performance over time.
- View progress trends and best lifts.
- Compare recent block vs previous block.

Charts in MVP:
- Line chart: top set weight over time.
- Bar chart: weekly volume.
- Optional area/line toggle for estimated 1RM.

## 5.4 Settings Tab

Primary jobs:
- Manage workout types.
- Unit preferences (lb/kg).
- Default rest timer.
- Data export/import hooks (if added in phase 2).

## 6) Build-Together Delivery Plan

This is sequenced for collaboration so you can review and adjust each layer.

## Phase 0: Foundation (Session 1)

Goals:
- Create SwiftUI app shell.
- Add SwiftData container.
- Implement theme tokens (colors, spacing, typography scale).
- Seed default workout types on first launch.

Deliverables:
- Running app with tab structure.
- Workout type list rendering seeded data.
- Basic data model committed.

Acceptance criteria:
- App boots cleanly with no runtime model errors.
- Seed logic is idempotent (no duplicate default types).

## Phase 1: Workout Type Management (Session 1-2)

Goals:
- CRUD for workout types.
- Archive instead of destructive delete when referenced by sessions.

Deliverables:
- Settings screen for types.
- Validation (no empty names, no duplicates ignoring case/whitespace).

Acceptance criteria:
- User can add/edit/archive types.
- Existing sessions remain intact after type archiving.

## Phase 2: Logging Flow (Session 2-4)

Goals:
- Start and save sessions.
- Add exercise entries and set rows.
- Capture reps/weight/notes.
- Show previous weight reference while logging.

Deliverables:
- Full logging screen.
- Session detail and edit.

Acceptance criteria:
- Complete session can be created in <30 seconds for a typical workout.
- Previous weight appears for matching exercise names.
- Data persists after app relaunch.

## Phase 3: Stats and Progress (Session 4-5)

Goals:
- Add stats engine and charts.
- Add progress indicators (up/down/flat).

Deliverables:
- Stats dashboard for selected exercise and date range.
- Graphs with empty/loading states.

Acceptance criteria:
- Charts render correctly for at least 3 months of sample data.
- Progress status updates as new sessions are added.

## Phase 4: Polish + Reliability (Session 5-6)

Goals:
- Improve UI speed and ergonomics.
- Add test coverage for calculations and key UI flows.
- Improve error handling and edge-case messaging.

Deliverables:
- Unit tests for stat functions.
- UI tests for core flows.
- Better empty states and validation copy.

Acceptance criteria:
- No critical crash in happy-path QA.
- Core tests pass in CI/local run.

## 7) Backlog (Detailed)

MVP must-do tickets:
- [ ] Define SwiftData models + relationships
- [ ] App launch seeding service for default workout types
- [ ] Workout type CRUD UI
- [ ] Start/stop workout session
- [ ] Add/remove exercise entry inside session
- [ ] Add/remove/edit set entries
- [ ] Notes at exercise and session levels
- [ ] History list and session detail
- [ ] Previous-weight lookup service
- [ ] Stats calculation engine
- [ ] Line + bar charts in Stats tab
- [ ] Trend badge logic (up/flat/down)
- [ ] Input validation + form UX polish
- [ ] Unit tests for stats + lookup logic
- [ ] UI tests for session logging flow

Post-MVP strong candidates:
- [ ] Rest timer and notifications
- [ ] Personal records tracker
- [ ] Favorite/recent exercise quick-add
- [ ] CSV export
- [ ] Cloud sync
- [ ] Apple Watch quick log

## 8) Quality Strategy

## 8.1 Unit Tests

Focus on deterministic logic:
- Volume calculations
- Trend calculations
- Previous-weight lookup
- 1RM estimator
- Type-name normalization and duplicate checks

## 8.2 UI Tests

Key flows:
- Create type -> start session -> log sets -> save -> verify history entry
- Edit set and verify stats update
- Archive type and verify old sessions still display correctly

## 8.3 Manual QA Checklist

- Rapid logging with one hand
- Large text accessibility
- Empty states on clean install
- Editing/deleting with undo safety
- Date and unit formatting correctness

## 9) Risks and Mitigations

Risk: Data model churn early can cause migration pain.  
Mitigation: Lock core model by end of phase 1, and avoid renaming entities after logs exist.

Risk: Logging flow becomes too form-heavy and slow in-gym use.  
Mitigation: prioritize speed shortcuts (repeat last set, numeric focus, minimal taps).

Risk: Trend stats can be misleading with sparse data.  
Mitigation: show confidence/insufficient-data states for low sample counts.

Risk: Duplicate exercise naming causes fragmented stats (`Bench`, `Bench Press`, `BB Bench`).  
Mitigation: add optional template pickers and alias normalization in phase 2.

## 10) Definition of Done for MVP

MVP is done when:
- User can manage workout types (including custom).
- User can complete and persist full workout logs (reps/sets/weight/notes).
- User can review history and visualize progress over time.
- Previous workout performance appears while logging.
- Core stat logic is tested and stable.

## 11) How We Build This Together (Collaboration Contract)

For each session:
1. Align on one phase goal.
2. Implement a vertical slice (UI + model + test).
3. Run quick QA checklist.
4. Commit small, reviewable changes.
5. Decide next slice.

Coding style:
- Keep components small.
- Prefer explicit naming over clever abstractions.
- Add tests for new math logic immediately.
- Avoid premature generic frameworks until repeated patterns appear.

## 12) Immediate Next Session Plan (Concrete)

If we start coding right now, first sequence should be:
1. Scaffold SwiftUI app shell with 4 tabs.
2. Add SwiftData models (`WorkoutType`, `WorkoutSession`, `ExerciseEntry`, `SetEntry`).
3. Seed default workout types on first launch.
4. Build Workout Type management screen.
5. Add first pass of logging screen with set rows (reps/weight/notes).

Expected output after this first build slice:
- You can create a workout type and log at least one exercise with multiple sets end-to-end.

---

This plan is intentionally detailed so we can execute it incrementally without re-architecting each step.
