import Foundation

enum L10n {
    static let Home = NSLocalizedString(
        "home",
        tableName: "Localizable",
        comment: "Title for the home tab"
    )

    enum Greeting {
        static let morning = NSLocalizedString(
            "greeting.morning",
            tableName: "Localizable",
            comment: "Morning greeting"
        )

        static let day = NSLocalizedString(
            "greeting.day",
            tableName: "Localizable",
            comment: "day greeting"
        )

        static let evening = NSLocalizedString(
            "greeting.evening",
            tableName: "Localizable",
            comment: "evening greeting"
        )

        static let night = NSLocalizedString(
            "greeting.night",
            tableName: "Localizable",
            comment: "night greeting"
        )
    }
    
    enum Library {
        static let myLibrary = NSLocalizedString(
            "library.myLibrary",
            tableName: "Localizable",
            comment: "Title for the library tab"
        )
        
        static let myLibraryDescription = NSLocalizedString(
            "library.myLibraryDescription",
            tableName: "Localizable",
            comment: "Description for the library tab"
        )
        
        static let newChecklist = NSLocalizedString(
            "library.newChecklist",
            tableName: "Localizable",
            comment: "Label for creating a new checklist in the library"
        )
        
        static let newFlashcardDeck = NSLocalizedString(
            "library.newFlashcardDeck",
            tableName: "Localizable",
            comment: "Label for creating a new flashcard deck in the library"
        )
        
        static let newPracticeGuide = NSLocalizedString(
            "library.newPracticeGuide",
            tableName: "Localizable",
            comment: "Label for creating a new practice guide in the library"
        )
        
        static let filterAll = NSLocalizedString(
            "library.filter.all",
            tableName: "Localizable",
            comment: "Filter label for showing all library items"
        )
        
        static let filterChecklists = NSLocalizedString(
            "library.filter.checklists",
            tableName: "Localizable",
            comment: "Filter label for showing only checklists"
        )
        
        static let filterGuides = NSLocalizedString(
            "library.filter.guides",
            tableName: "Localizable",
            comment: "Filter label for showing only practice guides"
        )
        
        static let filterDecks = NSLocalizedString(
            "library.filter.decks",
            tableName: "Localizable",
            comment: "Filter label for showing only flashcard decks"
        )
        
        static let actionDelete = NSLocalizedString(
            "library.action.delete",
            tableName: "Localizable",
            comment: "Delete action label in the library list"
        )
        
        static let actionEdit = NSLocalizedString(
            "library.action.edit",
            tableName: "Localizable",
            comment: "Edit action label in the library list"
        )
        
        static let actionPin = NSLocalizedString(
            "library.action.pin",
            tableName: "Localizable",
            comment: "Pin action label in the library list"
        )
        
        static let actionUnpin = NSLocalizedString(
            "library.action.unpin",
            tableName: "Localizable",
            comment: "Unpin action label in the library list"
        )
        
        static let filterAccessibilityLabel = NSLocalizedString(
            "library.filter.accessibilityLabel",
            tableName: "Localizable",
            comment: "Accessibility label for the content filter segmented control"
        )
        
        static let updatedPrefix = NSLocalizedString(
            "library.updatedPrefix",
            tableName: "Localizable",
            comment: "Prefix text for updated date in library item metadata"
        )

        static let emptyStateTitle = NSLocalizedString(
            "library.emptyState.title",
            tableName: "Localizable",
            comment: "Title for the library empty state when user has no content"
        )

        static let emptyStateMessage = NSLocalizedString(
            "library.emptyState.message",
            tableName: "Localizable",
            comment: "Message for the library empty state encouraging creation of content"
        )

        static let emptyStateAccessibilityLabel = NSLocalizedString(
            "library.emptyState.accessibilityLabel",
            tableName: "Localizable",
            comment: "Accessibility label for the library empty state"
        )
    }
    
    static let Discover = NSLocalizedString(
        "discover",
        tableName: "Localizable",
        comment: "Title for the discover tab"
    )

    enum DiscoverView {
        static let tabContent = NSLocalizedString(
            "discover.tab.content",
            tableName: "Localizable",
            comment: "Discover tab label for community content"
        )

        static let tabCharters = NSLocalizedString(
            "discover.tab.charters",
            tableName: "Localizable",
            comment: "Discover tab label for charter discovery"
        )

        static let emptyStateTitle = NSLocalizedString(
            "discover.emptyState.title",
            tableName: "Localizable",
            comment: "Title for the discover empty state"
        )

        static let emptyStateMessage = NSLocalizedString(
            "discover.emptyState.message",
            tableName: "Localizable",
            comment: "Message for the discover empty state"
        )
    }

    static let Charters = NSLocalizedString(
        "charters",
        tableName: "Localizable",
        comment: "Title for the charters tab"
    )
    
    static let ProfileTab = NSLocalizedString(
        "profile",
        tableName: "Localizable",
        comment: "Title for the profile tab"
    )
    
    enum Profile {
        static let welcomeTitle = NSLocalizedString(
            "profile.welcomeTitle",
            tableName: "Localizable",
            comment: "Welcome title on profile screen when not signed in"
        )
        
        static let welcomeSubtitle = NSLocalizedString(
            "profile.welcomeSubtitle",
            tableName: "Localizable",
            comment: "Welcome subtitle explaining sign-in on profile screen"
        )
        
        static let signOut = NSLocalizedString(
            "profile.signOut",
            tableName: "Localizable",
            comment: "Sign out button label"
        )
        
        static let signedInAs = NSLocalizedString(
            "profile.signedInAs",
            tableName: "Localizable",
            comment: "Label showing signed in user (e.g., 'Signed in as: username')"
        )

        static let accountTitle = NSLocalizedString(
            "profile.accountTitle",
            tableName: "Localizable",
            comment: "Title for the account settings section"
        )

        static let accountSubtitle = NSLocalizedString(
            "profile.accountSubtitle",
            tableName: "Localizable",
            comment: "Subtitle explaining the account settings section"
        )

        static let getStartedTitle = NSLocalizedString(
            "profile.getStartedTitle",
            tableName: "Localizable",
            comment: "Title for the get started section when not signed in"
        )

        static let getStartedSubtitle = NSLocalizedString(
            "profile.getStartedSubtitle",
            tableName: "Localizable",
            comment: "Subtitle explaining the get started section"
        )

        static let memberSincePrefix = NSLocalizedString(
            "profile.memberSincePrefix",
            tableName: "Localizable",
            comment: "Prefix text for member since date (e.g., 'Member since')"
        )

        // Reputation section
        static let reputationTitle = NSLocalizedString(
            "profile.reputationTitle",
            tableName: "Localizable",
            comment: "Title for the reputation section"
        )

        static let reputationSubtitle = NSLocalizedString(
            "profile.reputationSubtitle",
            tableName: "Localizable",
            comment: "Subtitle for the reputation section"
        )

        // Content ownership section
        static let contentOwnershipTitle = NSLocalizedString(
            "profile.contentOwnershipTitle",
            tableName: "Localizable",
            comment: "Title for the content ownership section"
        )

        static let contentOwnershipSubtitle = NSLocalizedString(
            "profile.contentOwnershipSubtitle",
            tableName: "Localizable",
            comment: "Subtitle for the content ownership section"
        )

        // Verification tiers
        enum VerificationTier {
            static let verificationTierLabel = NSLocalizedString(
                "profile.verificationTierLabel",
                tableName: "Localizable",
                comment: "Label for verification tier display"
            )

            static let new = NSLocalizedString(
                "profile.verificationTier.new",
                tableName: "Localizable",
                comment: "New sailor verification tier name"
            )

            static let contributor = NSLocalizedString(
                "profile.verificationTier.contributor",
                tableName: "Localizable",
                comment: "Contributor verification tier name"
            )

            static let trusted = NSLocalizedString(
                "profile.verificationTier.trusted",
                tableName: "Localizable",
                comment: "Trusted sailor verification tier name"
            )

            static let expert = NSLocalizedString(
                "profile.verificationTier.expert",
                tableName: "Localizable",
                comment: "Expert verification tier name"
            )
        }

        // Metrics labels
        static let contributions = NSLocalizedString(
            "profile.contributions",
            tableName: "Localizable",
            comment: "Label for contributions metric"
        )

        static let communityRating = NSLocalizedString(
            "profile.communityRating",
            tableName: "Localizable",
            comment: "Label for community rating metric"
        )

        static let totalForks = NSLocalizedString(
            "profile.totalForks",
            tableName: "Localizable",
            comment: "Label for total forks metric"
        )

        // Content types
        static let created = NSLocalizedString(
            "profile.created",
            tableName: "Localizable",
            comment: "Label for created content"
        )

        static let forked = NSLocalizedString(
            "profile.forked",
            tableName: "Localizable",
            comment: "Label for forked content"
        )

        static let imported = NSLocalizedString(
            "profile.imported",
            tableName: "Localizable",
            comment: "Label for imported content"
        )

        // Account management
        static let privacySettings = NSLocalizedString(
            "profile.privacySettings",
            tableName: "Localizable",
            comment: "Privacy settings button label"
        )

