import Foundation

// MARK: - Library Model

nonisolated struct LibraryModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
}
