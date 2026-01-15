//
//  DiscoverContentReaderViewModel.swift
//  anyfleet
//
//  ViewModel for reading public content from discover tab.
//

import Foundation
import Observation

@MainActor
@Observable
final class DiscoverContentReaderViewModel: ErrorHandling {
    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let publicID: String

    // MARK: - State

    var contentDetail: SharedContentDetail?
    var parsedContent: ParsedContent?
    var isLoading = false
    var currentError: AppError?
    var showErrorBanner = false

    // MARK: - Initialization

    init(apiClient: APIClientProtocol, publicID: String) {
        self.apiClient = apiClient
        self.publicID = publicID
    }

    // MARK: - Actions

    func loadContent() async {
        guard contentDetail == nil else { return }
        guard !isLoading else { return }

        isLoading = true
        clearError()
        defer { isLoading = false }

        do {
            AppLogger.view.startOperation("Load Discover Content")
            let detail = try await apiClient.fetchPublicContent(publicID: publicID)

            // Parse the content based on its type
            let parsed = try parseContent(from: detail)

            self.contentDetail = detail
            self.parsedContent = parsed

            AppLogger.view.completeOperation("Load Discover Content")
            AppLogger.view.info("Successfully loaded and parsed content: \(detail.title)")

        } catch {
            AppLogger.view.error("Failed to load discover content \(publicID)", error: error)
            handleError(error)
        }
    }

    // MARK: - Content Parsing

    private func parseContent(from detail: SharedContentDetail) throws -> ParsedContent {
        let contentType = ContentType(rawValue: detail.contentType) ?? .checklist

        switch contentType {
        case .checklist:
            return .checklist(try parseChecklist(from: detail))
        case .practiceGuide:
            return .practiceGuide(try parsePracticeGuide(from: detail))
        case .flashcardDeck:
            return .flashcardDeck(try parseFlashcardDeck(from: detail))
        }
    }

    private func parseChecklist(from detail: SharedContentDetail) throws -> Checklist {
        // Normalize contentData to ensure JSON serializability
        let normalizedContentData: [String: Any]
        do {
            let tempData = try JSONSerialization.data(withJSONObject: detail.contentData, options: [])
            let jsonObject = try JSONSerialization.jsonObject(with: tempData, options: [])
            guard let dict = jsonObject as? [String: Any] else {
                throw AppError.validationFailed(field: "content", reason: "Content data is not a valid dictionary")
            }
            normalizedContentData = dict
        } catch {
            throw AppError.validationFailed(field: "content", reason: "Content data contains non-serializable values: \(error.localizedDescription)")
        }

        let checklistData = try JSONSerialization.data(withJSONObject: normalizedContentData, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Debug log the content data structure for troubleshooting
        if let debugData = try? JSONSerialization.data(withJSONObject: normalizedContentData, options: .prettyPrinted),
           let debugString = String(data: debugData, encoding: .utf8) {
            AppLogger.view.debug("Discover checklist content data structure:\n\(debugString)")
        }

        var checklist = try decoder.decode(Checklist.self, from: checklistData)

        // Override metadata with the shared content info
        checklist.title = detail.title
        checklist.description = detail.description
        checklist.tags = detail.tags

        return checklist
    }

    private func parsePracticeGuide(from detail: SharedContentDetail) throws -> PracticeGuide {
        let guideData = try JSONSerialization.data(withJSONObject: detail.contentData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var guide = try decoder.decode(PracticeGuide.self, from: guideData)

        // Override metadata with the shared content info
        guide.title = detail.title
        guide.description = detail.description
        guide.tags = detail.tags

        return guide
    }

    private func parseFlashcardDeck(from detail: SharedContentDetail) throws -> FlashcardDeck {
        // For now, we'll throw an error as flashcard decks aren't fully implemented yet
        // This should be updated when flashcard functionality is complete
        throw AppError.validationFailed(field: "contentType", reason: "Flashcard decks are not yet supported in discover")
    }
}

// MARK: - Parsed Content Enum

enum ParsedContent {
    case checklist(Checklist)
    case practiceGuide(PracticeGuide)
    case flashcardDeck(FlashcardDeck)
}