        static let openPrivacyPolicy = NSLocalizedString(
            "profile.openPrivacyPolicy",
            tableName: "Localizable",
            comment: "Opens the public privacy policy in the browser"
        )

        static let openTermsOfService = NSLocalizedString(
            "profile.openTermsOfService",
            tableName: "Localizable",
            comment: "Opens the public terms of service in the browser"
        )

        static let exportData = NSLocalizedString(
            "profile.exportData",
            tableName: "Localizable",
            comment: "Export data button label"
        )

        static let activityLog = NSLocalizedString(
            "profile.activityLog",
            tableName: "Localizable",
            comment: "Activity log button label"
        )

        static let deleteAccount = NSLocalizedString(
            "profile.deleteAccount",
            tableName: "Localizable",
            comment: "Delete account button label"
        )

        static let deleteAccountSheetTitle = NSLocalizedString(
            "profile.deleteAccountSheetTitle",
            tableName: "Localizable",
            comment: "Title for delete account confirmation sheet"
        )

        static let deleteAccountSheetBody = NSLocalizedString(
            "profile.deleteAccountSheetBody",
            tableName: "Localizable",
            comment: "Explanation of permanent account deletion"
        )

        static let deleteAccountSheetConfirm = NSLocalizedString(
            "profile.deleteAccountSheetConfirm",
            tableName: "Localizable",
            comment: "Confirm delete account button"
        )

        static let deleteAccountSheetCancel = NSLocalizedString(
            "profile.deleteAccountSheetCancel",
            tableName: "Localizable",
            comment: "Cancel delete account"
        )

        static let displayNameTitle = NSLocalizedString(
            "profile.displayNameTitle",
            tableName: "Localizable",
            comment: "Title for display name input field"
        )

        static let displayNamePlaceholder = NSLocalizedString(
            "profile.displayNamePlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for display name input field"
        )
        
        // Profile Image
        enum Image {
            static let upload = NSLocalizedString(
                "profile.image.upload",
                tableName: "Localizable",
                comment: "Upload profile photo button"
            )
            
            static let change = NSLocalizedString(
                "profile.image.change",
                tableName: "Localizable",
                comment: "Change photo button"
            )
            
            static let remove = NSLocalizedString(
                "profile.image.remove",
                tableName: "Localizable",
                comment: "Remove photo button"
            )
            
            static let error = NSLocalizedString(
                "profile.image.error",
                tableName: "Localizable",
                comment: "Image upload error message"
            )
        }
        
        // Bio
        enum Bio {
            static let title = NSLocalizedString(
                "profile.bio.title",
                tableName: "Localizable",
                comment: "Bio section title"
            )
            
            static let placeholder = NSLocalizedString(
                "profile.bio.placeholder",
                tableName: "Localizable",
                comment: "Bio placeholder text"
            )
            
            static func characterLimit(_ count: Int) -> String {
                String(format: NSLocalizedString(
                    "profile.bio.characterLimit",
                    tableName: "Localizable",
                    comment: "Bio character limit counter"
                ), count)
            }
        }
        
        // Location
        enum Location {
            static let title = NSLocalizedString(
                "profile.location.title",
                tableName: "Localizable",
                comment: "Location section title"
            )
            
            static let placeholder = NSLocalizedString(
                "profile.location.placeholder",
                tableName: "Localizable",
                comment: "Location placeholder text"
            )
        }
        
        // Nationality
        enum Nationality {
            static let title = NSLocalizedString(
                "profile.nationality.title",
                tableName: "Localizable",
                comment: "Nationality section title"
            )
            
            static let placeholder = NSLocalizedString(
                "profile.nationality.placeholder",
                tableName: "Localizable",
                comment: "Nationality placeholder text"
            )
        }
        
        // Completion
        enum Completion {
            static func title(_ percentage: Int) -> String {
                String(format: NSLocalizedString(
                    "profile.completion.title",
                    tableName: "Localizable",
                    comment: "Profile completion percentage"
                ), percentage)
            }
            
            static let addPhoto = NSLocalizedString(
                "profile.completion.addPhoto",
                tableName: "Localizable",
                comment: "Add profile photo prompt"
            )
            
            static let addBio = NSLocalizedString(
                "profile.completion.addBio",
                tableName: "Localizable",
                comment: "Add bio prompt"
            )
            
            static let addLocation = NSLocalizedString(
                "profile.completion.addLocation",
                tableName: "Localizable",
                comment: "Add location prompt"
            )
        }

        // Communities
        enum Communities {
            static let title = NSLocalizedString(
                "profile.communities.title",
                tableName: "Localizable",
                comment: "Communities section title"
            )
            static let emptyState = NSLocalizedString(
                "profile.communities.emptyState",
                tableName: "Localizable",
                comment: "Empty state when user has no communities"
            )
            static let setAsPrimary = NSLocalizedString(
                "profile.communities.setAsPrimary",
                tableName: "Localizable",
                comment: "Context menu action to set community as primary"
            )
            static let leave = NSLocalizedString(
                "profile.communities.leave",
                tableName: "Localizable",
                comment: "Context menu action to leave community"
            )
            static let find = NSLocalizedString(
                "profile.communities.find",
                tableName: "Localizable",
                comment: "Button to find and join communities"
            )
        }

        // Community Search
        enum CommunitySearch {
            static let title = NSLocalizedString(
                "profile.communitySearch.title",
                tableName: "Localizable",
                comment: "Community search sheet title"
            )
            static let done = NSLocalizedString(
                "profile.communitySearch.done",
                tableName: "Localizable",
                comment: "Done button to dismiss community search"
            )
            static let placeholder = NSLocalizedString(
                "profile.communitySearch.placeholder",
                tableName: "Localizable",
                comment: "Search field placeholder"
            )
            static let emptyPrompt = NSLocalizedString(
                "profile.communitySearch.emptyPrompt",
                tableName: "Localizable",
                comment: "Prompt when search field is empty"
            )
            static func createCommunity(_ name: String) -> String {
                String(format: NSLocalizedString(
                    "profile.communitySearch.createCommunity",
                    tableName: "Localizable",
                    comment: "Create community row title with name"
                ), name)
            }
            static let startNew = NSLocalizedString(
                "profile.communitySearch.startNew",
                tableName: "Localizable",
                comment: "Subtitle for create community row"
            )
            static let member = NSLocalizedString(
                "profile.communitySearch.member",
                tableName: "Localizable",
                comment: "Singular: 1 member"
            )
            static let members = NSLocalizedString(
                "profile.communitySearch.members",
                tableName: "Localizable",
                comment: "Plural: N members"
            )
            static let open = NSLocalizedString(
                "profile.communitySearch.open",
                tableName: "Localizable",
                comment: "Open community badge"
            )
            static let moderated = NSLocalizedString(
                "profile.communitySearch.moderated",
                tableName: "Localizable",
                comment: "Moderated community badge"
            )
            static let join = NSLocalizedString(
                "profile.communitySearch.join",
                tableName: "Localizable",
                comment: "Join community button"
            )
        }

        // Social Links
        enum SocialLinks {
            enum Platform {
                static let instagram = NSLocalizedString(
                    "profile.socialLinks.platform.instagram",
                    tableName: "Localizable",
                    comment: "Instagram platform name"
                )
                static let telegram = NSLocalizedString(
                    "profile.socialLinks.platform.telegram",
                    tableName: "Localizable",
                    comment: "Telegram platform name"
                )
                static let other = NSLocalizedString(
                    "profile.socialLinks.platform.other",
                    tableName: "Localizable",
                    comment: "Other link platform name"
                )
            }
            static let title = NSLocalizedString(
                "profile.socialLinks.title",
                tableName: "Localizable",
                comment: "Social links section title"
            )
            static let urlPlaceholder = NSLocalizedString(
                "profile.socialLinks.urlPlaceholder",
                tableName: "Localizable",
                comment: "Placeholder for Other social link URL"
            )
            static let usernamePlaceholder = NSLocalizedString(
                "profile.socialLinks.usernamePlaceholder",
                tableName: "Localizable",
                comment: "Placeholder for Instagram/Telegram handle"
            )
        }

        // Edit Form
        enum EditForm {
            static let cancel = NSLocalizedString(
                "profile.editForm.cancel",
                tableName: "Localizable",
                comment: "Cancel edit button"
            )
            static let save = NSLocalizedString(
                "profile.editForm.save",
                tableName: "Localizable",
                comment: "Save edit button"
            )
            static func bioCounter(_ count: Int, limit: Int) -> String {
                String(format: NSLocalizedString(
                    "profile.editForm.bioCounter",
                    tableName: "Localizable",
                    comment: "Bio character counter"
                ), count, limit)
            }
        }

        // Validation
        static let displayNameEmpty = NSLocalizedString(
            "profile.validation.displayNameEmpty",
            tableName: "Localizable",
            comment: "Validation error when display name is empty"
        )

