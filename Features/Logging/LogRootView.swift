import SwiftData
import SwiftUI

struct LogRootView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    @Query(sort: \WorkoutType.sortOrder)
    private var allWorkoutTypes: [WorkoutType]

    @State private var selectedWorkoutTypeID: UUID?
    @State private var draftSessionNotes = ""
    @State private var isStartSheetPresented = false
    @State private var pendingDeleteSession: WorkoutSession?
    @State private var actionErrorMessage: String?
    @State private var editMode: EditMode = .inactive

    private var activeWorkoutTypes: [WorkoutType] {
        allWorkoutTypes
            .filter { $0.isArchived == false }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    private var activeSession: WorkoutSession? {
        allSessions.first { $0.endedAt == nil }
    }

    private var completedSessions: [WorkoutSession] {
        allSessions
            .filter { $0.endedAt != nil }
            .sorted { lhs, rhs in
                lhs.startedAt > rhs.startedAt
            }
    }

    private var groupedCompletedSessions: [LogFeedTimelineService.DayGroup] {
        LogFeedTimelineService.groupSessionsByDay(completedSessions)
    }

    private var selectedWorkoutType: WorkoutType? {
        if let selectedWorkoutTypeID {
            return activeWorkoutTypes.first(where: { $0.id == selectedWorkoutTypeID })
        }
        return activeWorkoutTypes.first
    }

    private var latestCompletedSession: WorkoutSession? {
        completedSessions.first
    }

    private var isEditingFeed: Bool {
        editMode == .active
    }

    var body: some View {
        NavigationStack {
            Group {
                if let activeSession {
                    SessionEditorView(
                        session: activeSession,
                        title: "Active Session",
                        showFinishButton: true,
                        finishButtonTitle: "Save Session"
                    ) {
                        finish(activeSession)
                    }
                } else {
                    timelineFeed
                }
            }
            .scrollContentBackground(.hidden)
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationChrome()
            .environment(\.editMode, $editMode)
            .toolbar {
                if activeSession == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isEditingFeed ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                editMode = isEditingFeed ? .inactive : .active
                            }
                        }
                        .accessibilityIdentifier("log.feed.toolbar.edit")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isStartSheetPresented = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("log.feed.toolbar.add")
                    }
                }
            }
            .sheet(isPresented: $isStartSheetPresented) {
                startSessionSheet
            }
            .confirmationDialog(
                "Delete Session",
                isPresented: Binding(
                    get: { pendingDeleteSession != nil },
                    set: { isPresented in
                        if isPresented == false {
                            pendingDeleteSession = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDeleteSession {
                        delete(pendingDeleteSession)
                    }
                }

                Button("Cancel", role: .cancel) {
                    pendingDeleteSession = nil
                }
            } message: {
                Text("This removes the session and all logged exercises and sets.")
            }
            .alert(
                "Action Failed",
                isPresented: Binding(
                    get: { actionErrorMessage != nil },
                    set: { isPresented in
                        if isPresented == false {
                            actionErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionErrorMessage ?? "Unknown error.")
            }
        }
        .onAppear {
            if selectedWorkoutTypeID == nil {
                selectedWorkoutTypeID = activeWorkoutTypes.first?.id
            }
        }
    }

    private var timelineFeed: some View {
        List {
            if activeWorkoutTypes.isEmpty {
                Section {
                    PlaceholderCard(
                        title: "No Workout Types",
                        message: "Create at least one workout type in Settings before starting a session."
                    )
                    .accessibilityIdentifier("log.empty.noWorkoutTypes")
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
            } else {
                Section {
                    GlassCard(style: .chrome, padding: AppTheme.Spacing.medium, cornerRadius: AppTheme.Radius.medium) {
                        HStack(spacing: AppTheme.Spacing.small) {
                            Button {
                                startSession()
                            } label: {
                                Label("Start Session", systemImage: "plus.circle.fill")
                                    .font(AppTheme.Typography.caption)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.Colors.accent)
                            .accessibilityIdentifier("log.start.button")

                            if let latestCompletedSession {
                                Button {
                                    startFrom(latestCompletedSession)
                                } label: {
                                    Label("Start Again", systemImage: "arrow.clockwise")
                                        .font(AppTheme.Typography.caption)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("log.feed.quick.startAgain")
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            if isEditingFeed {
                Section {
                    Label("Editing sessions", systemImage: "slider.horizontal.3")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .accessibilityIdentifier("log.feed.editing.indicator")
                }
                .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
            }

            if groupedCompletedSessions.isEmpty {
                Section {
                    PlaceholderCard(
                        title: "No Sessions Yet",
                        message: "Save your first workout to start building your timeline."
                    )
                    .accessibilityIdentifier("log.feed.empty.sessions")
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
            } else {
                ForEach(groupedCompletedSessions, id: \.dayStart) { group in
                    Section {
                        ForEach(group.sessions, id: \.id) { session in
                            NavigationLink {
                                LogSessionDetailView(session: session)
                            } label: {
                                SessionSummaryRow(
                                    session: session,
                                    summaryLines: LogFeedTimelineService.summaryLines(for: session),
                                    durationLabel: LogFeedTimelineService.durationLabel(for: session)
                                )
                            }
                            .accessibilityIdentifier("log.feed.row")
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    startFrom(session)
                                } label: {
                                    Label("Start Again", systemImage: "play.fill")
                                }
                                .tint(AppTheme.Colors.accent)

                                Button {
                                    duplicate(session)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteSession = session
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            guard let offset = offsets.first, group.sessions.indices.contains(offset) else {
                                return
                            }
                            pendingDeleteSession = group.sessions[offset]
                        }
                    } header: {
                        Text(group.dayStart, format: .dateTime.weekday(.wide).month().day().year())
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("log.feed.list")
    }

    private var startSessionSheet: some View {
        NavigationStack {
            Form {
                Section("Start Workout") {
                    Picker("Workout Type", selection: Binding(
                        get: { selectedWorkoutTypeID ?? activeWorkoutTypes.first?.id ?? UUID() },
                        set: { selectedWorkoutTypeID = $0 }
                    )) {
                        ForEach(activeWorkoutTypes, id: \.id) { workoutType in
                            Text(workoutType.name).tag(workoutType.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("log.start.workoutTypePicker")

                    TextField(
                        "Session notes (optional)",
                        text: $draftSessionNotes,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .accessibilityIdentifier("log.start.sessionNotesField")
                }

                Section {
                    Button {
                        startSession()
                        isStartSheetPresented = false
                    } label: {
                        Label("Start Session", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.accent)
                    .accessibilityIdentifier("log.start.sheet.button")
                }
            }
            .navigationTitle("Start Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isStartSheetPresented = false
                    }
                }
            }
        }
    }

    private var backgroundGradient: LinearGradient {
        AppTheme.Gradients.appBackground
    }

    private func startSession() {
        guard let selectedWorkoutType else {
            actionErrorMessage = "Select a workout type."
            return
        }

        do {
            _ = try WorkoutSessionManager.startSession(
                workoutType: selectedWorkoutType,
                notes: draftSessionNotes,
                context: modelContext
            )
            draftSessionNotes = ""
            editMode = .inactive
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func startFrom(_ source: WorkoutSession) {
        do {
            let newSession = try WorkoutSessionManager.startSession(
                workoutType: source.workoutType,
                notes: source.sessionNotes,
                context: modelContext
            )

            let orderedEntries = source.entries.sorted { lhs, rhs in
                if lhs.orderIndex == rhs.orderIndex {
                    return lhs.exerciseName.localizedCaseInsensitiveCompare(rhs.exerciseName) == .orderedAscending
                }
                return lhs.orderIndex < rhs.orderIndex
            }

            for entry in orderedEntries {
                _ = try WorkoutSessionManager.addExercise(
                    to: newSession,
                    name: entry.exerciseName,
                    notes: entry.entryNotes,
                    context: modelContext
                )
            }

            editMode = .inactive
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func duplicate(_ source: WorkoutSession) {
        do {
            let copiedEnd = Date.now
            let sourceEnd = source.endedAt ?? source.startedAt
            let sourceDuration = max(0, sourceEnd.timeIntervalSince(source.startedAt))
            let copiedStart = copiedEnd.addingTimeInterval(-sourceDuration)

            let copiedSession = WorkoutSession(
                startedAt: copiedStart,
                endedAt: copiedEnd,
                workoutType: source.workoutType,
                sessionNotes: source.sessionNotes
            )
            modelContext.insert(copiedSession)

            let orderedEntries = source.entries.sorted { lhs, rhs in
                if lhs.orderIndex == rhs.orderIndex {
                    return lhs.exerciseName.localizedCaseInsensitiveCompare(rhs.exerciseName) == .orderedAscending
                }
                return lhs.orderIndex < rhs.orderIndex
            }

            for entry in orderedEntries {
                let copiedEntry = ExerciseEntry(
                    session: copiedSession,
                    exerciseName: entry.exerciseName,
                    orderIndex: entry.orderIndex,
                    entryNotes: entry.entryNotes
                )
                modelContext.insert(copiedEntry)
                if copiedSession.entries.contains(where: { $0.id == copiedEntry.id }) == false {
                    copiedSession.entries.append(copiedEntry)
                }

                for set in WorkoutSessionManager.orderedSets(for: entry) {
                    let copiedSet = SetEntry(
                        exerciseEntry: copiedEntry,
                        setIndex: set.setIndex,
                        reps: set.reps,
                        weight: set.weight,
                        isWarmup: set.isWarmup,
                        setNotes: set.setNotes,
                        loggedAt: copiedEnd
                    )
                    modelContext.insert(copiedSet)
                    if copiedEntry.sets.contains(where: { $0.id == copiedSet.id }) == false {
                        copiedEntry.sets.append(copiedSet)
                    }
                }
            }

            try WorkoutSessionManager.saveIfNeeded(modelContext)
        } catch {
            actionErrorMessage = "Unable to duplicate session."
        }
    }

    private func delete(_ session: WorkoutSession) {
        modelContext.delete(session)

        do {
            try WorkoutSessionManager.saveIfNeeded(modelContext)
            pendingDeleteSession = nil
        } catch {
            actionErrorMessage = "Unable to delete session."
        }
    }

    private func finish(_ session: WorkoutSession) {
        do {
            try WorkoutSessionManager.finishSession(session, context: modelContext)
        } catch {
            actionErrorMessage = "Unable to save session."
        }
    }
}

private struct LogSessionDetailView: View {
    @Bindable var session: WorkoutSession

    var body: some View {
        SessionEditorView(
            session: session,
            title: "Session Detail",
            showFinishButton: false,
            finishButtonTitle: ""
        )
        .navigationTitle(session.workoutType?.name ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .appNavigationChrome()
    }
}

private struct TimelineDatePill: View {
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Text(date, format: .dateTime.day())
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .fill(AppTheme.material(.chrome))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .stroke(AppTheme.Colors.hairline.opacity(0.52), lineWidth: 1)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityIdentifier("log.feed.row.datePill")
    }
}

private struct SessionSummaryRow: View {
    let session: WorkoutSession
    let summaryLines: [String]
    let durationLabel: String?

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
            TimelineDatePill(date: session.startedAt)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
                    Text(session.workoutType?.name ?? "Workout")
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: AppTheme.Spacing.small)

                    if let durationLabel {
                        Text(durationLabel)
                            .font(AppTheme.Typography.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .accessibilityIdentifier("log.feed.row.duration")
                    }
                }

                ForEach(Array(summaryLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("log.feed.row.summary")
                }

                if session.sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Text(session.sessionNotes)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
    }
}

struct SessionEditorView: View {
    struct DeletedSetSnapshot {
        let entryID: UUID
        let setIndex: Int
        let reps: Int
        let weight: Double
        let isWarmup: Bool
        let setNotes: String
        let loggedAt: Date
    }

    @Environment(\.modelContext) private var modelContext

    @Bindable var session: WorkoutSession
    let title: String
    let showFinishButton: Bool
    let finishButtonTitle: String
    let onFinish: (() -> Void)?

    @State private var isAddExerciseSheetPresented = false
    @State private var draftExerciseName = ""
    @State private var draftExerciseNotes = ""
    @State private var pendingDeleteExercise: ExerciseEntry?
    @State private var deletedSetSnapshot: DeletedSetSnapshot?
    @State private var errorMessage: String?

    init(
        session: WorkoutSession,
        title: String,
        showFinishButton: Bool,
        finishButtonTitle: String,
        onFinish: (() -> Void)? = nil
    ) {
        self.session = session
        self.title = title
        self.showFinishButton = showFinishButton
        self.finishButtonTitle = finishButtonTitle
        self.onFinish = onFinish
    }

    private var sortedEntries: [ExerciseEntry] {
        session.entries.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex {
                return lhs.exerciseName.localizedCaseInsensitiveCompare(rhs.exerciseName) == .orderedAscending
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }

    private var canSaveExercise: Bool {
        draftExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        List {
            Section(title) {
                HStack(spacing: AppTheme.Spacing.small) {
                    Label(
                        session.workoutType?.name ?? "Unassigned",
                        systemImage: session.workoutType?.symbolName ?? "dumbbell.fill"
                    )
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                    Spacer()

                    Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                TextField("Session notes", text: sessionNotesBinding, axis: .vertical)
                    .lineLimit(2...5)

                if showFinishButton {
                    Button {
                        onFinish?()
                    } label: {
                        Label(finishButtonTitle, systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.accent)
                    .accessibilityIdentifier("log.session.save.button")
                }
            }
            .listRowBackground(AppTheme.Colors.surface.opacity(0.72))

            if sortedEntries.isEmpty {
                Section("Exercises") {
                    PlaceholderCard(
                        title: "No Exercises Yet",
                        message: "Add your first exercise to start logging sets."
                    )
                    .accessibilityIdentifier("log.empty.noExercises")
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
            } else {
                ForEach(sortedEntries, id: \.id) { entry in
                    Section {
                        TextField("Exercise", text: exerciseNameBinding(for: entry))
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)

                        if let reference = previousReference(for: entry) {
                            Label {
                                Text(
                                    "Previous: \(formattedWeight(reference.weight)) x \(reference.reps) (\(reference.loggedAt, format: .dateTime.month().day()))"
                                )
                            } icon: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        TextField("Exercise notes", text: entryNotesBinding(for: entry), axis: .vertical)
                            .lineLimit(1...3)

                        ForEach(WorkoutSessionManager.orderedSets(for: entry), id: \.id) { set in
                            setRow(set, for: entry)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(set, from: entry)
                                    } label: {
                                        Label("Delete Set", systemImage: "trash")
                                    }
                                }
                        }

                        HStack(spacing: AppTheme.Spacing.small) {
                            Button {
                                addSet(to: entry)
                            } label: {
                                Label("Add Set", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("log.set.add.button")

                            Button {
                                repeatLastSet(for: entry)
                            } label: {
                                Label("Repeat Last", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(entry.sets.isEmpty)
                            .accessibilityIdentifier("log.set.repeat.button")
                        }
                    } header: {
                        HStack {
                            Text(entry.exerciseName)
                            Spacer()
                            Button(role: .destructive) {
                                pendingDeleteExercise = entry
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
                }
            }

            Section {
                Button {
                    isAddExerciseSheetPresented = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .accessibilityIdentifier("log.exercise.add.button")
            }
            .listRowBackground(AppTheme.Colors.surface.opacity(0.72))

            if deletedSetSnapshot != nil {
                Section {
                    Button {
                        undoDeletedSet()
                    } label: {
                        Label("Undo Deleted Set", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                }
                .listRowBackground(AppTheme.Colors.surface.opacity(0.72))
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $isAddExerciseSheetPresented) {
            NavigationStack {
                Form {
                    Section("Exercise") {
                        TextField("Exercise name", text: $draftExerciseName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .accessibilityIdentifier("log.exercise.name.field")

                        TextField("Notes (optional)", text: $draftExerciseNotes, axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityIdentifier("log.exercise.notes.field")
                    }
                }
                .navigationTitle("Add Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            closeExerciseSheet()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            addExercise()
                        }
                        .disabled(canSaveExercise == false)
                        .accessibilityIdentifier("log.exercise.save.button")
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Remove Exercise",
            isPresented: Binding(
                get: { pendingDeleteExercise != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingDeleteExercise = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let pendingDeleteExercise {
                    removeExercise(pendingDeleteExercise)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the exercise and all its logged sets.")
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
    }

    @ViewBuilder
    private func setRow(_ set: SetEntry, for entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(spacing: AppTheme.Spacing.small) {
                Text("Set \(set.setIndex)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 44, alignment: .leading)

                TextField("Reps", text: repsBinding(for: set))
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .accessibilityIdentifier("log.set.reps.field")

                TextField("Weight", text: weightBinding(for: set))
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .accessibilityIdentifier("log.set.weight.field")

                Toggle("Warmup", isOn: warmupBinding(for: set))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("log.set.warmup.toggle")
            }

            TextField("Set notes", text: setNotesBinding(for: set), axis: .vertical)
                .lineLimit(1...2)
        }
    }

    private var sessionNotesBinding: Binding<String> {
        Binding(
            get: { session.sessionNotes },
            set: { newValue in
                session.sessionNotes = newValue
                persistChanges()
            }
        )
    }

    private func exerciseNameBinding(for entry: ExerciseEntry) -> Binding<String> {
        Binding(
            get: { entry.exerciseName },
            set: { newValue in
                entry.exerciseName = newValue
                persistChanges()
            }
        )
    }

    private func entryNotesBinding(for entry: ExerciseEntry) -> Binding<String> {
        Binding(
            get: { entry.entryNotes },
            set: { newValue in
                entry.entryNotes = newValue
                persistChanges()
            }
        )
    }

    private func repsBinding(for set: SetEntry) -> Binding<String> {
        Binding(
            get: { set.reps > 0 ? String(set.reps) : "" },
            set: { newValue in
                let cleaned = newValue.filter(\.isNumber)
                set.reps = Int(cleaned) ?? 0
                persistChanges()
            }
        )
    }

    private func weightBinding(for set: SetEntry) -> Binding<String> {
        Binding(
            get: {
                if set.weight == 0 {
                    return ""
                }
                return Self.weightFormatter.string(from: NSNumber(value: set.weight)) ?? String(set.weight)
            },
            set: { newValue in
                var cleaned = newValue.filter { character in
                    character.isNumber || character == "."
                }
                if cleaned.filter({ $0 == "." }).count > 1 {
                    cleaned = String(cleaned.dropLast())
                }

                set.weight = Double(cleaned) ?? 0
                persistChanges()
            }
        )
    }

    private func setNotesBinding(for set: SetEntry) -> Binding<String> {
        Binding(
            get: { set.setNotes },
            set: { newValue in
                set.setNotes = newValue
                persistChanges()
            }
        )
    }

    private func warmupBinding(for set: SetEntry) -> Binding<Bool> {
        Binding(
            get: { set.isWarmup },
            set: { newValue in
                set.isWarmup = newValue
                persistChanges()
            }
        )
    }

    private func addExercise() {
        do {
            _ = try WorkoutSessionManager.addExercise(
                to: session,
                name: draftExerciseName,
                notes: draftExerciseNotes,
                context: modelContext
            )
            closeExerciseSheet()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSet(to entry: ExerciseEntry) {
        do {
            _ = try WorkoutSessionManager.addSet(to: entry, context: modelContext)
        } catch {
            errorMessage = "Unable to add set."
        }
    }

    private func repeatLastSet(for entry: ExerciseEntry) {
        do {
            _ = try WorkoutSessionManager.repeatLastSet(for: entry, context: modelContext)
        } catch {
            errorMessage = "Unable to repeat set."
        }
    }

    private func delete(_ set: SetEntry, from entry: ExerciseEntry) {
        deletedSetSnapshot = DeletedSetSnapshot(
            entryID: entry.id,
            setIndex: set.setIndex,
            reps: set.reps,
            weight: set.weight,
            isWarmup: set.isWarmup,
            setNotes: set.setNotes,
            loggedAt: set.loggedAt
        )

        do {
            try WorkoutSessionManager.removeSet(set, from: entry, context: modelContext)
        } catch {
            errorMessage = "Unable to delete set."
        }
    }

    private func undoDeletedSet() {
        guard let deletedSetSnapshot else {
            return
        }

        guard let entry = session.entries.first(where: { $0.id == deletedSetSnapshot.entryID }) else {
            self.deletedSetSnapshot = nil
            return
        }

        let restoredSet = SetEntry(
            exerciseEntry: entry,
            setIndex: deletedSetSnapshot.setIndex,
            reps: deletedSetSnapshot.reps,
            weight: deletedSetSnapshot.weight,
            isWarmup: deletedSetSnapshot.isWarmup,
            setNotes: deletedSetSnapshot.setNotes,
            loggedAt: deletedSetSnapshot.loggedAt
        )
        modelContext.insert(restoredSet)
        entry.sets.append(restoredSet)
        WorkoutSessionManager.reindexSets(in: entry)

        do {
            try WorkoutSessionManager.saveIfNeeded(modelContext)
            self.deletedSetSnapshot = nil
        } catch {
            errorMessage = "Unable to restore set."
        }
    }

    private func removeExercise(_ entry: ExerciseEntry) {
        do {
            try WorkoutSessionManager.removeExercise(entry, from: session, context: modelContext)
        } catch {
            errorMessage = "Unable to remove exercise."
        }
    }

    private func closeExerciseSheet() {
        isAddExerciseSheetPresented = false
        draftExerciseName = ""
        draftExerciseNotes = ""
    }

    private func previousReference(for entry: ExerciseEntry) -> PreviousWeightLookupService.Reference? {
        do {
            return try PreviousWeightLookupService.latestReference(
                for: entry.exerciseName,
                excludingSessionID: session.id,
                context: modelContext
            )
        } catch {
            return nil
        }
    }

    private func formattedWeight(_ value: Double) -> String {
        Self.weightFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func persistChanges() {
        do {
            try WorkoutSessionManager.saveIfNeeded(modelContext)
        } catch {
            errorMessage = "Unable to save changes."
        }
    }

    private static let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
