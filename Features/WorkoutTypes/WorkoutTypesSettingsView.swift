import SwiftData
import SwiftUI

struct WorkoutTypesSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutType.sortOrder)
    private var allWorkoutTypes: [WorkoutType]

    @State private var isEditorPresented = false
    @State private var editingWorkoutType: WorkoutType?
    @State private var draftWorkoutTypeName = ""
    @State private var editorErrorMessage: String?
    @State private var pendingArchiveWorkoutType: WorkoutType?
    @State private var actionErrorMessage: String?

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

    private var archivedWorkoutTypes: [WorkoutType] {
        allWorkoutTypes
            .filter(\.isArchived)
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var isSaveDisabled: Bool {
        draftWorkoutTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editorTitle: String {
        editingWorkoutType == nil ? "New Workout Type" : "Edit Workout Type"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Workout Types") {
                    if activeWorkoutTypes.isEmpty {
                        Text("No workout types yet.")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    } else {
                        ForEach(activeWorkoutTypes, id: \.id) { workoutType in
                            workoutTypeRow(workoutType)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        beginEditing(workoutType)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(AppTheme.Colors.accent)

                                    Button(role: .destructive) {
                                        pendingArchiveWorkoutType = workoutType
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                        }
                    }
                }

                if archivedWorkoutTypes.isEmpty == false {
                    Section("Archived") {
                        ForEach(archivedWorkoutTypes, id: \.id) { workoutType in
                            workoutTypeRow(workoutType)
                                .opacity(0.65)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        beginCreating()
                    } label: {
                        Label("Add Workout Type", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isEditorPresented) {
                editorSheet
            }
            .alert(
                "Archive Workout Type",
                isPresented: Binding(
                    get: { pendingArchiveWorkoutType != nil },
                    set: { isPresented in
                        if isPresented == false {
                            pendingArchiveWorkoutType = nil
                        }
                    }
                ),
                presenting: pendingArchiveWorkoutType
            ) { workoutType in
                Button("Archive", role: .destructive) {
                    archive(workoutType)
                }
                Button("Cancel", role: .cancel) {}
            } message: { workoutType in
                Text("Archive \"\(workoutType.name)\"? Existing sessions remain intact.")
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
    }

    @ViewBuilder
    private func workoutTypeRow(_ workoutType: WorkoutType) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Circle()
                .fill(rowColor(for: workoutType))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                Text(workoutType.name)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: AppTheme.Spacing.small) {
                    if workoutType.isSystemType {
                        Label("Default", systemImage: "star.fill")
                    } else {
                        Label("Custom", systemImage: "person.fill")
                    }

                    if workoutType.isArchived {
                        Label("Archived", systemImage: "archivebox")
                    }
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            if let symbolName = workoutType.symbolName {
                Image(systemName: symbolName)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xSmall)
        .listRowBackground(AppTheme.Colors.surface)
    }

    private func rowColor(for workoutType: WorkoutType) -> Color {
        if let colorHex = workoutType.colorHex, let color = Color(hex: colorHex) {
            return color
        }
        return AppTheme.Colors.accent
    }

    private var editorSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Workout type name", text: $draftWorkoutTypeName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }

                if let editorErrorMessage {
                    Section {
                        Text(editorErrorMessage)
                            .foregroundStyle(.red)
                            .font(AppTheme.Typography.caption)
                    }
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        closeEditor()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditorChanges()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func beginCreating() {
        editingWorkoutType = nil
        draftWorkoutTypeName = ""
        editorErrorMessage = nil
        isEditorPresented = true
    }

    private func beginEditing(_ workoutType: WorkoutType) {
        editingWorkoutType = workoutType
        draftWorkoutTypeName = workoutType.name
        editorErrorMessage = nil
        isEditorPresented = true
    }

    private func closeEditor() {
        isEditorPresented = false
        editorErrorMessage = nil
        draftWorkoutTypeName = ""
        editingWorkoutType = nil
    }

    private func saveEditorChanges() {
        do {
            if let editingWorkoutType {
                try WorkoutTypeManager.rename(editingWorkoutType, to: draftWorkoutTypeName, context: modelContext)
            } else {
                _ = try WorkoutTypeManager.create(name: draftWorkoutTypeName, context: modelContext)
            }
            closeEditor()
        } catch let validationError as WorkoutTypeManager.ValidationError {
            editorErrorMessage = validationError.errorDescription ?? "Unable to save workout type."
        } catch {
            editorErrorMessage = "Unable to save workout type."
        }
    }

    private func archive(_ workoutType: WorkoutType) {
        do {
            try WorkoutTypeManager.archive(workoutType, context: modelContext)
        } catch {
            actionErrorMessage = "Unable to archive workout type."
        }
    }
}
