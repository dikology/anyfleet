import SwiftUI

struct CharterEditorView: View {
    @State private var viewModel: CharterEditorViewModel
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies

    init(viewModel: CharterEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    heroHeader

                    VStack(spacing: DesignSystem.Spacing.md) {
                        nameAndVesselCard
                        datesCard
                        visibilityCard
                        if viewModel.isCommunityManager && viewModel.form.visibility != .private {
                            PublishingAsSection(
                                currentUser: dependencies.authService.currentUser,
                                selectedCaptain: viewModel.selectedVirtualCaptain,
                                community: viewModel.selectedVirtualCaptainCommunity,
                                onChangeTap: { viewModel.showVirtualCaptainPicker = true }
                            )
                        }
                        destinationCard
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.bottom, FloatingTabBar.safeAreaInset + 80)
                }
            }

            footerCTA
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(DesignSystem.Typography.calloutSemibold)
                        Text(L10n.Charter.Editor.back)
                            .font(DesignSystem.Typography.headlineRegular)
                    }
                    .foregroundColor(DesignSystem.Colors.info)
                }
            }
        }
        .task {
            await viewModel.loadManagedCommunities()
            await viewModel.loadCharter()
            await viewModel.resolveVirtualCaptainSelectionFromStore()
        }
        .sheet(isPresented: $viewModel.showVirtualCaptainPicker) {
            VirtualCaptainPickerSheet(
                apiClient: dependencies.apiClient,
                currentUser: dependencies.authService.currentUser,
                managedCommunities: viewModel.managedCommunities,
                selectedCaptain: $viewModel.selectedVirtualCaptain
            )
        }
        .sheet(isPresented: $viewModel.showSignIn) {
            SignInModalView(
                title: "Sign In to Share",
                message: "Sign in to share your charter with the sailing community.",
                onSuccess: { viewModel.onSignInSuccess() },
                onDismiss: { viewModel.onSignInDismiss() }
            )
        }
        .animation(DesignSystem.Motion.standard, value: viewModel.showVirtualCaptainPicker)
        .animation(DesignSystem.Motion.standard, value: viewModel.showSignIn)
    }
}

// MARK: - Hero Header

private extension CharterEditorView {
    var heroHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                DesignSystem.Gradients.focalGoldRadial
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Spacing.cardCornerRadius)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 48, height: 48)

                        Image(systemName: "sailboat.fill")
                            .font(DesignSystem.Typography.pageTitleRegular)
                            .foregroundColor(DesignSystem.Colors.gold)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)

                    Text(viewModel.isNewCharter ? L10n.Charter.Editor.newTitle : L10n.Charter.Editor.editTitle)
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }
}

// MARK: - Bubble Cards