        // Stats
        enum Stats {
            static let dashboardLabel = NSLocalizedString(
                "profile.stats.dashboardLabel",
                tableName: "Localizable",
                comment: "Section label for stats dashboard"
            )
            static let chartersCompleted = NSLocalizedString(
                "profile.stats.chartersCompleted",
                tableName: "Localizable",
                comment: "Charters completed stat label"
            )
            static let nauticalMiles = NSLocalizedString(
                "profile.stats.nauticalMiles",
                tableName: "Localizable",
                comment: "Nautical miles stat label"
            )
            static let daysAtSea = NSLocalizedString(
                "profile.stats.daysAtSea",
                tableName: "Localizable",
                comment: "Days at sea stat label"
            )
            static let communitiesJoined = NSLocalizedString(
                "profile.stats.communitiesJoined",
                tableName: "Localizable",
                comment: "Communities joined stat label"
            )
        }
    }
    
    enum Error {
        // Generic errors
        static let generic = NSLocalizedString(
            "error.generic",
            tableName: "Localizable",
            comment: "Generic error message"
        )
        
        static let notFound = NSLocalizedString(
            "error.notFound",
            tableName: "Localizable",
            comment: "Item not found error"
        )
        
        static let validationFailed = NSLocalizedString(
            "error.validationFailed",
            tableName: "Localizable",
            comment: "Validation failed error"
        )
        
        static let databaseError = NSLocalizedString(
            "error.databaseError",
            tableName: "Localizable",
            comment: "Database error"
        )
        
        // Network errors
        static let networkOffline = NSLocalizedString(
            "error.network.offline",
            tableName: "Localizable",
            comment: "No internet connection error"
        )
        
        static let networkTimedOut = NSLocalizedString(
            "error.network.timedOut",
            tableName: "Localizable",
            comment: "Request timeout error"
        )
        
        static let networkConnectionRefused = NSLocalizedString(
            "error.network.connectionRefused",
            tableName: "Localizable",
            comment: "Server connection refused error"
        )
        
        static let networkUnreachableHost = NSLocalizedString(
            "error.network.unreachableHost",
            tableName: "Localizable",
            comment: "Server unreachable error"
        )
        
        static let networkUnknown = NSLocalizedString(
            "error.network.unknown",
            tableName: "Localizable",
            comment: "Unknown network error"
        )
        
        // Network recovery suggestions
        static let networkOfflineRecovery = NSLocalizedString(
            "error.network.offline.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for offline error"
        )
        
        static let networkTimedOutRecovery = NSLocalizedString(
            "error.network.timedOut.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for timeout error"
        )
        
        static let networkConnectionRefusedRecovery = NSLocalizedString(
            "error.network.connectionRefused.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for connection refused error"
        )
        
        static let networkUnreachableHostRecovery = NSLocalizedString(
            "error.network.unreachableHost.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for unreachable host error"
        )
        
        static let networkUnknownRecovery = NSLocalizedString(
            "error.network.unknown.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for unknown network error"
        )
        
        // Authentication errors
        static let authInvalidToken = NSLocalizedString(
            "error.auth.invalidToken",
            tableName: "Localizable",
            comment: "Invalid authentication token error"
        )
        
        static let authNetworkError = NSLocalizedString(
            "error.auth.networkError",
            tableName: "Localizable",
            comment: "Authentication network error"
        )
        
        static let authInvalidResponse = NSLocalizedString(
            "error.auth.invalidResponse",
            tableName: "Localizable",
            comment: "Invalid server response error"
        )
        
        static let authUnauthorized = NSLocalizedString(
            "error.auth.unauthorized",
            tableName: "Localizable",
            comment: "Unauthorized access error"
        )
        
        // Authentication recovery suggestions
        static let authInvalidTokenRecovery = NSLocalizedString(
            "error.auth.invalidToken.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for invalid token"
        )
        
        static let authNetworkErrorRecovery = NSLocalizedString(
            "error.auth.networkError.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for auth network error"
        )
        
        static let authInvalidResponseRecovery = NSLocalizedString(
            "error.auth.invalidResponse.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for invalid response"
        )
        
        static let authUnauthorizedRecovery = NSLocalizedString(
            "error.auth.unauthorized.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for unauthorized error"
        )
        
        // General recovery suggestions
        static let notFoundRecovery = NSLocalizedString(
            "error.notFound.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for not found error"
        )
        
        static let validationFailedRecovery = NSLocalizedString(
            "error.validationFailed.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for validation failed error"
        )
        
        static let databaseErrorRecovery = NSLocalizedString(
            "error.databaseError.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for database error"
        )
        
        static let unknownRecovery = NSLocalizedString(
            "error.unknown.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for unknown error"
        )

        // Library-specific errors
        static let libraryNotFound = NSLocalizedString(
            "error.library.notFound",
            tableName: "Localizable",
            comment: "Library content not found error"
        )

        static let librarySyncFailed = NSLocalizedString(
            "error.library.syncFailed",
            tableName: "Localizable",
            comment: "Library sync failed error"
        )

        static let libraryInvalidContent = NSLocalizedString(
            "error.libraryInvalidContent",
            tableName: "Localizable",
            comment: "Invalid content data error"
        )

        static let libraryNotFoundRecovery = NSLocalizedString(
            "error.library.notFound.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for library not found error"
        )

        static let librarySyncFailedRecovery = NSLocalizedString(
            "error.library.syncFailed.recovery",
            tableName: "Localizable",
            comment: "Recovery suggestion for library sync failed error"
        )

        static let genericRecovery = NSLocalizedString(
            "error.generic.recovery",
            tableName: "Localizable",
            comment: "Generic recovery suggestion"
        )
    }
    
    static let homeCreateCharterTitle = NSLocalizedString(
        "home.createCharter.title",
        tableName: "Localizable",
        comment: "Title for the create charter card on the home screen"
    )
    
    static let homeCreateCharterSubtitle = NSLocalizedString(
        "home.createCharter.subtitle",
        tableName: "Localizable",
        comment: "Subtitle explaining the create charter action"
    )
    
    static let homeCreateCharterAction = NSLocalizedString(
        "home.createCharter.action",
        tableName: "Localizable",
        comment: "Primary action button label for starting a charter"
    )

    static let charterCreateProgress = NSLocalizedString(
        "charter.create.progress",
        tableName: "Localizable",
        comment: "Progress label for the create charter form"
    )
    
    static let charterCreateName = NSLocalizedString(
        "charter.create.name",
        tableName: "Localizable",
        comment: "Title for the charter name field in the create charter form"
    )
    
    static let charterCreateNamePlaceholder = NSLocalizedString(
        "charter.create.namePlaceholder",
        tableName: "Localizable",
        comment: "Placeholder for the charter name input field in the create charter form"
    )
    
    static let charterCreateNameHelper = NSLocalizedString(
        "charter.create.nameHelper",
        tableName: "Localizable",
        comment: "Helper text for the charter name field in the create charter form"
    )

    static let charterCreateWhenWillYouSail = NSLocalizedString(
        "charter.create.whenWillYouSail",
        tableName: "Localizable",
        comment: "Title for the when will you sail section in the create charter form"
    )
    
    static let charterCreateChooseYourVoyageDates = NSLocalizedString(
        "charter.create.chooseYourVoyageDates",
        tableName: "Localizable",
        comment: "Subtitle for the choose your voyage dates section in the create charter form"
    )

    static let charterCreateDestination = NSLocalizedString(
        "charter.create.destination",
        tableName: "Localizable",
        comment: "Title for the destination section in the create charter form"
    )
    
    static let charterCreateChooseWhereYouWillSail = NSLocalizedString(
        "charter.create.chooseWhereYouWillSail",
        tableName: "Localizable",
        comment: "Subtitle for the choose where you will sail section in the create charter form"
    )
    
    static let charterCreateYourVessel = NSLocalizedString(
        "charter.create.yourVessel",
        tableName: "Localizable",
        comment: "Title for the your vessel section in the create charter form"
    )
    
    static let charterCreatePickTheCharacterOfYourJourney = NSLocalizedString(
        "charter.create.pickTheCharacterOfYourJourney",
        tableName: "Localizable",
        comment: "Subtitle for the pick the character of your journey section in the create charter form"
    )
    
    static let charterCreateGuests = NSLocalizedString(
        "charter.create.guests",
        tableName: "Localizable",
        comment: "Title for the guests section in the create charter form"
    )
    
    static let charterCreateWhoIsJoiningTheTrip = NSLocalizedString(
        "charter.create.whoIsJoiningTheTrip",
        tableName: "Localizable",
        comment: "Subtitle for the who is joining the trip section in the create charter form"
    )
    
    static let charterCreateBudget = NSLocalizedString(
        "charter.create.budget",
        tableName: "Localizable",
        comment: "Title for the budget section in the create charter form"
    )
    
    static let charterCreateOptionalBudgetRange = NSLocalizedString(
        "charter.create.optionalBudgetRange",
        tableName: "Localizable",
        comment: "Subtitle for the optional budget range section in the create charter form"
    )
    
    static let charterCreateSetSailOnYourNextAdventure = NSLocalizedString(
        "charter.create.setSailOnYourNextAdventure",
        tableName: "Localizable",
        comment: "Title for the set sail on your next adventure section in the create charter form"
    )
    
