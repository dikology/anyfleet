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
                // Full-screen backdrop image or gradient (Profile Card style)
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

                // Dark gradient overlay for cinematic effect
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.2),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Radial vignette for depth
                    RadialGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.4)]),
                        center: .center,
                        startRadius: 200,
                        endRadius: 600
                    )
                }
                .ignoresSafeArea()

                // Profile Card Content (as per Reference 2)
                VStack {
                    Spacer()

                    // Main profile card
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Profile image with verification overlay
                        ZStack(alignment: .bottomTrailing) {
                            if let thumbnailUrl = author.profileImageThumbnailUrl, let url = URL(string: thumbnailUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 3)
                                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                                            )
                                    case .failure, .empty:
                                        placeholderAvatar()
                                    @unknown default:
                                        placeholderAvatar()
                                    }
                                }
                            } else {
                                placeholderAvatar()
                            }

                            // Verification badge overlay
                            if author.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .frame(width: 28, height: 28)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    .offset(x: 4, y: 4)
                            }
                        }

                        // Username
                        Text(author.username)
                            .font(DesignSystem.Typography.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                            .accessibilityIdentifier("author_username")

                        // Bio (One-line summary as per reference)
                        if let bio = author.bio, !bio.isEmpty {
                            Text(bio)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .lineSpacing(2)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }

                        // Three Key Stats (horizontal layout as per reference)
                        if let stats = author.stats {
                            HStack(spacing: DesignSystem.Spacing.xl) {
                                if let rating = stats.averageRating {
                                    statBadge(
                                        icon: "star.fill",
                                        value: String(format: "%.1f", rating),
                                        label: "Rating",
                                        color: DesignSystem.Colors.warning
                                    )
                                }

                                if let contributions = stats.totalContributions {
                                    statBadge(
                                        icon: "doc.text.fill",
                                        value: "\(contributions)",
                                        label: "Content",
                                        color: DesignSystem.Colors.primary
                                    )
                                }

                                if let forks = stats.totalForks {
                                    statBadge(
                                        icon: "arrow.triangle.branch",
                                        value: "\(forks)",
                                        label: "Forks",
                                        color: DesignSystem.Colors.info
                                    )
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        // Location badge (if available)
                        if let location = author.location, !location.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 12))
                                Text(location)
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(DesignSystem.Spacing.md)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }

                        // Action buttons (Primary CTA + Bookmark)
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Primary CTA: Get In Touch
                            Button(action: {
                                if MFMailComposeViewController.canSendMail() {
                                    showMailComposer = true
                                }
                            }) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "envelope.fill")
                                    Text(L10n.AuthorProfile.getInTouch)
                                        .fontWeight(.semibold)
                                }
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(DesignSystem.Gradients.primary)
                                .cornerRadius(DesignSystem.Spacing.lg)
                                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(!MFMailComposeViewController.canSendMail())

                            // Bookmark button
                            Button(action: {
                                // TODO: Implement bookmark/save functionality
                            }) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(DesignSystem.Spacing.lg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.lg)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .blur(radius: 0.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)

                    Spacer()
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
    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)

                Text(value)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 70)
    }

    @MainActor
    private func placeholderAvatar() -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 80, height: 80)

            Image(systemName: "person.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
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