private extension CharterEditorView {
    var nameAndVesselCard: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    DesignSystem.Form.FieldLabelMicro(title: L10n.charterCreateName)
                    DesignSystem.Form.FormTextField(
                        placeholder: L10n.charterCreateNamePlaceholder,
                        text: $viewModel.form.name
                    )
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    DesignSystem.Form.FieldLabelMicro(title: L10n.charterCreateYourVessel)
                    DesignSystem.Form.BubbleTextField(
                        placeholder: L10n.charterCreateVesselNamePlaceholder,
                        text: $viewModel.form.vessel,
                        leadingIcon: "magnifyingglass"
                    )
                }
            }
        }
    }

    var datesCard: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    dateBlock(
                        label: L10n.charterCreateStartDate,
                        date: viewModel.form.startDate
                    ) {
                        showStartDatePicker = true
                    }

                    dateBlock(
                        label: L10n.charterCreateEndDate,
                        date: viewModel.form.endDate
                    ) {
                        showEndDatePicker = true
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)

                HStack {
                    Text(L10n.charterCreateChooseYourVoyageDates)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("\(viewModel.form.nights) \(L10n.charterCreateNights)")
                        .font(DesignSystem.Typography.captionBold)
                        .foregroundColor(DesignSystem.Colors.gold)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.gold.opacity(0.1))
                        .cornerRadius(DesignSystem.Spacing.cornerRadiusPill)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Spacing.cornerRadiusPill)
                                .stroke(DesignSystem.Colors.gold.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .sheet(isPresented: $showStartDatePicker) {
            DatePickerModal(
                title: L10n.charterCreateStartDate,
                selectedDate: $viewModel.form.startDate
            )
        }
        .sheet(isPresented: $showEndDatePicker) {
            DatePickerModal(
                title: L10n.charterCreateEndDate,
                selectedDate: $viewModel.form.endDate
            )
        }
        .animation(DesignSystem.Motion.standard, value: showStartDatePicker)
        .animation(DesignSystem.Motion.standard, value: showEndDatePicker)
    }

    private func dateBlock(label: String, date: Date, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            DesignSystem.Form.FieldLabelMicro(title: label)
            Button(action: action) {
                HStack {
                    Text(date, style: .date)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.gold.opacity(0.6))
                }
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.surfaceAlt)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusSmall)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var visibilityCard: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                DesignSystem.Form.FieldLabelMicro(title: L10n.Charter.Editor.visibilityTitle)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(CharterVisibility.selectableCases, id: \.self) { option in
                        visibilitySegment(option)
                    }
                }
                .padding(DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.background)
                .cornerRadius(DesignSystem.Spacing.cornerRadiusControl)

                Text(viewModel.form.visibility.description)
                    .font(DesignSystem.Typography.micro)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineSpacing(4)
            }
        }
    }

    private func visibilitySegment(_ option: CharterVisibility) -> some View {
        Button {
            viewModel.onVisibilityChanged(option)
        } label: {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: option.systemImage)
                    .font(DesignSystem.Typography.caption)
                Text(option.displayName)
                    .font(DesignSystem.Typography.nanoMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .foregroundColor(viewModel.form.visibility == option
                ? DesignSystem.Colors.textPrimary
                : DesignSystem.Colors.textSecondary)
            .background(
                viewModel.form.visibility == option
                    ? DesignSystem.Colors.surfaceAlt
                    : Color.clear
            )
            .cornerRadius(DesignSystem.Spacing.cornerRadiusSmall)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Visibility: \(option.displayName)")
        .accessibilityAddTraits(viewModel.form.visibility == option ? .isSelected : [])
    }

    var destinationCard: some View {
        DesignSystem.Form.BubbleCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                DesignSystem.Form.FieldLabelMicro(title: L10n.charterCreateDestination)
                DestinationSearchField(
                    query: $viewModel.form.destinationQuery,
                    selectedPlace: $viewModel.form.selectedPlace,
                    searchService: viewModel.locationSearchService
                )
            }
        }
    }
}

// MARK: - Footer CTA

private extension CharterEditorView {
    var footerCTA: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button {
                Task { await viewModel.saveCharter() }
            } label: {
                Text(viewModel.isNewCharter ? L10n.charterSummaryCreateCharter : L10n.Charter.Editor.saveTitle)
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DesignSystem.Gradients.primaryButton)
                    .cornerRadius(DesignSystem.Spacing.cardCornerRadius)
                    .shadow(color: DesignSystem.Colors.gold.opacity(0.2), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isValid)
            .opacity(viewModel.isValid ? 1 : 0.6)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, DesignSystem.Spacing.xl)
        .padding(.bottom, FloatingTabBar.safeAreaInset)
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.background.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Previews

#Preview {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        return CharterEditorView(
            viewModel: CharterEditorViewModel(
                charterStore: dependencies.charterStore,
                charterID: nil,
                onDismiss: {}
            )
        )
        .environment(\.appDependencies, dependencies)
    }
}

#Preview("With Mock Form") {
    MainActor.assumeIsolated {
        let dependencies = try! AppDependencies.makeForTesting()
        return CharterEditorView(
            viewModel: CharterEditorViewModel(
                charterStore: dependencies.charterStore,
                charterID: nil,
                onDismiss: {},
                initialForm: .mock
            )
        )
        .environment(\.appDependencies, dependencies)
    }
}
