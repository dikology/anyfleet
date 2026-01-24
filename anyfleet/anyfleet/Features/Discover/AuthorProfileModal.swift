import SwiftUI
import MessageUI

struct AuthorProfileModal: View {
    let author: AuthorProfile
    let onDismiss: () -> Void
    
    @State private var showMailComposer = false
    @State private var mailResult: Result<MFMailComposeResult, Error>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Full-screen backdrop image with blur
                if let url = createProfileImageURL(author.profileImageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                //.blur(radius: 20) // Heavy blur for depth and focus on content
                                .ignoresSafeArea()
                        case .failure:
                            placeholderBackground()
                        case .empty:
                            ZStack {
                                placeholderBackground()
                                ProgressView()
                                    .tint(.white)
                            }
                        @unknown default:
                            placeholderBackground()
                        }
                    }
                } else {
                    placeholderBackground()
                }

                // Enhanced gradient overlay for readability
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Bottom-aligned content
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Avatar with verification badge
                    ZStack(alignment: .bottomTrailing) {
                        if let url = createProfileImageURL(author.profileImageThumbnailUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 4)
                                        )
                                        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
                                case .failure, .empty:
                                    placeholderAvatar()
                                @unknown default:
                                    placeholderAvatar()
                                }
                            }
                        } else {
                            placeholderAvatar()
                        }

                        // Verification badge
                        if author.isVerified {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .offset(x: 4, y: 4)
                        }
                    }

                    // Username with inline verification
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(author.username)
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                            .accessibilityIdentifier("author_username")
                    }

                    // Bio with optional location
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        if let bio = author.bio, !bio.isEmpty {
                            Text(bio)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.white.opacity(0.95))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .lineSpacing(3)
                                .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                        }
                        
                        // Location badge
                        if let location = author.location, !location.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                Text(location)
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Stats row with dividers
                    if let stats = author.stats {
                        HStack(spacing: 0) {
                            if let rating = stats.averageRating {
                                statBadge(
                                    icon: "star.fill",
                                    value: String(format: "%.1f", rating),
                                    label: "Rating",
                                    color: DesignSystem.Colors.warning
                                )
                                .frame(maxWidth: .infinity)
                            }
                            
                            if let contributions = stats.totalContributions {
                                Divider()
                                    .frame(height: 40)
                                    .background(.white.opacity(0.3))
                                
                                statBadge(
                                    icon: "doc.text.fill",
                                    value: contributions > 999 ? "\(contributions/1000)k+" : "\(contributions)",
                                    label: "Content",
                                    color: DesignSystem.Colors.primary
                                )
                                .frame(maxWidth: .infinity)
                            }
                            
                            if let forks = stats.totalForks {
                                Divider()
                                    .frame(height: 40)
                                    .background(.white.opacity(0.3))
                                
                                statBadge(
                                    icon: "arrow.triangle.branch",
                                    value: forks > 999 ? "\(forks/1000)k+" : "\(forks)",
                                    label: "Forks",
                                    color: DesignSystem.Colors.info
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Spacing.lg)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.lg)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }

                    // Action buttons
//                    HStack(spacing: DesignSystem.Spacing.md) {
//                        // Primary CTA: Get In Touch
//                        Button(action: {
//                            if MFMailComposeViewController.canSendMail() {
//                                showMailComposer = true
//                            }
//                        }) {
//                            HStack(spacing: DesignSystem.Spacing.sm) {
//                                Image(systemName: "envelope.fill")
//                                Text(L10n.AuthorProfile.getInTouch)
//                                    .fontWeight(.semibold)
//                            }
//                            .font(DesignSystem.Typography.body)
//                            .foregroundColor(DesignSystem.Colors.onPrimary)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, DesignSystem.Spacing.md)
//                            .background(
//                                RoundedRectangle(cornerRadius: DesignSystem.Spacing.xl)
//                                    .fill(DesignSystem.Gradients.primary)
//                            )
//                            .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 12, x: 0, y: 6)
//                        }
//                        .disabled(!MFMailComposeViewController.canSendMail())
//
//                        // Bookmark button
//                        Button(action: {
//                            // TODO: Implement bookmark/save functionality
//                        }) {
//                            Image(systemName: "bookmark")
//                                .font(.system(size: 18, weight: .semibold))
//                                .foregroundColor(.white)
//                                .frame(width: 56, height: 56)
//                                .background(
//                                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.xl)
//                                        .fill(.ultraThinMaterial)
//                                        .overlay(
//                                            RoundedRectangle(cornerRadius: DesignSystem.Spacing.xl)
//                                                .stroke(.white.opacity(0.3), lineWidth: 1)
//                                        )
//                                )
//                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
//                        }
//                    }
//                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityIdentifier("modal_xmark_button")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipients: [author.email],
                subject: "Contact from AnyFleet",
                body: "",
                result: $mailResult
            )
        }
    }
    
    @MainActor
    private func placeholderBackground() -> some View {
        Rectangle()
            .fill(DesignSystem.Gradients.primary)
            .ignoresSafeArea()
    }
    
    
    @MainActor
    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)

                Text(value)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    @MainActor
    private func placeholderAvatar() -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.7),
                            DesignSystem.Colors.primary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)

            Image(systemName: "person.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .strokeBorder(.white, lineWidth: 4)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    // Helper function to create proper URLs from backend responses
    private func createProfileImageURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString else {
            AppLogger.view.debug("AuthorProfileModal createProfileImageURL: nil input")
            return nil
        }

        // If URL already has protocol, use as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            AppLogger.view.debug("AuthorProfileModal createProfileImageURL: URL already has protocol: \(urlString)")
            return URL(string: urlString)
        }

        // Check if URL contains a domain (contains dots and starts with a domain-like pattern)
        if urlString.contains(".") && !urlString.hasPrefix("/") {
            // URL contains domain but no protocol - add https://
            let fullURLString = "https://" + urlString
            AppLogger.view.debug("AuthorProfileModal createProfileImageURL: added https to domain URL: \(fullURLString)")
            return URL(string: fullURLString)
        } else {
            // Relative path - prepend base URL
            let baseURL = "https://elegant-empathy-production-583b.up.railway.app"
            let fullURLString = baseURL + (urlString.hasPrefix("/") ? "" : "/") + urlString
            AppLogger.view.debug("AuthorProfileModal createProfileImageURL: constructed relative URL: \(fullURLString)")
            return URL(string: fullURLString)
        }
    }
}

// MARK: - Supporting Types

struct AuthorProfile {
    let username: String
    let email: String
    let profileImageUrl: String?
    let profileImageThumbnailUrl: String?
    let bio: String?
    let location: String?
    let nationality: String?
    let isVerified: Bool
    let stats: AuthorStats?
}

struct AuthorStats {
    let averageRating: Double?
    let totalContributions: Int?
    let totalForks: Int?
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    @Binding var result: Result<MFMailComposeResult, Error>?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.result = .failure(error)
            } else {
                parent.result = .success(result)
            }
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    AuthorProfileModal(
        author: AuthorProfile(
            username: "Captain Sarah",
            email: "sarah@example.com",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: "Professional skipper with 20+ years experience. Specializing in yacht charters and sailing instruction across the Mediterranean.",
            location: "Mediterranean",
            nationality: "Italian",
            isVerified: true,
            stats: AuthorStats(
                averageRating: 4.9,
                totalContributions: 127,
                totalForks: 89
            )
        ),
        onDismiss: {}
    )
}
