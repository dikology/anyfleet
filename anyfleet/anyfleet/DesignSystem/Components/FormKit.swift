import SwiftUI
import UIKit

/// Common building blocks for forms, selection flows, and summaries.
extension DesignSystem {
    enum Form {
        /// Bubble-style card for form sections (dark surface, subtle border, rounded).
        struct BubbleCard<Content: View>: View {
            @ViewBuilder let content: Content

            init(@ViewBuilder content: () -> Content) {
                self.content = content()
            }

            var body: some View {
                content
                    .padding(DesignSystem.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            }
        }

        /// Small uppercase label for form fields.
        struct FieldLabelMicro: View {
            let title: String

            var body: some View {
                Text(title.uppercased())
                    .font(DesignSystem.Typography.micro)
                    .fontWeight(.semibold)
                    .tracking(0.8)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }

        /// Styled text field for bubble card forms.
        struct BubbleTextField: View {
            let placeholder: String
            @Binding var text: String
            var leadingIcon: String? = nil
            var trailingIcon: String? = nil
            var onTrailingTap: (() -> Void)? = nil

            var body: some View {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let icon = leadingIcon {
                        Image(systemName: icon)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .autocorrectionDisabled()
                    if let icon = trailingIcon {
                        Button(action: { onTrailingTap?() }) {
                            Image(systemName: icon)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.info)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceAlt)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusSmall)
            }
        }
        
        /// A padded section with a title/subtitle and consistent surface styling.
        struct Section<Content: View>: View {
            let title: String
            let subtitle: String?
            let spacing: CGFloat
            @ViewBuilder let content: Content
            
            init(
                title: String,
                subtitle: String? = nil,
                spacing: CGFloat = DesignSystem.Spacing.md,
                @ViewBuilder content: () -> Content
            ) {
                self.title = title
                self.subtitle = subtitle
                self.spacing = spacing
                self.content = content()
            }
            
            var body: some View {
                VStack(alignment: .leading, spacing: spacing) {
                    DesignSystem.SectionHeader(title, subtitle: subtitle)
                    content
                }
                .sectionContainer()
            }
        }
        
        /// Label wrapper used above text fields or pickers.
        struct FieldLabel: View {
            let title: String
            let helper: String?
            
            init(_ title: String, helper: String? = nil) {
                self.title = title
                self.helper = helper
            }
            
            var body: some View {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    if let helper, !helper.isEmpty {
                        Text(helper)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.8))
                    }
                }
            }
        }
        
        /// A reusable text field component following iOS best practices.
        /// Provides consistent styling, accessibility, and user experience.
        /// Use this component inside Form.Section for consistent form layouts.
        struct FormTextField: View {
            let placeholder: String
            @Binding var text: String
            let keyboardType: UIKeyboardType
            let autocapitalization: TextInputAutocapitalization
            
            init(
                placeholder: String,
                text: Binding<String>,
                keyboardType: UIKeyboardType = .default,
                autocapitalization: TextInputAutocapitalization = .sentences
            ) {
                self.placeholder = placeholder
                self._text = text
                self.keyboardType = keyboardType
                self.autocapitalization = autocapitalization
            }
            
            var body: some View {
                SwiftUI.TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .formFieldStyle()
                    .accessibilityLabel(placeholder)
            }
        }
        
        /// Horizontal progress indicator with percentage text.
        struct Progress: View {
            let progress: Double // 0...1
            let label: String
            
            var body: some View {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text(label)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(DesignSystem.Typography.footnoteSemibold)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DesignSystem.Colors.surfaceAlt)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.primary, DesignSystem.Colors.gold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * min(max(progress, 0), 1))
                                .animation(DesignSystem.Motion.standard, value: progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusMedium)
            }
        }
        
        /// Gradient hero for top-of-form context.
        struct Hero: View {
            let title: String
            let subtitle: String
            let icon: String?
            let height: CGFloat
            let gradient: LinearGradient

            init(
                title: String,
                subtitle: String,
                icon: String? = "sailboat.fill",
                height: CGFloat = 140,
                gradient: LinearGradient = LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.22, blue: 0.32),
                        Color(red: 0.04, green: 0.33, blue: 0.47)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                self.title = title
                self.subtitle = subtitle
                self.icon = icon
                self.height = height
                self.gradient = gradient
            }

            var body: some View {
                gradient
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay(
                        Group {
                            if let icon {
                                Image(systemName: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180, height: 180)
                                    .foregroundColor(Color.white.opacity(0.08))
                                    .padding()
                            }
                        },
                        alignment: .trailing
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(title)
                                .font(DesignSystem.Typography.emptyStateTitleSemibold)
                                .foregroundColor(.white)
                            Text(subtitle)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.onPrimaryMuted)
                        }
                        .padding(DesignSystem.Spacing.xl)
                    }
                    .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
            }
        }
        
        /// A simple summary row with leading icon and trailing check.
        struct SummaryRow: View {
            let icon: String
            let title: String
            let value: String
            let detail: String?
            
            var body: some View {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    Text(icon)
                        .font(DesignSystem.Typography.insetHeadline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(value)
                            .font(DesignSystem.Typography.subheader)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surfaceAlt)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusMedium)
            }
        }
    }
}

#Preview("Hero Light") {
    DesignSystem.Form.Hero(
        title: "Set sail on your next adventure",
        subtitle: "From dream to reality in a few guided steps."
    )
    .padding()
}

#Preview("Hero Dark") {
    DesignSystem.Form.Hero(
        title: "Set sail on your next adventure",
        subtitle: "From dream to reality in a few guided steps."
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Hero Dynamic Type XL") {
    DesignSystem.Form.Hero(
        title: "Set sail on your next adventure",
        subtitle: "From dream to reality in a few guided steps."
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility2)
}

