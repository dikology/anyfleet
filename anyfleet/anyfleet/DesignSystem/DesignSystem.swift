import SwiftUI

enum DesignSystem {

    /// Shared motion presets (DESIGN.md — springs for cards; ease for sheets and state).
    enum Motion {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let springQuick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.9)
        static let skeleton = SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }
    struct CardStyle: ViewModifier {
        @Environment(\.colorScheme) private var colorScheme

        func body(content: Content) -> some View {
            content
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.06) : Colors.border,
                            lineWidth: 1
                        )
                )
                .shadow(color: Colors.shadowStrong.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
    
    struct SectionHeader: View {
        let title: String
        let subtitle: String?
        
        init(_ title: String, subtitle: String? = nil) {
            self.title = title
            self.subtitle = subtitle
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Immersive section label — uppercase, wide tracking, muted. For "Data Dashboard", "Communities", etc.
    struct SectionLabel: View {
        let text: String

        init(_ text: String) {
            self.text = text
        }

        var body: some View {
            Text(text.uppercased())
                .font(Typography.microBold)
                .tracking(1.2)
                .foregroundColor(Colors.textSecondary)
        }
    }

    /// Glass-style panel — backdrop blur, semi-transparent, subtle border. For floating buttons.
    struct GlassPanel: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusMedium)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
    
    struct Pill: View {
        let text: String
        
        var body: some View {
            Text(text)
                .font(Typography.caption)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Colors.border.opacity(0.5))
                .foregroundColor(Colors.textPrimary)
                .cornerRadius(Spacing.cornerRadiusPill)
        }
    }
    
    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Typography.subheader)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(Spacing.cornerRadiusSmall)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    
    struct SecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Typography.subheader)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Colors.surface)
                .foregroundColor(Colors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .cornerRadius(Spacing.cornerRadiusSmall)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    
    struct OutlineButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Typography.subheader)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .foregroundColor(Colors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    
    struct FormFieldStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .textFieldStyle(.plain)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Colors.surfaceAlt)
                .cornerRadius(Spacing.cornerRadiusSmall)
        }
    }
    
    struct SectionContainer: ViewModifier {
        @Environment(\.colorScheme) private var colorScheme

        func body(content: Content) -> some View {
            content
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardCornerRadius, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.06) : Colors.border,
                            lineWidth: 1
                        )
                )
        }
    }

    enum SelectableCardStyle {
        static let cornerRadius: CGFloat = Spacing.cornerRadiusControl
        static let borderWidth: CGFloat = 1
        static let selectedBorderWidth: CGFloat = 2
        static let shadowRadius: CGFloat = 4
        static let shadowRadiusSelected: CGFloat = 10
        static let shadowYOffset: CGFloat = 2
        static let shadowYOffsetSelected: CGFloat = 6
        static let shadowColor: Color = .black
        static let selectedBorderColor: Color = Colors.primary
    }
    
    enum Layout {
        struct VStackSpaced<Content: View>: View {
            let spacing: CGFloat
            let alignment: HorizontalAlignment
            @ViewBuilder let content: Content
            
            init(
                alignment: HorizontalAlignment = .leading,
                spacing: CGFloat = DesignSystem.Spacing.md,
                @ViewBuilder content: () -> Content
            ) {
                self.alignment = alignment
                self.spacing = spacing
                self.content = content()
            }
            
            var body: some View {
                VStack(alignment: alignment, spacing: spacing) {
                    content
                }
            }
        }
    }
    
    // MARK: - Cinematic Composition Elements
    
    struct HeroCardStyle: ViewModifier {
        let elevation: Elevation
        @Environment(\.colorScheme) private var colorScheme

        enum Elevation {
            case low, medium, high

            var shadowRadius: CGFloat {
                switch self {
                case .low: return 6
                case .medium: return 12
                case .high: return 20
                }
            }

            var shadowYOffset: CGFloat {
                switch self {
                case .low: return 2
                case .medium: return 4
                case .high: return 8
                }
            }

            var shadowOpacity: Double {
                switch self {
                case .low: return 0.08
                case .medium: return 0.12
                case .high: return 0.16
                }
            }

            // Extra shadow depth in dark mode so photo cards pop against the dark canvas
            var darkModeShadowOpacity: Double {
                switch self {
                case .low: return 0.22
                case .medium: return 0.32
                case .high: return 0.45
                }
            }
        }

        init(elevation: Elevation = .medium) {
            self.elevation = elevation
        }

        func body(content: Content) -> some View {
            let effectiveShadowOpacity = colorScheme == .dark
                ? elevation.darkModeShadowOpacity
                : elevation.shadowOpacity

            return content
                .background(
                    RoundedRectangle(cornerRadius: Spacing.cardCornerRadius)
                        .fill(Colors.surface)
                        .shadow(
                            color: Colors.shadowStrong.opacity(effectiveShadowOpacity),
                            radius: elevation.shadowRadius,
                            x: 0,
                            y: elevation.shadowYOffset
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardCornerRadius)
                        .stroke(
                            colorScheme == .dark
                                ? LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Colors.border.opacity(0.6),
                                        Colors.border.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: 1
                        )
                )
        }
    }
    
    struct FocalHighlight: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay(
                    LinearGradient(
                        colors: [
                            Colors.gold.opacity(0.15),
                            Colors.gold.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    struct EmptyStateHero: View {
        let icon: String
        let title: String
        let message: String
        let accentColor: Color
        
        init(
            icon: String,
            title: String,
            message: String,
            accentColor: Color = Colors.primary
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.accentColor = accentColor
        }
        
        var body: some View {
            VStack(spacing: Spacing.xl) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.15),
                                    accentColor.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: icon)
                        .font(Typography.symbolPlateXXL)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.bottom, Spacing.sm)
                
                VStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.pageTitleSemibold)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text(message)
                        .font(Typography.body)
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Spacing.xxl)
        }
    }

    struct EmptyStateView: View {
        let icon: String
        let title: String
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?

        init(
            icon: String,
            title: String,
            message: String,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }

        var body: some View {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.15),
                                    DesignSystem.Colors.primary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: icon)
                        .font(Typography.symbolPlateXL)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(title)
                        .font(Typography.emptyStateHeadline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                            Text(actionTitle)
                        }
                        .font(Typography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(Spacing.cornerRadiusMedium)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.background,
                        DesignSystem.Colors.oceanDeep.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    struct TimelineIndicator: View {
        let isActive: Bool
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(isActive ? Colors.primary : Colors.border)
                    .frame(width: 8, height: 8)
                
                if isActive {
                    Circle()
                        .fill(Colors.primary.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }
        }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(DesignSystem.CardStyle())
    }
    
    func formFieldStyle() -> some View {
        modifier(DesignSystem.FormFieldStyle())
    }
    
    func sectionContainer() -> some View {
        modifier(DesignSystem.SectionContainer())
    }

    func glassPanel() -> some View {
        modifier(DesignSystem.GlassPanel())
    }
    
    func heroCardStyle(elevation: DesignSystem.HeroCardStyle.Elevation = .medium) -> some View {
        modifier(DesignSystem.HeroCardStyle(elevation: elevation))
    }
    
    func focalHighlight() -> some View {
        modifier(DesignSystem.FocalHighlight())
    }
}

