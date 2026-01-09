# Profile Design Reference Mapping

This document maps the reference images to specific SwiftUI components and implementation details.

---

## Reference #1: Captain Profile (Anna Bonny)
**Use Case:** Detailed profile view (own profile in ProfileView.swift)

### Top Section - Hero with Stats
```
┌─────────────────────────────────────────┐
│  [Large Profile Image with Gradient]   │
│                                         │
│  Anna Bonny, 27 y.o.         🏅 Beginner│
│  Ireland                                │
│                                         │
│  ┌────────┬─────────────┬────────────┐ │
│  │  100   │  ⭐ 5.0 (3) │  3 days    │ │
│  │Sea Miles│avg feedback │Time at sea │ │
│  └────────┴─────────────┴────────────┘ │
└─────────────────────────────────────────┘
```

**SwiftUI Components:**

```swift
// ProfileView.swift enhancements

// 1. Hero Image Section (replace current avatar)
struct ProfileHeroImage: View {
    let imageUrl: String?
    let username: String
    let location: String?
    let experienceLevel: String? // "Beginner", "Expert", etc.
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or gradient
            if let imageUrl = imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    gradientPlaceholder
                }
            } else {
                gradientPlaceholder
            }
            
            // Gradient overlay for text legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // User info overlay
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(username)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let level = experienceLevel {
                        ExperienceBadge(level: level)
                    }
                }
                
                if let location = location {
                    Text(location)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    var gradientPlaceholder: some View {
        LinearGradient(
            colors: [
                Color(hex: "#4A90E2"),
                Color(hex: "#357ABD")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// 2. Stats Grid (below hero)
struct ProfileStatsGrid: View {
    let seaMiles: Int?
    let avgRating: Double?
    let ratingCount: Int?
    let seaTime: String? // "3 days", "2 months", etc.
    
    var body: some View {
        HStack(spacing: 0) {
            StatCard(
                icon: "figure.sailing",
                label: "Sea Miles",
                value: "\(seaMiles ?? 0)"
            )
            
            Divider()
                .frame(height: 60)
            
            StatCard(
                icon: "star.fill",
                label: "avg feedback",
                value: String(format: "%.1f", avgRating ?? 0.0),
                subtitle: "(\(ratingCount ?? 0))",
                iconColor: .yellow
            )
            
            Divider()
                .frame(height: 60)
            
            StatCard(
                icon: "clock.fill",
                label: "Time at sea",
                value: seaTime ?? "N/A"
            )
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var subtitle: String?
    var iconColor: Color = .blue
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

---

### Crewing Tags Section
```
Crewing tags
┌─────────────┬────────────┬───────────┬─────────────┐
│ Novice Crew │ Friendship │ Voluntary │ Non-smoker  │
└─────────────┴────────────┴───────────┴─────────────┘
```

**SwiftUI Component:**

```swift
struct CrewingTagsSection: View {
    let tags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crewing tags")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagPill(text: tag, color: .blue.opacity(0.1))
                }
            }
        }
        .sectionContainer()
    }
}

struct TagPill: View {
    let text: String
    var color: Color = Color.blue.opacity(0.1)
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
    }
}

// Flow Layout for wrapping tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows.rows {
            var x = bounds.minX
            for (index, size) in row {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> (rows: [[(Int, CGSize)]], size: CGSize) {
        let width = proposal.width ?? .infinity
        var rows: [[(Int, CGSize)]] = [[]]
        var currentRow = 0
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > width && !rows[currentRow].isEmpty {
                totalHeight += rows[currentRow].map { $0.1.height }.max() ?? 0
                totalHeight += spacing
                currentRow += 1
                rows.append([])
                x = 0
            }
            
            rows[currentRow].append((index, size))
            x += size.width + spacing
        }
        
        totalHeight += rows.last?.map { $0.1.height }.max() ?? 0
        return (rows, CGSize(width: width, height: totalHeight))
    }
}