    static let charterCreateFromDreamToRealityInAFewGuidedSteps = NSLocalizedString(
        "charter.create.fromDreamToRealityInAFewGuidedSteps",
        tableName: "Localizable",
        comment: "Subtitle for the from dream to reality in a few guided steps section in the create charter form"
    )
    
    static let charterCreateYourAdventureAwaits = NSLocalizedString(
        "charter.create.yourAdventureAwaits",
        tableName: "Localizable",
        comment: "Title for the your adventure awaits section in the create charter form"
    )
    
    static let charterCreateReviewYourCharterPlan = NSLocalizedString(
        "charter.create.reviewYourCharterPlan",
        tableName: "Localizable",
        comment: "Subtitle for the review your charter plan section in the create charter form"
    )
    
    static let charterCreateDates = NSLocalizedString(
        "charter.create.dates",
        tableName: "Localizable",
        comment: "Title for the dates section in the create charter form"
    )
    
    static let charterCreateRegion = NSLocalizedString(
        "charter.create.region",
        tableName: "Localizable",
        comment: "Title for the region section in the create charter form"
    )
    
    static let charterCreateSelectARegion = NSLocalizedString(
        "charter.create.selectARegion",
        tableName: "Localizable",
        comment: "Subtitle for the select a region section in the create charter form"
    )
    
    static let charterCreateVessel = NSLocalizedString(
        "charter.create.vessel",
        tableName: "Localizable",
        comment: "Title for the vessel section in the create charter form"
    )
    
    static let charterCreateUpToGuests = NSLocalizedString(
        "charter.create.upToGuests",
        tableName: "Localizable",
        comment: "Subtitle for the up to guests section in the create charter form"
    )
    
    static let charterCreateCrew = NSLocalizedString(
        "charter.create.crew",
        tableName: "Localizable",
        comment: "Title for the crew section in the create charter form"
    )
    
    static let charterCreateCaptainAndOptionsSelected = NSLocalizedString(
        "charter.create.captainAndOptionsSelected",
        tableName: "Localizable",
        comment: "Subtitle for the captain and options selected section in the create charter form"
    )
    
    static let charterCreateCreateCharter = NSLocalizedString(
        "charter.create.createCharter",
        tableName: "Localizable",
        comment: "Title for the create charter button in the create charter form"
    )
    
    static let charterCreateStep = NSLocalizedString(
        "charter.create.step",
        tableName: "Localizable",
        comment: "Title for the step section in the create charter form"
    )
    
    static let charterCreateReadyToLockInYourPlan = NSLocalizedString(
        "charter.create.readyToLockInYourPlan",
        tableName: "Localizable",
        comment: "Subtitle for the ready to lock in your plan section in the create charter form"
    )

    static let charterCreateFrom = NSLocalizedString(
        "charter.create.from",
        tableName: "Localizable",
        comment: "Title for the from section in the create charter form"
    )
    
    static let charterCreateTo = NSLocalizedString(
        "charter.create.to",
        tableName: "Localizable",
        comment: "Title for the to section in the create charter form"
    )
    
    static let charterCreateStartDate = NSLocalizedString(
        "charter.create.startDate",
        tableName: "Localizable",
        comment: "Title for the start date section in the create charter form"
    )
    
    static let charterCreateEndDate = NSLocalizedString(
        "charter.create.endDate",
        tableName: "Localizable",
        comment: "Title for the end date section in the create charter form"
    )

    static let charterCreateNights = NSLocalizedString(
        "charter.create.nights",
        tableName: "Localizable",
        comment: "Title for the nights section in the create charter form"
    )

    static let charterCreateVesselNamePlaceholder = NSLocalizedString(
        "charter.create.vesselNamePlaceholder",
        tableName: "Localizable",
        comment: "Placeholder for the vessel name input field in the create charter form"
    )

    static let charterSummaryYourAdventureAwaits = NSLocalizedString(
        "charter.summary.yourAdventureAwaits",
        tableName: "Localizable",
        comment: "Title for the your adventure awaits section in the charter summary card"
    )
    
    static let charterSummaryReviewYourCharterPlan = NSLocalizedString(
        "charter.summary.reviewYourCharterPlan",
        tableName: "Localizable",
        comment: "Subtitle for the review your charter plan section in the charter summary card"
    )
    
    static let charterSummaryDates = NSLocalizedString(
        "charter.summary.dates",
        tableName: "Localizable",
        comment: "Title for the dates section in the charter summary card"
    )
    
    static let charterSummaryRegion = NSLocalizedString(
        "charter.summary.region",
        tableName: "Localizable",
        comment: "Title for the region section in the charter summary card"
    )
    
    static let charterSummaryVessel = NSLocalizedString(
        "charter.summary.vessel",
        tableName: "Localizable",
        comment: "Title for the vessel section in the charter summary card"
    )
    
    static let charterSummaryCrew = NSLocalizedString(
        "charter.summary.crew",
        tableName: "Localizable",
        comment: "Title for the crew section in the charter summary card"
    )
    
    static let charterSummaryBudget = NSLocalizedString(
        "charter.summary.budget",
        tableName: "Localizable",
        comment: "Title for the budget section in the charter summary card"
    )
    
    static let charterSummaryReadyToLockInYourPlan = NSLocalizedString(
        "charter.summary.readyToLockInYourPlan",
        tableName: "Localizable",
        comment: "Subtitle for the ready to lock in your plan section in the charter summary card"
    )
    
    static let charterSummaryCreateCharter = NSLocalizedString(
        "charter.summary.createCharter",
        tableName: "Localizable",
        comment: "Title for the create charter button in the charter summary card"
    )
    
    static let charterSummaryStep = NSLocalizedString(
        "charter.summary.step",
        tableName: "Localizable",
        comment: "Title for the step section in the charter summary card"
    )

    static let charterSummarySelectARegion = NSLocalizedString(
        "charter.summary.selectARegion",
        tableName: "Localizable",
        comment: "Subtitle for the select a region section in the charter summary card"
    )

    static let charterSummaryUpToGuests = NSLocalizedString(
        "charter.summary.upToGuests",
        tableName: "Localizable",
        comment: "Subtitle for the up to guests section in the charter summary card"
    )

    static let charterSummaryCaptainAndOptionsSelected = NSLocalizedString(
        "charter.summary.captainAndOptionsSelected",
        tableName: "Localizable",
        comment: "Subtitle for the captain and options selected section in the charter summary card"
    )

    static let charterSummaryNights = NSLocalizedString(
        "charter.summary.nights",
        tableName: "Localizable",
        comment: "Title for the nights section in the charter summary card"
    )

    static let charterSummaryUpto = NSLocalizedString(
        "charter.summary.upto",
        tableName: "Localizable",
        comment: "Title for the upto section in the charter summary card"
    )

    static let charterSummaryOf = NSLocalizedString(
        "charter.summary.of",
        tableName: "Localizable",
        comment: "Title for the of section in the charter summary card"
    )

    static let homeActiveCharterTitle = NSLocalizedString(
        "charter.activeCharter",
        tableName: "Localizable",
        comment: "Label for the active charter badge on the home screen"
    )
    
    static let homePinnedContentTitle = NSLocalizedString(
        "home.pinnedContent.title",
        tableName: "Localizable",
        comment: "Section title for pinned content on the home screen"
    )
    
    static let homePinnedContentSubtitle = NSLocalizedString(
        "home.pinnedContent.subtitle",
        tableName: "Localizable",
        comment: "Section subtitle explaining pinned content on the home screen"
    )

    static let homeNextCharterTitle = NSLocalizedString(
        "home.nextCharter.title",
        tableName: "Localizable",
        comment: "Label for the next charter badge on the home screen hero card"
    )

    static let homeUpcomingTripsTitle = NSLocalizedString(
        "home.upcomingTrips.title",
        tableName: "Localizable",
        comment: "Section title for upcoming charters strip on the home screen"
    )

    static let homeViewCharter = NSLocalizedString(
        "home.viewCharter",
        tableName: "Localizable",
        comment: "Button label to view charter details"
    )

    static func homeInDays(_ count: Int) -> String {
        String(format: NSLocalizedString("home.inDays", tableName: "Localizable", comment: "Charter starts in X days"), count)
    }

    static let homeNextMonth = NSLocalizedString(
        "home.nextMonth",
        tableName: "Localizable",
        comment: "Charter starts next month"
    )
    
    enum ChecklistEditor {
        static let newChecklist = NSLocalizedString(
            "checklistEditor.newChecklist",
            tableName: "Localizable",
            comment: "Navigation title for creating a new checklist"
        )
        
        static let editChecklist = NSLocalizedString(
            "checklistEditor.editChecklist",
            tableName: "Localizable",
            comment: "Navigation title for editing an existing checklist"
        )
        
        static let save = NSLocalizedString(
            "checklistEditor.save",
            tableName: "Localizable",
            comment: "Save button label"
        )
        
        static let error = NSLocalizedString(
            "checklistEditor.error",
            tableName: "Localizable",
            comment: "Error alert title"
        )
        
        static let ok = NSLocalizedString(
            "checklistEditor.ok",
            tableName: "Localizable",
            comment: "OK button label"
        )
        
