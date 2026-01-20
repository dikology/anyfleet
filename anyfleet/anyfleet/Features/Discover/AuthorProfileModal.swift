import SwiftUI
import MessageUI

struct AuthorProfileModal: View {
    let author: AuthorProfile
    let onDismiss: () -> Void
    
    @State private var showMailComposer = false
    @State private var mailResult: Result<MFMailComposeResult, Error>?

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen backdrop image or gradient
                if let imageUrl = author.profileImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .ignoresSafeArea()
                        case .failure, .empty:
                            placeholderBackground()
                        @unknown default:
                            placeholderBackground()
                        }
                    }
                } else {
                    placeholderBackground()
                }
                
                // Dark gradient overlay for text legibility
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Content
                VStack(spacing: DesignSystem.Spacing.xl) {
                    Spacer()
                    
                    // Profile avatar
                    if let thumbnailUrl = author.profileImageThumbnailUrl, let url = URL(string: thumbnailUrl) {
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
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            case .failure, .empty:
                                placeholderAvatar()
                            @unknown default:
                                placeholderAvatar()
                            }
                        }
                    } else {
                        placeholderAvatar()
                    }

                    // Username with verification badge
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(author.username)
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                    .accessibilityIdentifier("author_username")

                    // Bio (2-3 lines, truncated)
                    if let bio = author.bio, !bio.isEmpty {
                        Text(bio)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                    }
                    
                    // Location and nationality
                    HStack(spacing: DesignSystem.Spacing.md) {
                        if let location = author.location, !location.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                Text(location)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let nationality = author.nationality, !nationality.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 14))
                                Text(nationality)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Key stats section (if available)
                    if let stats = author.stats {
                        HStack(spacing: DesignSystem.Spacing.xl) {
                            if let rating = stats.averageRating {
                                statItem(icon: "star.fill", value: String(format: "%.1f", rating))
                            }
                            
                            if let contributions = stats.totalContributions {
                                statItem(icon: "doc.text.fill", value: "\(contributions)")
                            }
                            
                            if let forks = stats.totalForks {
                                statItem(icon: "arrow.triangle.branch", value: "\(forks)")
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                    }
                    
                    Spacer()

                    // Action buttons
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Get In Touch button
                        Button(action: {
                            if MFMailComposeViewController.canSendMail() {
                                showMailComposer = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text(L10n.AuthorProfile.getInTouch)
                            }
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Gradients.primary)
                            .cornerRadius(DesignSystem.Spacing.md)
                        }
                        .disabled(!MFMailComposeViewController.canSendMail())
                        
                        // Bookmark button (placeholder for future)
                        Button(action: {
                            // TODO: Implement bookmark functionality
                        }) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(DesignSystem.Spacing.md)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
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
    private func placeholderAvatar() -> some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.surface)
                .frame(width: 100, height: 100)
            
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    @MainActor
    private func statItem(icon: String, value: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(DesignSystem.Typography.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
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
            username: "SailorMaria",
            email: "maria@example.com",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: "Experienced sailor with 15 years on the water. Passionate about teaching newcomers the art of sailing and exploring Mediterranean waters.",
            location: "Mediterranean",
            nationality: "Spanish",
            isVerified: true,
            stats: AuthorStats(
                averageRating: 4.8,
                totalContributions: 42,
                totalForks: 15
            )
        ),
        onDismiss: {}
    )
}
