import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthService.self) private var authService
    @State private var appError: AppError?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Anyfleet")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Sign in to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.email, .fullName]
                },
                onCompletion: { result in
                    Task {
                        await handleSignIn(result: result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .frame(maxWidth: 375)
            .disabled(isLoading)
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .padding(.top, DesignSystem.Spacing.sm)
            }
            
            if let error = appError {
                ErrorBanner(
                    error: error,
                    onDismiss: { appError = nil },
                    onRetry: nil
                )
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        appError = nil
        
        do {
            try await authService.handleAppleSignIn(result: result)
        } catch {
            appError = error.toAppError()
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview("Sign In View") { @MainActor in
    SignInView()
        .environment(AuthService())
}