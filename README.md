# health+

SwiftUI-first workout tracking for lifters who care about consistent progress.

[![Platform](https://img.shields.io/badge/platform-iOS-blue.svg)](https://developer.apple.com/ios/)
[![UI](https://img.shields.io/badge/UI-SwiftUI-0A84FF.svg)](https://developer.apple.com/xcode/swiftui/)
[![Persistence](https://img.shields.io/badge/data-SwiftData-34C759.svg)](https://developer.apple.com/documentation/swiftdata)
[![Charts](https://img.shields.io/badge/charts-Swift%20Charts-FF9F0A.svg)](https://developer.apple.com/documentation/charts)

## Why health+?

Most workout apps are either too simple to show real progress or too heavy to log quickly in the gym.  
`health+` is being built to solve both:

- Fast workout logging while training
- Structured history for long-term progress
- Clean, native iOS experience
- SwiftUI architecture that scales as features grow

## MVP Goals

### 1) Workout Types
- List workouts by type (Back, Triceps, Biceps, etc.)
- Add your own custom types
- Edit and archive types safely

### 2) Workout Tracking
- Log reps
- Log sets
- Log weight
- Add notes per workout and exercise

### 3) Statistics
- Graph performance over time
- Show previous weight while logging
- Track progress trends (up, flat, down)

### 4) Smart Evolution
- Built with clear phases so we can ship fast and improve continuously

## Product Direction

The app is designed around one principle: **log fast, learn fast**.

Planned UX highlights:
- Timeline-first workout history (not just static cards)
- Set-by-set context during logging
- In-session references to recent performance
- Focused metrics that help make the next training decision

## Tech Stack

- `SwiftUI` for all primary UI
- `SwiftData` for local persistence
- `Swift Charts` for progress visualization
- `Swift Concurrency` for async work
- `XCTest` for unit and UI testing

## Architecture (Planned)

Feature-first structure:

- `Features/WorkoutTypes`
- `Features/Logging`
- `Features/History`
- `Features/Stats`
- `Shared/Components`
- `Shared/Theme`
- `Core/Models`
- `Core/Services`
- `Core/Stats`

Core entities:
- `WorkoutType`
- `WorkoutSession`
- `ExerciseEntry`
- `SetEntry`

## Roadmap

### Phase 0: Foundation
- SwiftUI app shell
- SwiftData container
- default workout type seeding

### Phase 1: Type Management
- workout type CRUD
- archive-safe behavior

### Phase 2: Logging Flow
- create sessions
- add exercises and sets
- notes + previous-weight hints

### Phase 3: Stats
- line/bar charts
- trend classification
- weekly volume and progress indicators

### Phase 4: Reliability + Polish
- test coverage
- input/empty/error states
- UX speed improvements

## Current Status

Phase 0 and Phase 1 are complete in source:
- SwiftUI app shell with 4 tabs (`Log`, `History`, `Stats`, `Settings`)
- SwiftData model layer (`WorkoutType`, `ExerciseTemplate`, `WorkoutSession`, `ExerciseEntry`, `SetEntry`, `BodyMetric`)
- Idempotent default workout-type seed service
- Settings workout type management with add/edit/archive flows
- Name validation (no empty names, no duplicates ignoring case/whitespace)
- Archive-safe behavior that preserves existing session links
- Theme tokens (`colors`, `spacing`, `type scale`) and shared placeholder component

Detailed implementation plan lives in [PLAN.md](/Users/tannermccoy/Development/health+/PLAN.md).

## Building This Together

This project is intentionally structured for collaboration:

1. Pick one vertical slice
2. Build UI + model + logic together
3. Test it
4. Ship small, reviewable increments

If you want to contribute, open an issue or PR with:
- clear goal
- UX notes
- data model impact
- test impact

## Planned Post-MVP Features

- Rest timer
- Personal records tracking
- Quick duplicate last workout
- CSV export
- Cloud sync
- Apple Watch quick log

## Vision

`health+` should feel like a serious training tool that stays out of your way:

- fast while you lift
- insightful when you review
- dependable every day
