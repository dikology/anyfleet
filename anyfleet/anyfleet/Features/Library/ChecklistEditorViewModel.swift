//
//  ChecklistEditorViewModel.swift
//  anyfleet
//
//  ViewModel for checklist editing flow
//

import Foundation
import Observation

@MainActor
@Observable
final class ChecklistEditorViewModel: ErrorHandling {
    // MARK: - Dependencies

    private let libraryStore: LibraryStore
    private let checklistID: UUID?
    private let onDismiss: () -> Void

    // MARK: - State

    var checklist: Checklist
    var isSaving = false
    var isLoading = false
    var editingSection: ChecklistSection?
    var editingItem: (sectionID: UUID, item: ChecklistItem)?

    // Error handling
    var currentError: AppError?
    var showErrorBanner = false
    
    var isNewChecklist: Bool {
        checklistID == nil
    }
    
    // MARK: - Initialization
    
    init(
        libraryStore: LibraryStore,
        checklistID: UUID? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.libraryStore = libraryStore
        self.checklistID = checklistID
        self.onDismiss = onDismiss
        self.checklist = Checklist.empty()
    }
    
    // MARK: - Actions
    
    func loadChecklist() async {
        guard let checklistID = checklistID, !isNewChecklist else { return }

        isLoading = true
        clearError()

        do {
            // Ensure library metadata is loaded for on-demand fetching
            if libraryStore.myChecklists.isEmpty {
                await libraryStore.loadLibrary()
            }

            let loaded = try await libraryStore.fetchChecklist(checklistID)
            checklist = loaded
        } catch {
            handleError(error)
        }

        isLoading = false
    }
    
    func saveChecklist() async {
        guard !isSaving else { return }

        // Validation: every section must have at least one item
        if let emptySection = checklist.sections.first(where: { $0.items.isEmpty }) {
            handleError(LibraryError.validationFailed("Section '\(emptySection.title)' must have at least one item"))
            return
        }

        guard !checklist.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(LibraryError.validationFailed("Checklist title is required"))
            return
        }

        isSaving = true
        clearError()

        do {
            if isNewChecklist {
                try await libraryStore.createChecklist(checklist)
            } else {
                try await libraryStore.saveChecklist(checklist)
            }

            // Reload library to reflect changes
            await libraryStore.loadLibrary()

            onDismiss()
        } catch {
            isSaving = false
            handleError(error)
        }
    }
    
    func addSection(_ section: ChecklistSection) {
        checklist.addSection(section)
    }
    
    func updateSection(_ section: ChecklistSection) {
        if let index = checklist.sections.firstIndex(where: { $0.id == section.id }) {
            checklist.sections[index] = section
            checklist.updatedAt = Date()
        }
    }
    
    func deleteSection(id: UUID) {
        checklist.removeSection(id: id)
    }
    
    func addItem(to sectionID: UUID) {
        guard let sectionIndex = checklist.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        
        let newItem = ChecklistItem(
            title: "",
            sortOrder: checklist.sections[sectionIndex].items.count
        )
        
        checklist.sections[sectionIndex].items.append(newItem)
        editingItem = (sectionID, newItem)
    }
    
    func updateItem(_ item: ChecklistItem, inSection sectionID: UUID) {
        guard let sectionIndex = checklist.sections.firstIndex(where: { $0.id == sectionID }),
              let itemIndex = checklist.sections[sectionIndex].items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        
        checklist.sections[sectionIndex].items[itemIndex] = item
        checklist.updatedAt = Date()
    }
    
    func deleteItem(_ itemID: UUID, fromSection sectionID: UUID) {
        guard let sectionIndex = checklist.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        checklist.sections[sectionIndex].items.removeAll { $0.id == itemID }
        checklist.updatedAt = Date()
    }
    
    func moveItem(in sectionID: UUID, from: Int, to: Int) {
        guard let sectionIndex = checklist.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        checklist.sections[sectionIndex].items.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        checklist.updatedAt = Date()
    }
}

