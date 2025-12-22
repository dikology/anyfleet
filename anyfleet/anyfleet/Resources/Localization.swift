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
    }
    
    static let Discover = NSLocalizedString(
        "discover",
        tableName: "Localizable",
        comment: "Title for the discover tab"
    )
    
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

        static let detailTitle = NSLocalizedString(
            "charter.detail.title",
            tableName: "Localizable",
            comment: "Navigation title for charter detail view"
        )

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
}