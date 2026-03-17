import SwiftUI
import PhotosUI

// MARK: - Profile Components Extension
extension DesignSystem {
  enum Profile {
    
    // MARK: - Profile Hero Section
    /// Full-bleed hero background. Avatar and user info live in overlapping content below.
    struct Hero: View {
      let user: UserInfo
      let onEditTap: () -> Void

      private let heroHeight: CGFloat = 256
      
      var body: some View {
        ZStack(alignment: .topTrailing) {
          heroBackgroundView
            .frame(height: heroHeight)
            .frame(maxWidth: .infinity)
            .clipped()
          
          LinearGradient(
            colors: [
              Color.clear,
              Color.clear,
              Colors.background.opacity(0.3),
              Colors.background
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          
          Button(action: onEditTap) {
            Image(systemName: "pencil")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 40, height: 40)
              .glassPanel()
              .clipShape(Circle())
          }
          .padding(.top, 56)
          .padding(.trailing, Spacing.lg)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
      }
      
      private var heroBackgroundView: some View {
        Group {
          if let url = user.profileImageUrl {
            AsyncImage(url: URL(string: url)) { phase in
              switch phase {
              case .success(let image):
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
              case .failure:
                gradientBackground
              case .empty:
                ZStack {
                  gradientBackground
                  ProgressView().tint(.white)
                }
              @unknown default:
                gradientBackground
              }
            }
          } else {
            gradientBackground
          }
        }
      }
      
      private var gradientBackground: some View {
        LinearGradient(
          colors: [
            Colors.primary.opacity(0.7),
            Colors.primary,
            Colors.primary.opacity(0.9)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
    
    // MARK: - Profile Header Content (overlapping)
    /// Avatar, name, metadata, bio — overlaps the hero with negative margin.
    struct HeaderContent: View {
      let user: UserInfo
      let verificationTier: VerificationTier?
      var primaryCommunity: CommunityMembership? = nil
      let memberSince: String?
      let onPhotoSelect: (PhotosPickerItem) -> Void
      let isUploadingImage: Bool

      private let avatarSize: CGFloat = 112
      
      var body: some View {
        VStack(alignment: .leading, spacing: 0) {
          avatarView
            .padding(.bottom, Spacing.md)
          
          Text(user.username ?? user.email)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .tracking(-0.5)
            .foregroundColor(Colors.textPrimary)
            .lineLimit(1)
            .padding(.bottom, Spacing.sm)
          
          metadataRow
          
          if let bio = user.bio, !bio.isEmpty {
            Text(bio)
              .font(Typography.body)
              .foregroundColor(Colors.textSecondary)
              .lineSpacing(4)
              .padding(.top, Spacing.md)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      
      private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
          ZStack {
            Circle()
              .strokeBorder(Colors.background, lineWidth: 4)
              .frame(width: avatarSize, height: avatarSize)
            
            Group {
              if let url = user.profileImageThumbnailUrl {
                AsyncImage(url: URL(string: url)) { phase in
                  switch phase {
                  case .success(let image):
                    image
                      .resizable()
                      .aspectRatio(contentMode: .fill)
                      .frame(width: avatarSize - 8, height: avatarSize - 8)
                      .clipShape(Circle())
                  case .failure:
                    avatarPlaceholder
                  case .empty:
                    ZStack {
                      Circle().fill(Colors.surfaceAlt)
                      ProgressView().tint(.white)
                    }
                    .frame(width: avatarSize - 8, height: avatarSize - 8)
                  @unknown default:
                    avatarPlaceholder
                  }
                }
              } else {
                avatarPlaceholder
              }
            }
          }

          PhotosPicker(selection: Binding(
            get: { nil },
            set: { item in if let item = item { onPhotoSelect(item) } }
          ), matching: .images) {
            ZStack {
              Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5))
              
              if isUploadingImage {
                ProgressView().tint(Colors.primary).scaleEffect(0.8)
              } else {
                Image(systemName: "camera.fill")
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundColor(Colors.primary)
              }
            }
          }
          .disabled(isUploadingImage)
          .offset(x: 4, y: 4)
        }
        .frame(width: avatarSize, height: avatarSize)
      }
      
      private var avatarPlaceholder: some View {
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [Colors.primary.opacity(0.8), Colors.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: avatarSize - 8, height: avatarSize - 8)
          Image(systemName: "person.fill")
            .font(.system(size: 44, weight: .medium))
            .foregroundColor(.white)
        }
      }
      
      private var metadataRow: some View {
        HStack(spacing: Spacing.lg) {
          if let location = user.location, !location.isEmpty {
            HStack(spacing: 4) {
              Image(systemName: "mappin.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(Colors.primary)
              Text(location)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
            }
          }
          if let date = memberSince {
            HStack(spacing: 4) {
              Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundColor(Colors.primary)
              Text(date)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
            }
          }
          if let community = primaryCommunity {
            CommunityBadge(name: community.name, iconURL: community.iconURL, style: .pill)
          }
        }
      }
    }
    
    // MARK: - Verification Tier
    enum VerificationTier: String, Codable, Sendable {
      case new = "new"
      case contributor = "contributor"
      case trusted = "trusted"
      case expert = "expert"
      
      var displayName: String {
        switch self {
        case .new: return "New"
        case .contributor: return "Contributor"
        case .trusted: return "Trusted"
        case .expert: return "Expert"
        }
      }
      
      var icon: String {
        switch self {
        case .new: return "person.crop.circle"
        case .contributor: return "person.crop.circle.fill"
        case .trusted: return "checkmark.seal.fill"
        case .expert: return "star.fill"
        }
      }
      
      var color: Color {
        switch self {
        case .new: return Colors.textSecondary
        case .contributor: return Colors.primary
        case .trusted: return Colors.success
        case .expert: return Colors.warning
        }
      }
    }
    
    // MARK: - Info Row Component
    /// Reusable component for displaying icon, label, and value
    struct InfoRow: View {
      let icon: String
      let label: String
      let value: String
      let detail: String?
      let color: Color
      
      init(
        icon: String,
        label: String,
        value: String,
        detail: String? = nil,
        color: Color = DesignSystem.Colors.primary
      ) {
        self.icon = icon
        self.label = label
        self.value = value
        self.detail = detail
        self.color = color
      }
      
      var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
          HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(color)
              .frame(width: 20)
            
            Text(label)
              .font(Typography.caption)
              .fontWeight(.semibold)
              .foregroundColor(Colors.textSecondary)
          }
          
          Text(value)
            .font(Typography.body)
            .foregroundColor(Colors.textPrimary)
          
          if let detail {
            Text(detail)
              .font(Typography.caption)
              .foregroundColor(Colors.textSecondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(color.opacity(0.08))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
            )
        )
      }
    }
    
    // MARK: - Metrics Card Component
    /// Displays a collection of metrics in a card layout
    struct MetricsCard: View {
      struct Metric {
        let icon: String
        let label: String
        let value: String
        let color: Color
        
        init(icon: String, label: String, value: String, color: Color) {
          self.icon = icon
          self.label = label
          self.value = value
          self.color = color
        }
      }
      
      let title: String
      let subtitle: String?
      let metrics: [Metric]
      
      var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
          DesignSystem.SectionHeader(title, subtitle: subtitle)
          
          VStack(spacing: Spacing.sm) {
            ForEach(metrics, id: \.label) { metric in
              HStack(spacing: Spacing.md) {
                Image(systemName: metric.icon)
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundColor(metric.color)
                  .frame(width: 20)
                
                Text(metric.label)
                  .font(Typography.body)
                  .foregroundColor(Colors.textSecondary)
                
                Spacer()
                
                Text(metric.value)
                  .font(Typography.body)
                  .fontWeight(.semibold)
                  .foregroundColor(metric.color)
              }
              .padding(.vertical, Spacing.xs)
              .padding(.horizontal, Spacing.sm)
            }
          }
        }
        .sectionContainer()
      }
    }
    