        static let title = NSLocalizedString(
            "checklistEditor.title",
            tableName: "Localizable",
            comment: "Title field label"
        )
        
        static let checklistNamePlaceholder = NSLocalizedString(
            "checklistEditor.checklistNamePlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for checklist name input field"
        )
        
        static let description = NSLocalizedString(
            "checklistEditor.description",
            tableName: "Localizable",
            comment: "Description field label"
        )
        
        static let descriptionPlaceholder = NSLocalizedString(
            "checklistEditor.descriptionPlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for checklist description input field"
        )
        
        static let checklistType = NSLocalizedString(
            "checklistEditor.checklistType",
            tableName: "Localizable",
            comment: "Checklist type field label"
        )
        
        static let sections = NSLocalizedString(
            "checklistEditor.sections",
            tableName: "Localizable",
            comment: "Sections stat label"
        )
        
        static let items = NSLocalizedString(
            "checklistEditor.items",
            tableName: "Localizable",
            comment: "Items stat label"
        )
        
        static let addSection = NSLocalizedString(
            "checklistEditor.addSection",
            tableName: "Localizable",
            comment: "Add section button label"
        )
        
        static let addItem = NSLocalizedString(
            "checklistEditor.addItem",
            tableName: "Localizable",
            comment: "Add item button label"
        )
        
        static let delete = NSLocalizedString(
            "checklistEditor.delete",
            tableName: "Localizable",
            comment: "Delete button label"
        )
    }
    
    enum ItemEditor {
        static let newItem = NSLocalizedString(
            "itemEditor.newItem",
            tableName: "Localizable",
            comment: "Navigation title for creating a new item"
        )
        
        static let editItem = NSLocalizedString(
            "itemEditor.editItem",
            tableName: "Localizable",
            comment: "Navigation title for editing an existing item"
        )
        
        static let itemTitle = NSLocalizedString(
            "itemEditor.itemTitle",
            tableName: "Localizable",
            comment: "Item title field label"
        )
        
        static let itemNamePlaceholder = NSLocalizedString(
            "itemEditor.itemNamePlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for item name input field"
        )
        
        static let description = NSLocalizedString(
            "itemEditor.description",
            tableName: "Localizable",
            comment: "Description field label"
        )
        
        static let optional = NSLocalizedString(
            "itemEditor.optional",
            tableName: "Localizable",
            comment: "Optional label"
        )
        
        static let itemDescriptionPlaceholder = NSLocalizedString(
            "itemEditor.itemDescriptionPlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for item description input field"
        )
        
        static let importance = NSLocalizedString(
            "itemEditor.importance",
            tableName: "Localizable",
            comment: "Importance section label"
        )
        
        static let required = NSLocalizedString(
            "itemEditor.required",
            tableName: "Localizable",
            comment: "Required toggle label"
        )
        
        static let requiredDescription = NSLocalizedString(
            "itemEditor.requiredDescription",
            tableName: "Localizable",
            comment: "Required toggle description"
        )
        
        static let optionalDescription = NSLocalizedString(
            "itemEditor.optionalDescription",
            tableName: "Localizable",
            comment: "Optional toggle description"
        )
        
        static let estimatedTime = NSLocalizedString(
            "itemEditor.estimatedTime",
            tableName: "Localizable",
            comment: "Estimated time field label"
        )
        
        static let minutesPlaceholder = NSLocalizedString(
            "itemEditor.minutesPlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for minutes input field"
        )
        
        static let deleteItem = NSLocalizedString(
            "itemEditor.deleteItem",
            tableName: "Localizable",
            comment: "Delete item button label"
        )
        
        static let cancel = NSLocalizedString(
            "itemEditor.cancel",
            tableName: "Localizable",
            comment: "Cancel button label"
        )
        
        static let save = NSLocalizedString(
            "itemEditor.save",
            tableName: "Localizable",
            comment: "Save button label"
        )
        
        static let deleteItemAlert = NSLocalizedString(
            "itemEditor.deleteItemAlert",
            tableName: "Localizable",
            comment: "Delete item alert title"
        )
        
        static let deleteItemMessage = NSLocalizedString(
            "itemEditor.deleteItemMessage",
            tableName: "Localizable",
            comment: "Delete item alert message"
        )
        
        static let delete = NSLocalizedString(
            "itemEditor.delete",
            tableName: "Localizable",
            comment: "Delete button label in alert"
        )
    }
    
    enum SectionEditor {
        static let newSection = NSLocalizedString(
            "sectionEditor.newSection",
            tableName: "Localizable",
            comment: "Navigation title for creating a new section"
        )
        
        static let editSection = NSLocalizedString(
            "sectionEditor.editSection",
            tableName: "Localizable",
            comment: "Navigation title for editing an existing section"
        )
        
        static let sectionTitle = NSLocalizedString(
            "sectionEditor.sectionTitle",
            tableName: "Localizable",
            comment: "Section title field label"
        )
        
        static let sectionNamePlaceholder = NSLocalizedString(
            "sectionEditor.sectionNamePlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for section name input field"
        )
        
        static let icon = NSLocalizedString(
            "sectionEditor.icon",
            tableName: "Localizable",
            comment: "Icon field label"
        )
        
        static let optional = NSLocalizedString(
            "sectionEditor.optional",
            tableName: "Localizable",
            comment: "Optional label"
        )
        
        static let changeIcon = NSLocalizedString(
            "sectionEditor.changeIcon",
            tableName: "Localizable",
            comment: "Change icon button label"
        )
        
        static let chooseIcon = NSLocalizedString(
            "sectionEditor.chooseIcon",
            tableName: "Localizable",
            comment: "Choose icon button label"
        )
        
        static let description = NSLocalizedString(
            "sectionEditor.description",
            tableName: "Localizable",
            comment: "Description field label"
        )
        
        static let sectionDescriptionPlaceholder = NSLocalizedString(
            "sectionEditor.sectionDescriptionPlaceholder",
            tableName: "Localizable",
            comment: "Placeholder for section description input field"
        )
        
        static let options = NSLocalizedString(
            "sectionEditor.options",
            tableName: "Localizable",
            comment: "Options section label"
        )
        
        static let expandedByDefault = NSLocalizedString(
            "sectionEditor.expandedByDefault",
            tableName: "Localizable",
            comment: "Expanded by default toggle label"
        )
        
        static let expandedByDefaultDescription = NSLocalizedString(
            "sectionEditor.expandedByDefaultDescription",
            tableName: "Localizable",
            comment: "Expanded by default toggle description"
        )
        
        static let deleteSection = NSLocalizedString(
            "sectionEditor.deleteSection",
            tableName: "Localizable",
            comment: "Delete section button label"
        )
        
        static let cancel = NSLocalizedString(
            "sectionEditor.cancel",
            tableName: "Localizable",
            comment: "Cancel button label"
        )
        
        static let save = NSLocalizedString(
            "sectionEditor.save",
            tableName: "Localizable",
            comment: "Save button label"
        )
        
        static let deleteSectionAlert = NSLocalizedString(
            "sectionEditor.deleteSectionAlert",
            tableName: "Localizable",
            comment: "Delete section alert title"
        )
        
        static let deleteSectionMessage = NSLocalizedString(
            "sectionEditor.deleteSectionMessage",
            tableName: "Localizable",
            comment: "Delete section alert message"
        )
        
        static let delete = NSLocalizedString(
            "sectionEditor.delete",
            tableName: "Localizable",
            comment: "Delete button label in alert"
        )
        
        static let chooseIconTitle = NSLocalizedString(
            "sectionEditor.chooseIconTitle",
            tableName: "Localizable",
            comment: "Icon picker navigation title"
        )
        
        static let done = NSLocalizedString(
            "sectionEditor.done",
            tableName: "Localizable",
            comment: "Done button label"
        )
        
        static let none = NSLocalizedString(
            "sectionEditor.none",
            tableName: "Localizable",
            comment: "None option label in icon picker"
        )
    }

    enum Charter {
        static let newCharter = NSLocalizedString(
            "charter.newCharter",
            tableName: "Localizable",
            comment: "Label for creating a new charter"
        )

        enum List {
            static let sectionUpcoming = NSLocalizedString(
                "charter.list.sectionUpcoming",
                tableName: "Localizable",
                comment: "Section header for upcoming charters"
            )
            static func sectionPastWithCount(_ count: Int) -> String {
                String(format: NSLocalizedString(
                    "charter.list.sectionPastWithCount",
                    tableName: "Localizable",
                    comment: "Section header for past charters; %d = count"
                ), count)
            }
            static let actionDelete = NSLocalizedString(
                "charter.list.actionDelete",
                tableName: "Localizable",
                comment: "Swipe action: delete charter"
            )
            static let actionEdit = NSLocalizedString(
                "charter.list.actionEdit",
                tableName: "Localizable",
                comment: "Swipe action: edit charter"
            )
            static let signInToSyncBanner = NSLocalizedString(
                "charter.list.signInToSyncBanner",
                tableName: "Localizable",
                comment: "Banner text when user needs to sign in to sync charters"
            )