extension Array where Element == [(Int, CGSize)] {
    var maxHeight: CGFloat {
        map { $0.map { $0.1.height }.max() ?? 0 }.max() ?? 0
    }
}
```

---

### Bio Section
```
Bio
🌐 Speaks: English, German

Hi! I'm new to sailing and looking to learn the ropes while
soaking up life at sea. I'm a UX/UI designer with a love for
adventure, good conversation, and thoughtful design (of boats
and apps alike). I'm curious, easygoing, and always up for
trying something new.

Looking forward to my first real sailing stories! ⛵✨
```

**SwiftUI Component:**

```swift
struct BioSection: View {
    let languages: [String]
    let bio: String
    @State private var isEditing = false
    @State private var editedBio: String
    
    init(languages: [String], bio: String) {
        self.languages = languages
        self.bio = bio
        _editedBio = State(initialValue: bio)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bio")
                .font(.headline)
            
            // Languages
            if !languages.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    
                    Text("Speaks: ")
                        .fontWeight(.semibold)
                    + Text(languages.joined(separator: ", "))
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // Bio text
            if isEditing {
                VStack(alignment: .trailing, spacing: 8) {
                    TextEditor(text: $editedBio)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("\(editedBio.count) / 2000")
                        .font(.caption)
                        .foregroundColor(editedBio.count > 2000 ? .red : .secondary)
                    
                    HStack {
                        Button("Cancel") {
                            editedBio = bio
                            isEditing = false
                        }
                        
                        Button("Save") {
                            // Save bio
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sectionContainer()
        .onTapGesture {
            if !isEditing {
                isEditing = true
            }
        }
    }
}
```

---

### Qualifications Section
```
Qualifications                            View all >

┌──────────────────────────────────────────────┐
│ [RYA Logo]  Day Skipper                     │
│             The RYA                           │
│                                      ⚙️       │
│ Issued on: 8th Oct 2023                      │
└──────────────────────────────────────────────┘
```

**SwiftUI Component:**

```swift
struct QualificationsSection: View {
    let qualifications: [UserQualification]
    @State private var expandedId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Qualifications")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: AllQualificationsView()) {
                    Text("View all")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            ForEach(qualifications.prefix(3)) { qual in
                QualificationCard(
                    qualification: qual,
                    isExpanded: expandedId == qual.id
                ) {
                    withAnimation {
                        expandedId = expandedId == qual.id ? nil : qual.id
                    }
                }
            }
        }
        .sectionContainer()
    }
}

struct QualificationCard: View {
    let qualification: UserQualification
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Logo/Icon
                Image(systemName: "seal.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(qualification.title)
                        .font(.headline)
                    
                    if let org = qualification.issuingOrganization {
                        Text(org)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                }
            }
            
            if let issueDate = qualification.issueDate {
                Text("Issued on: \(formatDate(issueDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isExpanded, let description = qualification.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .onTapGesture(perform: onTap)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
```

---

### Skills Section
```
Skills
┌────────────┬────────────┬──────────┬──────────────┐
│Line Handling│Watch Duty │Knot Tying│Winch Basics  │
└────────────┴────────────┴──────────┴──────────────┘
┌────────────┬───────────────┬─────────────┬────────┬────┐
│Sail Trimming│Light Navigation│Docking Assist│Cooking│+6  │
└────────────┴───────────────┴─────────────┴────────┴────┘
```

**SwiftUI Component:**

```swift
struct SkillsSection: View {
    let skills: [UserSkill]
    @State private var showAll = false
    
    var displayedSkills: [UserSkill] {
        showAll ? skills : Array(skills.prefix(8))
    }
    
    var remainingCount: Int {
        max(0, skills.count - 8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skills")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(displayedSkills) { skill in
                    SkillPill(skill: skill)
                }
                
                if !showAll && remainingCount > 0 {
                    Button(action: { showAll = true }) {
                        Text("+\(remainingCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(minWidth: 44, minHeight: 32)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .sectionContainer()
    }
}

struct SkillPill: View {
    let skill: UserSkill
    
    var body: some View {
        HStack(spacing: 4) {
            Text(skill.skillName)
                .font(.subheadline)
            
            // Proficiency dots (1-5)
            ForEach(0..<skill.proficiencyLevel, id: \.self) { _ in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
            }
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
```

---

### Hobbies Section
```
Hobbies
┌─────┬────────┬────────┬─────────┐
│Art🎨│Gaming🎮│Humor😂│Cinema🎬│
└─────┴────────┴────────┴─────────┘
```

**SwiftUI Component:**

```swift
struct HobbiesSection: View {
    let hobbies: [(name: String, icon: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hobbies")
                .font(.headline)
            
            FlowLayout(spacing: 12) {
                ForEach(hobbies, id: \.name) { hobby in
                    HobbyCard(name: hobby.name, icon: hobby.icon)
                }
            }
        }
        .sectionContainer()
    }
}

struct HobbyCard: View {
    let name: String
    let icon: String // emoji
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.largeTitle)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 80, height: 80)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
```

---

## Reference #2: Compact Profile Card (Natasha Romanoff)
**Use Case:** Author profile modal, discovery cards (AuthorProfileModal.swift)

```
┌─────────────────────────────────────┐
│ [Full-Screen Background Image]      │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [Dark Gradient Overlay]         │ │
│ │                                 │ │
│ │ Natasha Romanoff ✓              │ │
│ │                                 │ │
│ │ I'm a Brand Designer who focuses│ │
│ │ on clarity & emotional connection│ │
│ │                                 │ │
│ │  ⭐ 4.8      $45k+      $50/hr  │ │
│ │  Rating     Earned      Rate    │ │
│ │                                 │ │
│ │ [    Get In Touch    ]   [📌]  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**SwiftUI Implementation:**

```swift
// AuthorProfileModal.swift - Complete Redesign

struct AuthorProfileModal: View {
    let profile: UserProfile // Extended user info
    let onDismiss: () -> Void
    @State private var isBookmarked = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen backdrop
                BackdropImage(url: profile.profileImageUrl)
                
                // Content overlay
                VStack {
                    Spacer()
                    
                    // Info card
                    ProfileInfoCard(
                        profile: profile,
                        isBookmarked: $isBookmarked,
                        onContact: handleContact
                    )
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                }
            }
        }
    }
    
    private func handleContact() {
        // Show contact options action sheet
    }
}

struct BackdropImage: View {
    let url: String?
    
    var body: some View {
        ZStack {
            if let url = url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                } placeholder: {
                    defaultGradient
                }
            } else {
                defaultGradient
            }
            
            // Vignette effect
            LinearGradient(
                colors: [.clear, .black.opacity(0.4), .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    var defaultGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "#667eea"),
                Color(hex: "#764ba2")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ProfileInfoCard: View {
    let profile: UserProfile
    @Binding var isBookmarked: Bool
    let onContact: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Name with verification
            HStack {
                Text(profile.username)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if profile.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            
            // Bio (1-2 lines)
            if let bio = profile.bio {
                Text(bio)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Stats
            HStack(spacing: 0) {
                StatItem(
                    icon: "⭐",
                    value: String(format: "%.1f", profile.rating ?? 0.0),
                    label: "Rating"
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 50)
                
                StatItem(
                    icon: "💰",
                    value: "$\(profile.totalEarned ?? 0)+",
                    label: "Earned"
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 50)
                
                StatItem(
                    icon: "⏱",
                    value: "$\(profile.hourlyRate ?? 0)/hr",
                    label: "Rate"
                )
            }
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onContact) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Get In Touch")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                
                Button(action: { isBookmarked.toggle() }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                Text(value)
                    .fontWeight(.bold)
            }
            .font(.title3)
            .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}
```

---

## Design System Extensions

### Color Palette
```swift
extension DesignSystem.Colors {
    // Profile-specific colors
    static let profileBackdropOverlay = Color.black.opacity(0.6)
    static let statCardBackground = Color.white
    static let tagBackground = Color.blue.opacity(0.1)
    static let tagText = Color.blue
    static let verifiedBadge = Color.blue
}
```

### Typography Scale
```swift
extension DesignSystem.Typography {
    static let profileName = Font.system(size: 32, weight: .bold)
    static let statValue = Font.system(size: 20, weight: .semibold)
    static let statLabel = Font.system(size: 12, weight: .regular)
}
```

### Spacing
```swift
extension DesignSystem.Spacing {
    static let heroHeight: CGFloat = 280
    static let statCardHeight: CGFloat = 80
    static let pillPadding: CGFloat = 12
    static let cardPadding: CGFloat = 16
}
```

---

## Image Guidelines

### Profile Images
- **Aspect Ratio:** 4:3 or 16:9 (flexible, will be cropped)
- **Recommended Size:** 1200x900px or larger
- **File Formats:** JPEG, PNG, HEIC
- **Max File Size:** 10MB
- **Thumbnail:** 400x400px generated automatically

### Image Treatment
- Apply subtle darkening overlay for text legibility
- Blur background slightly on compact cards
- Use gradient overlays (top-to-bottom or radial)

### Placeholder States
- Use brand gradient when no image available
- Show user initials in center
- Subtle pattern overlay (optional)

---

## Accessibility Requirements

### VoiceOver Labels
```swift
.accessibilityLabel("Profile image")
.accessibilityHint("Tap to change profile photo")

.accessibilityElement(children: .combine)
.accessibilityLabel("Rating \(rating) out of 5, based on \(count) reviews")

.accessibilityLabel("Qualification: \(title), issued by \(organization)")
```

### Dynamic Type
- All text must scale with Dynamic Type
- Minimum touch target: 44x44 points
- Test at largest accessibility size

### Color Contrast
- Text on backdrop: WCAG AA minimum (4.5:1)
- Use dark gradient overlays for legibility
- Provide high contrast alternative if needed

---

## Animation & Interaction

### Micro-interactions
- **Image Upload:** Progress circle around avatar
- **Save Profile:** Checkmark animation
- **Expand Cards:** Smooth height animation with easing
- **Stat Counters:** Count up animation on appear

### Transitions
- **Modal Present:** Slide up with spring animation
- **Edit Mode:** Cross-fade between view/edit states
- **Image Load:** Fade in from thumbnail to full

### Gestures
- **Long Press:** Quick actions on cards
- **Swipe:** Dismiss modal
- **Pinch:** Zoom profile image (optional)

---

## Testing Scenarios

### Visual Testing
- [ ] Profile with all fields filled
- [ ] Profile with minimal data (just email)
- [ ] Profile with image vs. without
- [ ] Very long bio (2000 chars)
- [ ] Many skills (20+) with "+X" overflow
- [ ] Expired qualifications
- [ ] Various image aspect ratios

### Device Testing
- [ ] iPhone SE (smallest)
- [ ] iPhone Pro Max (largest)
- [ ] iPad (if supported)
- [ ] Landscape orientation
- [ ] Split screen (iPad)

### Accessibility Testing
- [ ] VoiceOver complete profile flow
- [ ] Largest Dynamic Type setting
- [ ] High contrast mode
- [ ] Reduce motion enabled
- [ ] Color blindness simulation

---

## Component File Structure

```
Features/Profile/
├── ProfileView.swift (main view)
├── Components/
│   ├── ProfileHeroImage.swift
│   ├── ProfileStatsGrid.swift
│   ├── BioSection.swift
│   ├── QualificationsSection.swift
│   ├── SkillsSection.swift
│   ├── HobbiesSection.swift
│   ├── ContactSection.swift
│   └── Shared/
│       ├── TagPill.swift
│       ├── StatCard.swift
│       ├── FlowLayout.swift
│       └── SectionContainer.swift
│
Features/Discover/
├── AuthorProfileModal.swift
└── Components/
    ├── BackdropImage.swift
    ├── ProfileInfoCard.swift
    └── StatItem.swift
```

---

**This mapping provides a direct reference for implementing the designs from the mockups. Each component is self-contained and follows the existing DesignSystem patterns.**