    // MARK: - Edit Form Component
    /// Form for editing profile information
    struct EditForm: View {
      @Binding var username: String
      @Binding var bio: String
      @Binding var location: String
      @Binding var nationality: String
      
      let onSave: () -> Void
      let onCancel: () -> Void
      let isSaving: Bool
      let bioCharacterLimit: Int
      
      init(
        username: Binding<String>,
        bio: Binding<String>,
        location: Binding<String>,
        nationality: Binding<String>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        isSaving: Bool,
        bioCharacterLimit: Int = 2000
      ) {
        self._username = username
        self._bio = bio
        self._location = location
        self._nationality = nationality
        self.onSave = onSave
        self.onCancel = onCancel
        self.isSaving = isSaving
        self.bioCharacterLimit = bioCharacterLimit
      }
      
      var body: some View {
        VStack(spacing: Spacing.md) {
          // Display name field
          fieldGroup(
            label: "Display Name",
            helper: nil,
            content: {
              TextField("Your name", text: $username)
                .formFieldStyle()
                .textInputAutocapitalization(.words)
            }
          )
          
          // Bio field
          fieldGroup(
            label: "Bio",
            helper: "\(bio.count) / \(bioCharacterLimit)",
            content: {
              TextEditor(text: $bio)
                .font(Typography.body)
                .frame(minHeight: 100)
                .padding(Spacing.xs)
                .background(Colors.surfaceAlt)
                .cornerRadius(Spacing.sm)
                .overlay(
                  RoundedRectangle(cornerRadius: Spacing.sm)
                    .stroke(Colors.border, lineWidth: 1)
                )
            }
          )
          
          // Action buttons
          HStack(spacing: Spacing.md) {
            Button(action: onCancel) {
              Text("Cancel")
                .font(Typography.body)
                .foregroundColor(Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Colors.surface)
                .cornerRadius(Spacing.md)
                .overlay(
                  RoundedRectangle(cornerRadius: Spacing.md)
                    .stroke(Colors.border, lineWidth: 1)
                )
            }
            .disabled(isSaving)
            
            Button(action: onSave) {
              if isSaving {
                ProgressView()
                  .tint(Colors.onPrimary)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, Spacing.md)
              } else {
                Text("Save")
                  .font(Typography.body)
                  .foregroundColor(Colors.onPrimary)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, Spacing.md)
              }
            }
            .background(DesignSystem.Gradients.primary)
            .cornerRadius(Spacing.md)
            .disabled(isSaving || bio.count > bioCharacterLimit)
          }
        }
      }
      
