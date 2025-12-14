import SwiftUI

enum DesignSystem {
    enum Colors {
        static let primary = Color(red: 0.126, green: 0.541, blue: 0.552) // #208A8D
        static let secondary = Color(red: 0.369, green: 0.322, blue: 0.251) // #5E5240
        static let success = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
        static let warning = Color(red: 0.902, green: 0.506, blue: 0.380) // #E68161
        static let error = Color(red: 1.0, green: 0.329, blue: 0.349) // #FF5459
        static let gold = Color(red: 0.98, green: 0.82, blue: 0.45) // accent for highlights
        static let oceanDeep = Color(red: 0.02, green: 0.28, blue: 0.36)
        
        // Dynamic surfaces for light/dark
        static let background = Color(.systemGroupedBackground)
        static let surface = Color(.secondarySystemGroupedBackground)
        static let surfaceAlt = Color(.tertiarySystemGroupedBackground)
        
        // Text
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        
        static let border = Color(.separator).opacity(0.4)
        static let onPrimary = Color.white
        static let onPrimaryMuted = Color.white.opacity(0.9)
        static let shadowStrong = Color.black.opacity(0.18)
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    enum Typography {
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 14, weight: .regular)
    }
    
    enum Gradients {
        static let primary = LinearGradient(
            colors: [
                Color(red: 0.102, green: 0.47, blue: 0.53),
                Color(red: 0.054, green: 0.32, blue: 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let subtleOverlay = LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    struct CardStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
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
    
    struct Pill: View {
        let text: String
        
        var body: some View {
            Text(text)
                .font(Typography.caption)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Colors.border.opacity(0.5))
                .foregroundColor(Colors.textPrimary)
                .cornerRadius(20)
        }
    }
    
    struct PrimaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(10)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    
    struct SecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Colors.surface)
                .foregroundColor(Colors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .cornerRadius(10)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    
    struct OutlineButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .foregroundColor(Colors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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
                .cornerRadius(10)
        }
    }
    
    struct SectionContainer: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Colors.border, lineWidth: 1)
                )
        }
    }

    enum SelectableCardStyle {
        static let cornerRadius: CGFloat = 14
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
        }
        
        init(elevation: Elevation = .medium) {
            self.elevation = elevation
        }
        
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Colors.surface)
                        .shadow(
                            color: Colors.shadowStrong.opacity(elevation.shadowOpacity),
                            radius: elevation.shadowRadius,
                            x: 0,
                            y: elevation.shadowYOffset
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
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
                        .font(.system(size: 56, weight: .light))
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
                        .font(.system(size: 24, weight: .semibold))
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
    
    func heroCardStyle(elevation: DesignSystem.HeroCardStyle.Elevation = .medium) -> some View {
        modifier(DesignSystem.HeroCardStyle(elevation: elevation))
    }
    
    func focalHighlight() -> some View {
        modifier(DesignSystem.FocalHighlight())
    }
}