            enum EmptyState {
                static let title = NSLocalizedString(
                    "charter.list.emptyState.title",
                    tableName: "Localizable",
                    comment: "Title for empty charter list"
                )
                static let message = NSLocalizedString(
                    "charter.list.emptyState.message",
                    tableName: "Localizable",
                    comment: "Message explaining how to create first charter"
                )
                static let action = NSLocalizedString(
                    "charter.list.emptyState.action",
                    tableName: "Localizable",
                    comment: "Button label to create first charter"
                )
                static let accessibilityLabel = NSLocalizedString(
                    "charter.list.emptyState.accessibilityLabel",
                    tableName: "Localizable",
                    comment: "Accessibility label for empty charter list"
                )
            }
        }

        static let detailTitle = NSLocalizedString(
            "charter.detail.title",
            tableName: "Localizable",
            comment: "Navigation title for charter detail view"
        )

        /// Strings for the redesigned charter detail screen (hero, stats row, sections, FAB).
        enum Detail {
            enum Status {
                static let upcoming = NSLocalizedString(
                    "charter.detail.status.upcoming",
                    tableName: "Localizable",
                    comment: "Lifecycle pill: charter has not started"
                )
                static let active = NSLocalizedString(
                    "charter.detail.status.active",
                    tableName: "Localizable",
                    comment: "Lifecycle pill: charter in progress"
                )
                static let completed = NSLocalizedString(
                    "charter.detail.status.completed",
                    tableName: "Localizable",
                    comment: "Lifecycle pill: charter ended"
                )
            }

            enum Stats {
                static let done = NSLocalizedString(
                    "charter.detail.stats.done",
                    tableName: "Localizable",
                    comment: "Stat value when voyage is completed"
                )
                static let voyage = NSLocalizedString(
                    "charter.detail.stats.voyage",
                    tableName: "Localizable",
                    comment: "Stat label under Done for completed voyage"
                )
                static func dayNumber(_ day: Int) -> String {
                    String(format: NSLocalizedString(
                        "charter.detail.stats.dayNumber",
                        tableName: "Localizable",
                        comment: "Stat value: Day N of active charter"
                    ), day)
                }
                static func ofDays(_ total: Int) -> String {
                    String(format: NSLocalizedString(
                        "charter.detail.stats.ofDays",
                        tableName: "Localizable",
                        comment: "Stat label: of N total days"
                    ), total)
                }
                static let today = NSLocalizedString(
                    "charter.detail.stats.today",
                    tableName: "Localizable",
                    comment: "Stat value when departure is today"
                )
                static let departure = NSLocalizedString(
                    "charter.detail.stats.departure",
                    tableName: "Localizable",
                    comment: "Stat label when departure is today"
                )
                static let daysAway = NSLocalizedString(
                    "charter.detail.stats.daysAway",
                    tableName: "Localizable",
                    comment: "Stat label: countdown until departure"
                )
                static let day = NSLocalizedString(
                    "charter.detail.stats.day",
                    tableName: "Localizable",
                    comment: "Duration stat label singular"
                )
                static let days = NSLocalizedString(
                    "charter.detail.stats.days",
                    tableName: "Localizable",
                    comment: "Duration stat label plural"
                )
                static let destination = NSLocalizedString(
                    "charter.detail.stats.destination",
                    tableName: "Localizable",
                    comment: "Stat label for destination name in stats row"
                )
            }

            static let voyageSectionLabel = NSLocalizedString(
                "charter.detail.section.voyageDetails",
                tableName: "Localizable",
                comment: "BubbleCard section title for dates and destination"
            )
            static let rowDates = NSLocalizedString(
                "charter.detail.row.dates",
                tableName: "Localizable",
                comment: "Detail row label for charter dates"
            )
            static let rowDestination = NSLocalizedString(
                "charter.detail.row.destination",
                tableName: "Localizable",
                comment: "Detail row label for destination"
            )
            static func durationBadge(days: Int) -> String {
                if days == 1 {
                    return NSLocalizedString(
                        "charter.detail.duration.oneDay",
                        tableName: "Localizable",
                        comment: "Duration badge for exactly one day"
                    )
                }
                return String(format: NSLocalizedString(
                    "charter.detail.duration.days",
                    tableName: "Localizable",
                    comment: "Duration badge for N days"
                ), days)
            }

            enum FAB {
                static let viewVoyageLog = NSLocalizedString(
                    "charter.detail.fab.viewVoyageLog",
                    tableName: "Localizable",
                    comment: "Primary action when charter is completed"
                )
                static let openChecklist = NSLocalizedString(
                    "charter.detail.fab.openChecklist",
                    tableName: "Localizable",
                    comment: "Primary action when charter is active"
                )
                static let editCharter = NSLocalizedString(
                    "charter.detail.fab.editCharter",
                    tableName: "Localizable",
                    comment: "Primary action when charter is upcoming or no checklist"
                )
            }
        }

        // MARK: - Editor

        enum Editor {
            static let newTitle = NSLocalizedString(
                "charter.editor.newTitle",
                tableName: "Localizable",
                comment: "Navigation title when creating a new charter"
            )

            static let editTitle = NSLocalizedString(
                "charter.editor.editTitle",
                tableName: "Localizable",
                comment: "Navigation title when editing an existing charter"
            )

            static let visibilityTitle = NSLocalizedString(
                "charter.editor.visibility.title",
                tableName: "Localizable",
                comment: "Section title for the charter visibility picker"
            )

            static let visibilitySubtitle = NSLocalizedString(
                "charter.editor.visibility.subtitle",
                tableName: "Localizable",
                comment: "Section subtitle explaining the visibility picker"
            )

            static let visibilityChangeNote = NSLocalizedString(
                "charter.editor.visibility.changeNote",
                tableName: "Localizable",
                comment: "Info note that visibility can be changed later"
            )

            static let draftsSavedNote = NSLocalizedString(
                "charter.editor.draftsSavedNote",
                tableName: "Localizable",
                comment: "Note below create button that drafts are saved automatically"
            )

            static let back = NSLocalizedString(
                "charter.editor.back",
                tableName: "Localizable",
                comment: "Back button in charter editor"
            )

            static let saveTitle = NSLocalizedString(
                "charter.editor.saveTitle",
                tableName: "Localizable",
                comment: "Save button when editing charter"
            )

            enum PublishingAs {
                static let title = NSLocalizedString(
                    "charter.editor.publishingAs.title",
                    tableName: "Localizable",
                    comment: "Section title for publish-on-behalf picker"
                )
                static let yourself = NSLocalizedString(
                    "charter.editor.publishingAs.yourself",
                    tableName: "Localizable",
                    comment: "Option: publishing as the signed-in user"
                )
                static let yourselfSubtitle = NSLocalizedString(
                    "charter.editor.publishingAs.yourselfSubtitle",
                    tableName: "Localizable",
                    comment: "Subtitle under yourself option"
                )
                static let pickerTitle = NSLocalizedString(
                    "charter.editor.publishingAs.pickerTitle",
                    tableName: "Localizable",
                    comment: "Navigation title for virtual captain picker sheet"
                )
            }
        }

        // MARK: - Visibility options

        enum Visibility {
            enum Private {
                static let name = NSLocalizedString(
                    "charter.visibility.private.name",
                    tableName: "Localizable",
                    comment: "Display name for private visibility option"
                )
                static let description = NSLocalizedString(
                    "charter.visibility.private.description",
                    tableName: "Localizable",
                    comment: "Description of private visibility"
                )
            }
            enum Community {
                static let name = NSLocalizedString(
                    "charter.visibility.community.name",
                    tableName: "Localizable",
                    comment: "Display name for community visibility option"
                )
                static let description = NSLocalizedString(
                    "charter.visibility.community.description",
                    tableName: "Localizable",
                    comment: "Description of community visibility"
                )
            }
            enum Public {
                static let name = NSLocalizedString(
                    "charter.visibility.public.name",
                    tableName: "Localizable",
                    comment: "Display name for public visibility option"
                )
                static let description = NSLocalizedString(
                    "charter.visibility.public.description",
                    tableName: "Localizable",
                    comment: "Description of public visibility"
                )
            }
        }

        // MARK: - Discovery feed

