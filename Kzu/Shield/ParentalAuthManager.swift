// ParentalAuthManager.swift
// Kzu — FamilyControls Authorization & App Selection Flow

import SwiftUI
import FamilyControls

// MARK: - Authorization Status

enum KzuAuthStatus: Equatable {
    case notDetermined
    case approved
    case denied
    case error(String)
}

// MARK: - Parental Auth Manager

@Observable
final class ParentalAuthManager {

    // MARK: Properties
    var authStatus: KzuAuthStatus = .notDetermined
    var selectedApps = FamilyActivitySelection()
    var isShowingPicker = false

    // MARK: - Request Authorization

    /// Requests FamilyControls authorization from the parent.
    /// This triggers the system Screen Time authentication dialog.
    @MainActor
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authStatus = .approved
        } catch {
            authStatus = .denied
        }
    }

    // MARK: - Check Existing Authorization

    @MainActor
    func checkAuthorizationStatus() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            authStatus = .notDetermined
        case .approved:
            authStatus = .approved
        case .denied:
            authStatus = .denied
        @unknown default:
            authStatus = .error("Unknown authorization state")
        }
    }

    // MARK: - Show App Picker

    func showAppPicker() {
        isShowingPicker = true
    }

    // MARK: - Has Valid Selection

    var hasValidSelection: Bool {
        !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
    }
}

// MARK: - Authorization Gate View

/// A view that gates the app experience behind parental Screen Time authorization.
/// Presented with aspirational copy and neo-skeuomorphic styling.
struct AuthorizationGateView: View {
    @Bindable var authManager: ParentalAuthManager
    let onAuthorized: () -> Void

    var body: some View {
        ZStack {
            Color.kzuIvory.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App icon / branding
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.kzuDeepNavy, .kzuSoftNavy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Text("Kzu")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)

                    Text("Focus. Learn. Play.")
                        .font(KzuTypography.journeyCaption)
                        .foregroundStyle(Color.kzuSoftNavy)
                        .tracking(3)
                        .textCase(.uppercase)
                }

                Spacer()

                // Status-specific content
                VStack(spacing: 24) {
                    switch authManager.authStatus {
                    case .notDetermined:
                        parentalPromptSection

                    case .approved:
                        approvedSection

                    case .denied:
                        deniedSection

                    case .error(let message):
                        errorSection(message)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    // MARK: - Sections

    private var parentalPromptSection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.kzuFlowBlue)

                Text("A Parent's Blessing")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("Kzu needs Screen Time permission to create a focused, distraction-free learning environment for your child.")
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .multilineTextAlignment(.center)

                NeoSkeuomorphicButton("Grant Permission", icon: "checkmark.shield") {
                    Task {
                        await authManager.requestAuthorization()
                    }
                }
            }
        }
    }

    private var approvedSection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.kzuSuccess)

                Text("You're All Set")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("Screen Time permission granted. Your child's focus journey begins now.")
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .multilineTextAlignment(.center)

                NeoSkeuomorphicButton("Begin the Journey", icon: "arrow.right") {
                    onAuthorized()
                }
            }
        }
        .onAppear {
            // Auto-proceed after a brief moment for delight
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onAuthorized()
            }
        }
    }

    private var deniedSection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.kzuWarning)

                Text("Permission Needed")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("Without Screen Time access, Kzu cannot protect your child's focus. Please enable it in Settings → Screen Time.")
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .multilineTextAlignment(.center)

                NeoSkeuomorphicButton("Try Again", icon: "arrow.clockwise", isPrimary: false) {
                    Task {
                        await authManager.requestAuthorization()
                    }
                }
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "xmark.octagon")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.kzuError)

                Text("Something Went Wrong")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                Text(message)
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
