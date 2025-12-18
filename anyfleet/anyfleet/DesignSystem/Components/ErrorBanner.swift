//
//  ErrorBanner.swift
//  anyfleet
//
//  Centralized error presentation component
//

import SwiftUI

struct ErrorBanner: View {
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            VStack(alignment: .leading) {
                Text(error.errorDescription ?? "An error occurred")
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                }
            }
            Spacer()
            if let onRetry = onRetry {
                Button("Retry", action: onRetry)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
        }
        .padding()
        .background(DesignSystem.Colors.error.opacity(0.1))
        .cornerRadius(12)
    }
}