        enum Discovery {
            static let title = NSLocalizedString(
                "charter.discovery.title",
                tableName: "Localizable",
                comment: "Navigation title for the charter discovery screen"
            )
            static let loadMore = NSLocalizedString(
                "charter.discovery.loadMore",
                tableName: "Localizable",
                comment: "Load more charters button"
            )
            static let loading = NSLocalizedString(
                "charter.discovery.loading",
                tableName: "Localizable",
                comment: "Loading indicator text while fetching charters"
            )
            static let clearAll = NSLocalizedString(
                "charter.discovery.clearAll",
                tableName: "Localizable",
                comment: "Clear all active filters"
            )
            static let clearFilters = NSLocalizedString(
                "charter.discovery.clearFilters",
                tableName: "Localizable",
                comment: "Clear filters button in empty state"
            )
            static let captainFallback = NSLocalizedString(
                "charter.discovery.captainFallback",
                tableName: "Localizable",
                comment: "Fallback label when captain username is unknown"
            )
            static let anonymousCaptain = NSLocalizedString(
                "charter.discovery.anonymousCaptain",
                tableName: "Localizable",
                comment: "Placeholder name when captain is anonymous"
            )
            static let charterHost = NSLocalizedString(
                "charter.discovery.charterHost",
                tableName: "Localizable",
                comment: "Role label shown under captain's name in detail view"
            )
            static let virtualCaptainBadge = NSLocalizedString(
                "charter.discovery.virtualCaptainBadge",
                tableName: "Localizable",
                comment: "Short label when the host is a virtual captain"
            )
            static let mapCommunityFallback = NSLocalizedString(
                "charter.discovery.mapCommunityFallback",
                tableName: "Localizable",
                comment: "Label when a charter has a community badge but no community name from the API"
            )
            static let mapEmptyTitle = NSLocalizedString(
                "charter.discovery.mapEmptyTitle",
                tableName: "Localizable",
                comment: "Title when no discoverable charters appear on the map"
            )
            static let mapEmptySubtitle = NSLocalizedString(
                "charter.discovery.mapEmptySubtitle",
                tableName: "Localizable",
                comment: "Subtitle suggesting filter or zoom changes when the map has no pins"
            )
            static let mapCalloutSwipeHint = NSLocalizedString(
                "charter.discovery.mapCalloutSwipeHint",
                tableName: "Localizable",
                comment: "VoiceOver hint for map charter card: swipe up opens detail"
            )
            static let sectionCaptain = NSLocalizedString(
                "charter.discovery.sectionCaptain",
                tableName: "Localizable",
                comment: "Section header label for the captain block"
            )
            static let sectionCharterDetails = NSLocalizedString(
                "charter.discovery.sectionCharterDetails",
                tableName: "Localizable",
                comment: "Section header for charter info rows"
            )
            static let fieldName = NSLocalizedString(
                "charter.discovery.fieldName",
                tableName: "Localizable",
                comment: "Info row label for charter name"
            )
            static let fieldDates = NSLocalizedString(
                "charter.discovery.fieldDates",
                tableName: "Localizable",
                comment: "Info row label for charter dates"
            )
            static let fieldDuration = NSLocalizedString(
                "charter.discovery.fieldDuration",
                tableName: "Localizable",
                comment: "Info row label for charter duration"
            )
            static let fieldVessel = NSLocalizedString(
                "charter.discovery.fieldVessel",
                tableName: "Localizable",
                comment: "Info row label for vessel name"
            )
            static let fieldDestination = NSLocalizedString(
                "charter.discovery.fieldDestination",
                tableName: "Localizable",
                comment: "Info row label for destination"
            )
            static let fieldDistance = NSLocalizedString(
                "charter.discovery.fieldDistance",
                tableName: "Localizable",
                comment: "Info row label for distance"
            )
            static let sectionDestination = NSLocalizedString(
                "charter.discovery.sectionDestination",
                tableName: "Localizable",
                comment: "Map section header label"
            )

            static func kmAway(_ km: Int) -> String {
                String(format: NSLocalizedString(
                    "charter.discovery.kmAway",
                    tableName: "Localizable",
                    comment: "Distance label, %d = kilometres"
                ), km)
            }

            static func durationDays(_ count: Int) -> String {
                let key = count == 1
                    ? "charter.discovery.duration.day"
                    : "charter.discovery.duration.days"
                return String(format: NSLocalizedString(
                    key,
                    tableName: "Localizable",
                    comment: "Charter duration, %d = number of days"
                ), count)
            }

            // MARK: Empty states

            static let emptyTitle = NSLocalizedString(
                "charter.discovery.emptyTitle",
                tableName: "Localizable",
                comment: "Title for the empty charter discovery list"
            )
            static let emptyFiltered = NSLocalizedString(
                "charter.discovery.emptyFiltered",
                tableName: "Localizable",
                comment: "Empty state message when filters return no results"
            )
            static let emptyNearby = NSLocalizedString(
                "charter.discovery.emptyNearby",
                tableName: "Localizable",
                comment: "Empty state message when no charters are nearby"
            )
            static let emptyDefault = NSLocalizedString(
                "charter.discovery.emptyDefault",
                tableName: "Localizable",
                comment: "Default empty state message for charter discovery"
            )

            // MARK: Urgency badges

            enum Badge {
                static let past = NSLocalizedString(
                    "charter.discovery.badge.past",
                    tableName: "Localizable",
                    comment: "Badge label for past charters"
                )
                static let ongoing = NSLocalizedString(
                    "charter.discovery.badge.ongoing",
                    tableName: "Localizable",
                    comment: "Badge label for ongoing charters"
                )
                static let imminent = NSLocalizedString(
                    "charter.discovery.badge.imminent",
                    tableName: "Localizable",
                    comment: "Badge label for charters starting within 7 days"
                )
                static let soon = NSLocalizedString(
                    "charter.discovery.badge.soon",
                    tableName: "Localizable",
                    comment: "Badge label for charters starting within 30 days"
                )
                static let upcoming = NSLocalizedString(
                    "charter.discovery.badge.upcoming",
                    tableName: "Localizable",
                    comment: "Badge label for future charters"
                )
            }

            // MARK: Filter sheet

            enum Filter {
                static let title = NSLocalizedString(
                    "charter.discovery.filter.title",
                    tableName: "Localizable",
                    comment: "Navigation title for the filter sheet"
                )
                static let apply = NSLocalizedString(
                    "charter.discovery.filter.apply",
                    tableName: "Localizable",
                    comment: "Apply filters button"
                )
                static let reset = NSLocalizedString(
                    "charter.discovery.filter.reset",
                    tableName: "Localizable",
                    comment: "Reset filters button"
                )
                static let sectionDateRange = NSLocalizedString(
                    "charter.discovery.filter.sectionDateRange",
                    tableName: "Localizable",
                    comment: "Date range section header in filter sheet"
                )
                static let sectionLocation = NSLocalizedString(
                    "charter.discovery.filter.sectionLocation",
                    tableName: "Localizable",
                    comment: "Location & distance section header in filter sheet"
                )
                static let nearMe = NSLocalizedString(
                    "charter.discovery.filter.nearMe",
                    tableName: "Localizable",
                    comment: "Near me toggle label"
                )
                static let nearMeSubtitle = NSLocalizedString(
                    "charter.discovery.filter.nearMeSubtitle",
                    tableName: "Localizable",
                    comment: "Near me toggle subtitle explaining what it does"
                )
                static let searchRadius = NSLocalizedString(
                    "charter.discovery.filter.searchRadius",
                    tableName: "Localizable",
                    comment: "Search radius label in filter sheet"
                )
                static let sectionSortBy = NSLocalizedString(
                    "charter.discovery.filter.sectionSortBy",
                    tableName: "Localizable",
                    comment: "Sort by section header in filter sheet"
                )
                static let anyDistance = NSLocalizedString(
                    "charter.discovery.filter.anyDistance",
                    tableName: "Localizable",
                    comment: "Radius label when maximum range is selected (any distance)"
                )

                static func withinKm(_ km: Int) -> String {
                    String(format: NSLocalizedString(
                        "charter.discovery.filter.withinKm",
                        tableName: "Localizable",
                        comment: "Active-filter chip label showing the current radius, %d = km"
                    ), km)
                }

                // Date presets
                enum DatePreset {
                    static let upcoming = NSLocalizedString(
                        "charter.discovery.filter.preset.upcoming",
                        tableName: "Localizable",
                        comment: "Date preset: all upcoming charters"
                    )
                    static let thisWeek = NSLocalizedString(
                        "charter.discovery.filter.preset.thisWeek",
                        tableName: "Localizable",
                        comment: "Date preset: charters this week"
                    )
                    static let thisMonth = NSLocalizedString(
                        "charter.discovery.filter.preset.thisMonth",
                        tableName: "Localizable",
                        comment: "Date preset: charters this month"
                    )
                    static let custom = NSLocalizedString(
                        "charter.discovery.filter.preset.custom",
                        tableName: "Localizable",
                        comment: "Date preset: custom date range"
                    )
                }

                // Sort orders
                enum SortOrder {
                    static let dateAscending = NSLocalizedString(
                        "charter.discovery.filter.sort.dateAscending",
                        tableName: "Localizable",
                        comment: "Sort order: earliest start date first"
                    )
                    static let distanceAscending = NSLocalizedString(
                        "charter.discovery.filter.sort.distanceAscending",
                        tableName: "Localizable",
                        comment: "Sort order: closest first"
                    )
                    static let recentlyPosted = NSLocalizedString(
                        "charter.discovery.filter.sort.recentlyPosted",
                        tableName: "Localizable",
                        comment: "Sort order: most recently posted"
                    )
                }
            }

            // MARK: Map filter bar (charter discovery map mode)

