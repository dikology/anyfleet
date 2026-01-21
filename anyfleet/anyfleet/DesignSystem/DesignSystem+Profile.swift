import SwiftUI
import PhotosUI

// MARK: - Profile Components Extension
extension DesignSystem {
  enum Profile {
    
    // MARK: - Profile Hero Section
    /// Hero header displaying user identity with optional completion indicator
    struct Hero: View {
      let user: UserInfo
      let verificationTier: VerificationTier?
      let completionPercentage: Int?
      let onEditTap: () -> Void
      let onPhotoSelect: (PhotosPickerItem) -> Void
      let isUploadingImage: Bool
      
      var body: some View {
        VStack(spacing: 0) {
          // Hero background section
          ZStack(alignment: .bottomLeading) {
            // Background image with gradient overlay
            heroBackgroundView
            
            // Content overlay
            VStack(alignment: .leading, spacing: Spacing.lg) {
              Spacer()
              
              HStack(spacing: Spacing.lg) {
                // Profile image + camera button
                profileImageStackView
                
                // Name, email, verification
                VStack(alignment: .leading, spacing: Spacing.xs) {
                  Text(user.username ?? user.email)
                    .font(Typography.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                  
                  Text(user.email)
                    .font(Typography.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                  
                  if let tier = verificationTier {
                    verificationBadgeView(tier)
                      .frame(width: 28, height: 28)
                  }
                }
                
                Spacer()
                
                // Edit button
                Button(action: onEditTap) {
                  Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Colors.primary)
                    .clipShape(Circle())
                }
              }
              .padding(.leading, Spacing.lg)
              .padding(.bottom, Spacing.lg)
            }
            .frame(height: 240)
          }
          .frame(height: 240)
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .shadow(color: Colors.shadowStrong.opacity(0.3), radius: 16, x: 0, y: 8)
          
          // Completion banner (optional)
          if let completion = completionPercentage, completion < 100 {
            completionBannerView(completion)
              .padding(.horizontal, Spacing.lg)
              .padding(.top, Spacing.lg)
          }
        }
      }
      
      // MARK: - Hero Helper Views
      
      private var heroBackgroundView: some View {
        ZStack {
          if let url = user.profileImageUrl {
            AsyncImage(url: URL(string: url)) { phase in
              switch phase {
              case .success(let image):
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
              default:
                Colors.primary
              }
            }
          } else {
            Colors.primary
          }

          LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.4)],
            startPoint: .center,
            endPoint: .bottom
          )
        }
      }
      
      private var profileImageStackView: some View {
        ZStack(alignment: .bottomTrailing) {
          // Avatar
          if let url = user.profileImageThumbnailUrl {
            AsyncImage(url: URL(string: url)) { phase in
              switch phase {
              case .success(let image):
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 88, height: 88)
                  .clipShape(Circle())
              default:
                Circle().fill(Colors.primary).frame(width: 88, height: 88)
              }
            }
          } else {
            Circle().fill(Colors.primary).frame(width: 88, height: 88)
          }

          // Person icon fallback
          if user.profileImageThumbnailUrl == nil {
            Image(systemName: "person.fill")
              .font(.system(size: 35, weight: .semibold))
              .foregroundColor(.white)
          }

          // Camera button
          PhotosPicker(selection: Binding(
            get: { nil },
            set: { item in
              if let item = item {
                onPhotoSelect(item)
              }
            }
          ), matching: .images) {
            Image(systemName: "camera.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 32, height: 32)
              .background(Colors.primary)
              .clipShape(Circle())
              .overlay(Circle().strokeBorder(.white, lineWidth: 2))
          }
          .disabled(isUploadingImage)
          .offset(x: -4, y: -4)
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
      }
      
      private func completionBannerView(_ percentage: Int) -> some View {
        HStack(spacing: Spacing.md) {
          Image(systemName: "chart.pie.fill")
            .foregroundColor(.primary)
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Profile \(percentage)% complete")
              .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(percentage), total: 100)
              .tint(.primary)
          }
          
          Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
      }
      
      private func verificationBadgeView(_ tier: VerificationTier) -> some View {
        ZStack {
          Circle().fill(Colors.surface)
          Image(systemName: tier.icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tier.color)
        }
        .shadow(color: Colors.shadowStrong, radius: 4, x: 0, y: 2)
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
          
          // Location field
          fieldGroup(
            label: "Location",
            helper: nil,
            content: {
              TextField("Your location", text: $location)
                .formFieldStyle()
            }
          )
          
          // Nationality field
          fieldGroup(
            label: "Nationality",
            helper: nil,
            content: {
              TextField("Your nationality", text: $nationality)
                .formFieldStyle()
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
    verificationTier: .expert,
    completionPercentage: 80,
    onEditTap: {},
    onPhotoSelect: { _ in },
    isUploadingImage: false
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