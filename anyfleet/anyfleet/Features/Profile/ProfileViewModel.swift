import Foundation
import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - Profile View Model

@MainActor
@Observable
final class ProfileViewModel: ErrorHandling {
    private let authService: AuthServiceProtocol
    private var imageUploadService: ImageUploadService?
    let authObserver: AuthStateObserverProtocol

    var currentError: AppError?
    var showErrorBanner: Bool = false
    var isLoading = false

    // Phase 2: Reputation metrics
    var contributionMetrics: ContributionMetrics?

    // Profile editing
    var isEditingProfile = false
    var editedUsername = ""
    var editedBio = ""
    var editedLocation = ""
    var editedNationality = ""
    var isSavingProfile = false

    // Profile image
    var selectedPhotoItem: PhotosPickerItem?
    var isUploadingImage = false

    // Auth state (exposed through viewModel for proper observation)
    var isSignedIn: Bool {
        authObserver.isSignedIn
    }

    var currentUser: UserInfo? {
        authObserver.currentUser
    }

    init(authService: AuthServiceProtocol, authObserver: AuthStateObserverProtocol? = nil) {
        self.authService = authService
        self.authObserver = authObserver ?? AuthStateObserver(authService: authService)
        self.imageUploadService = ImageUploadService(authService: authService)
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }

        await authService.logout()
    }

    func startEditingProfile(user: UserInfo) {
        isEditingProfile = true
        editedUsername = user.username ?? ""
        editedBio = user.bio ?? ""
        editedLocation = user.location ?? ""
        editedNationality = user.nationality ?? ""
        clearError()
    }

    func cancelEditingProfile() {
        isEditingProfile = false
        editedUsername = ""
        editedBio = ""
        editedLocation = ""
        editedNationality = ""
        selectedPhotoItem = nil
        clearError()
    }

    func saveProfile() async {
        guard !editedUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(AppError.validationFailed(field: "username", reason: "Display name cannot be empty"))
            return
        }

        isSavingProfile = true
        clearError()
        defer { isSavingProfile = false }

        do {
            let trimmedUsername = editedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBio = editedBio.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLocation = editedLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNationality = editedNationality.trimmingCharacters(in: .whitespacesAndNewlines)

            _ = try await authService.updateProfile(
                username: trimmedUsername,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                nationality: trimmedNationality.isEmpty ? nil : trimmedNationality,
                profileVisibility: nil
            )
            isEditingProfile = false
            editedUsername = ""
            editedBio = ""
            editedLocation = ""
            editedNationality = ""
        } catch {
            handleError(error)
        }
    }

    func handlePhotoSelection() async {
        guard let selectedPhotoItem = selectedPhotoItem,
              let imageUploadService = imageUploadService else {
            AppLogger.services.warning("No photo item or image upload service available")
            return
        }

        AppLogger.services.info("Starting photo upload process")
        isUploadingImage = true
        clearError()
        defer {
            isUploadingImage = false
            self.selectedPhotoItem = nil
            AppLogger.services.debug("Photo upload process completed")
        }

        do {
            _ = try await imageUploadService.processAndUploadImage(selectedPhotoItem)
            AppLogger.services.info("Photo uploaded successfully")
        } catch {
            AppLogger.services.error("Photo upload failed", error: error)
            handleError(error)
        }
    }

    func calculateProfileCompletion(for user: UserInfo) -> Int {
        var completedFields = 0
        let totalFields = 3

        // Username is always filled (required)
        completedFields += 1

        if user.profileImageUrl != nil {
            completedFields += 1
        }
        if let bio = user.bio, !bio.isEmpty {
            completedFields += 1
        }

        return Int((Double(completedFields) / Double(totalFields)) * 100)
    }

    func handleAppleSignIn(
        result: Result<ASAuthorization, Error>
    ) async {
        isLoading = true
        clearError()
        defer { isLoading = false }

        do {
            try await authService.handleAppleSignIn(result: result)
        } catch {
            handleError(error)
        }
    }
}

// MARK: - Models

struct ContributionMetrics: Codable, Sendable {
    let totalContributions: Int
    let totalForks: Int
    let averageRating: Double
    let verificationTier: DesignSystem.Profile.VerificationTier
    let createdCount: Int
    let forkedCount: Int
    let importedCount: Int
}