            enum MapFilter {
                static let dateRangeChip = NSLocalizedString(
                    "charter.discovery.mapFilter.dateRangeChip",
                    tableName: "Localizable",
                    comment: "Map filter bar chip to open date window controls"
                )
                static let sortChip = NSLocalizedString(
                    "charter.discovery.mapFilter.sortChip",
                    tableName: "Localizable",
                    comment: "Map filter bar chip for sort menu"
                )
                static let presetThreeMonths = NSLocalizedString(
                    "charter.discovery.mapFilter.preset.threeMonths",
                    tableName: "Localizable",
                    comment: "Map date preset: next three months"
                )
                static let presetAll = NSLocalizedString(
                    "charter.discovery.mapFilter.preset.all",
                    tableName: "Localizable",
                    comment: "Map date preset: full slider range (e.g. 12 months)"
                )
                static let resetChip = NSLocalizedString(
                    "charter.discovery.mapFilter.resetChip",
                    tableName: "Localizable",
                    comment: "Map filter bar control to clear non-default filters"
                )
                static let dateRangeSheetHintTitle = NSLocalizedString(
                    "charter.discovery.mapFilter.sheet.dateHintTitle",
                    tableName: "Localizable",
                    comment: "List filter sheet: title explaining date is on map"
                )
                static let dateRangeSheetHintBody = NSLocalizedString(
                    "charter.discovery.mapFilter.sheet.dateHintBody",
                    tableName: "Localizable",
                    comment: "List filter sheet: body explaining date is on map"
                )
                static let trackNow = NSLocalizedString(
                    "charter.discovery.mapFilter.track.now",
                    tableName: "Localizable",
                    comment: "Map date slider left track label"
                )
                static let trackPlusOneYear = NSLocalizedString(
                    "charter.discovery.mapFilter.track.plusOneYear",
                    tableName: "Localizable",
                    comment: "Map date slider right track label (rolling year window)"
                )
            }
        }

        /// Charter delete confirmation modal (when charter is visible in discovery).
        enum DeleteModal {
            static let title = NSLocalizedString(
                "charter.deleteModal.title",
                tableName: "Localizable",
                comment: "Title for the charter delete confirmation when charter is in discovery"
            )
            static func explanation(_ charterName: String) -> String {
                String(format: NSLocalizedString(
                    "charter.deleteModal.explanation",
                    tableName: "Localizable",
                    comment: "Explanation text; %@ = charter name"
                ), charterName)
            }
            static let unpublishAndDeleteTitle = NSLocalizedString(
                "charter.deleteModal.unpublishAndDeleteTitle",
                tableName: "Localizable",
                comment: "Option: unpublish from discovery and delete locally"
            )
            static let unpublishAndDeleteSubtitle = NSLocalizedString(
                "charter.deleteModal.unpublishAndDeleteSubtitle",
                tableName: "Localizable",
                comment: "Subtitle for unpublish and delete option"
            )
            static let deleteLocalOnlyTitle = NSLocalizedString(
                "charter.deleteModal.deleteLocalOnlyTitle",
                tableName: "Localizable",
                comment: "Option: delete only from this device, keep in discovery"
            )
            static let deleteLocalOnlySubtitle = NSLocalizedString(
                "charter.deleteModal.deleteLocalOnlySubtitle",
                tableName: "Localizable",
                comment: "Subtitle for delete local only option"
            )
            static let unpublishRequiresSignIn = NSLocalizedString(
                "charter.deleteModal.unpublishRequiresSignIn",
                tableName: "Localizable",
                comment: "Shown instead of the unpublish subtitle when the user is not signed in"
            )
        }

        enum CheckInChecklist {
            static let title = NSLocalizedString(
                "charter.detail.checkInChecklist.title",
                tableName: "Localizable",
                comment: "Title for the check-in checklist section"
            )

            static let subtitle = NSLocalizedString(
                "charter.detail.checkInChecklist.subtitle",
                tableName: "Localizable",
                comment: "Subtitle explaining the check-in checklist purpose"
            )

            enum Button {
                static let title = NSLocalizedString(
                    "charter.detail.checkInChecklist.button.title",
                    tableName: "Localizable",
                    comment: "Title for the check-in checklist button"
                )

                static let description = NSLocalizedString(
                    "charter.detail.checkInChecklist.button.description",
                    tableName: "Localizable",
                    comment: "Description for the check-in checklist button"
                )
            }

            enum Empty {
                static let title = NSLocalizedString(
                    "charter.detail.checkInChecklist.empty.title",
                    tableName: "Localizable",
                    comment: "Title when no check-in checklist exists"
                )

                static let description = NSLocalizedString(
                    "charter.detail.checkInChecklist.empty.description",
                    tableName: "Localizable",
                    comment: "Description explaining how to create a check-in checklist"
                )
            }
        }
    }

    enum Common {
        static let close = NSLocalizedString(
            "common.close",
            tableName: "Localizable",
            comment: "Close button text"
        )

        static let cancel = NSLocalizedString(
            "common.cancel",
            tableName: "Localizable",
            comment: "Cancel button text"
        )

        static let save = NSLocalizedString(
            "common.save",
            tableName: "Localizable",
            comment: "Save button text"
        )

        static let ok = NSLocalizedString(
            "common.ok",
            tableName: "Localizable",
            comment: "OK button text"
        )

        static let retry = NSLocalizedString(
            "common.retry",
            tableName: "Localizable",
            comment: "Retry button after an error"
        )
    }

    enum CommunityManager {
        static let title = NSLocalizedString(
            "communityManager.title",
            tableName: "Localizable",
            comment: "Navigation title for community manager dashboard"
        )
        static let sectionTitle = NSLocalizedString(
            "communityManager.sectionTitle",
            tableName: "Localizable",
            comment: "Profile section header for community manager entry"
        )
        static let sectionSubtitle = NSLocalizedString(
            "communityManager.sectionSubtitle",
            tableName: "Localizable",
            comment: "Profile section subtitle for virtual captains"
        )
        static let emptyManaged = NSLocalizedString(
            "communityManager.emptyManaged",
            tableName: "Localizable",
            comment: "Empty state when user manages no communities"
        )
        static let emptyStateTitle = NSLocalizedString(
            "communityManager.emptyStateTitle",
            tableName: "Localizable",
            comment: "Empty state title on community manager list"
        )
        static let emptyStateMessage = NSLocalizedString(
            "communityManager.emptyStateMessage",
            tableName: "Localizable",
            comment: "Empty state message: create community from profile"
        )
        static let virtualCaptainsSection = NSLocalizedString(
            "communityManager.virtualCaptainsSection",
            tableName: "Localizable",
            comment: "Section header for virtual captain list"
        )
        static let noVirtualCaptainsYet = NSLocalizedString(
            "communityManager.noVirtualCaptainsYet",
            tableName: "Localizable",
            comment: "Placeholder when a community has no virtual captains"
        )
        static let addVirtualCaptain = NSLocalizedString(
            "communityManager.addVirtualCaptain",
            tableName: "Localizable",
            comment: "Accessibility / toolbar: add virtual captain"
        )
        static let deleteBlockedTitle = NSLocalizedString(
            "communityManager.deleteBlockedTitle",
            tableName: "Localizable",
            comment: "Alert title when virtual captain cannot be deleted"
        )
        static func deleteBlockedMessage(_ name: String) -> String {
            String(format: NSLocalizedString(
                "communityManager.deleteBlockedMessage",
                tableName: "Localizable",
                comment: "Alert message: %@ = virtual captain display name"
            ), name)
        }
        static func virtualCaptainCount(_ count: Int) -> String {
            String(format: NSLocalizedString(
                "communityManager.virtualCaptainCount",
                tableName: "Localizable",
                comment: "Subtitle: %d = number of virtual captains"
            ), count)
        }
        static func memberCount(_ count: Int) -> String {
            String(format: NSLocalizedString(
                "communityManager.memberCount",
                tableName: "Localizable",
                comment: "Subtitle: %d = member count"
            ), count)
        }
        static let editorTitleNew = NSLocalizedString(
            "communityManager.editorTitleNew",
            tableName: "Localizable",
            comment: "Title when creating a virtual captain"
        )
        static let editorTitleEdit = NSLocalizedString(
            "communityManager.editorTitleEdit",
            tableName: "Localizable",
            comment: "Title when editing a virtual captain"
        )
        static let displayNameLabel = NSLocalizedString(
            "communityManager.displayNameLabel",
            tableName: "Localizable",
            comment: "Label for virtual captain display name field"
        )
    }

    enum AuthorProfile {
        static let title = NSLocalizedString(
            "authorProfile.title",
            tableName: "Localizable",
            comment: "Title for author profile modal"
        )

        static let comingSoonTitle = NSLocalizedString(
            "authorProfile.comingSoonTitle",
            tableName: "Localizable",
            comment: "Coming soon section title"
        )

        static let comingSoonMessage = NSLocalizedString(
            "authorProfile.comingSoonMessage",
            tableName: "Localizable",
            comment: "Coming soon message explaining future features"
        )
        
        static let verified = NSLocalizedString(
            "authorProfile.verified",
            tableName: "Localizable",
            comment: "Verified badge text"
        )
        
        static let getInTouch = NSLocalizedString(
            "authorProfile.getInTouch",
            tableName: "Localizable",
            comment: "Get in touch button text"
        )
    }
}