      private func fieldGroup<Content: View>(
        label: String,
        helper: String?,
        @ViewBuilder content: () -> Content
      ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
          HStack {
            Text(label)
              .font(Typography.caption)
              .foregroundColor(Colors.textSecondary)
            
            if let helper {
              Spacer()
              Text(helper)
                .font(Typography.caption)
                .foregroundColor(
                  helper.contains("2000") ? Colors.error : Colors.textSecondary
                )
            }
          }
          
          content()
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("Profile.Hero") {
  DesignSystem.Profile.Hero(
    user: UserInfo(
      id: "123",
      email: "john@example.com",
      username: "John Doe",
      createdAt: "2024-01-15T10:30:00Z",
      profileImageUrl: nil,
      profileImageThumbnailUrl: nil,
      bio: nil,
      location: nil,
      nationality: nil,
      profileVisibility: "public"
    ),
    onEditTap: {}
  )
  .padding()
}

#Preview("Profile.InfoRow") {
  VStack(spacing: 16) {
    DesignSystem.Profile.InfoRow(
      icon: "mappin.circle.fill",
      label: "Location",
      value: "Cork, Ireland",
      color: .primary
    )
    
    DesignSystem.Profile.InfoRow(
      icon: "flag.fill",
      label: "Nationality",
      value: "Irish",
      color: .orange
    )
  }
  .padding()
}

#Preview("Profile.MetricsCard") {
  DesignSystem.Profile.MetricsCard(
    title: "Reputation",
    subtitle: "Your standing in the community",
    metrics: [
      .init(icon: "doc.text.fill", label: "Contributions", value: "42", color: .blue),
      .init(icon: "star.fill", label: "Rating", value: "4.7/5.0", color: .orange),
      .init(icon: "arrow.triangle.branch", label: "Forks", value: "15", color: .cyan)
    ]
  )
  .padding()
}

#Preview("Profile.EditForm") {
  @State var username = "John Doe"
  @State var bio = "Experienced sailor with 15 years on the water."
  @State var location = "Cork, Ireland"
  @State var nationality = "Irish"
  
  return DesignSystem.Profile.EditForm(
    username: $username,
    bio: $bio,
    location: $location,
    nationality: $nationality,
    onSave: { print("Saved") },
    onCancel: { print("Cancelled") },
    isSaving: false
  )
  .padding()
}
