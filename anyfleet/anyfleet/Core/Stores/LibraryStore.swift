import Foundation
import SwiftUI

@Observable
final class LibraryStore {
    private(set) var library: [LibraryModel] = []

    // Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    nonisolated private let repository: any LibraryRepository

    // MARK: - Initialization

    nonisolated init(repository: any LibraryRepository) {
        self.repository = repository
    }
}