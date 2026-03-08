// KzuApp.swift
// Kzu — App Entry Point

import SwiftUI
import SwiftData
import FamilyControls

// MARK: - App Entry

@main
struct KzuApp: App {
    @State private var appState = AppStateManager()
    @State private var authManager = ParentalAuthManager()
    @State private var shieldManager = ShieldManager()
    @State private var contentEngine = ContentDeliveryEngine()
    @Environment(\.scenePhase) private var scenePhase

    // Student profile (set during onboarding)
    @AppStorage("studentGrade") private var studentGrade: Int = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootView(
                appState: appState,
                authManager: authManager,
                shieldManager: shieldManager,
                contentEngine: contentEngine,
                studentGrade: $studentGrade,
                hasCompletedOnboarding: $hasCompletedOnboarding
            )
            .onAppear {
                authManager.checkAuthorizationStatus()
                appState.requestNotificationPermission()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                appState.appDidEnterBackground()
            } else if newPhase == .active {
                appState.appWillEnterForeground()
                checkForExtensionMessages()
            }
        }
        .modelContainer(for: [FocusSession.self])
    }

    /// Checks shared UserDefaults for messages from the DeviceActivityMonitor extension
    private func checkForExtensionMessages() {
        let shared = UserDefaults(suiteName: KzuConstants.appGroupIdentifier)

        // Check for reset penalty
        if shared?.bool(forKey: "resetPending") == true {
            appState.applyResetPenalty()
            shared?.set(false, forKey: "resetPending")
        }

        // Check for phase transition from extension
        if let phase = shared?.string(forKey: "currentPhase") {
            if phase == "gameHub" && appState.currentPhase == .learningBlock {
                shieldManager.clearShields()
                appState.transitionTo(.gameHub)
            }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Bindable var appState: AppStateManager
    @Bindable var authManager: ParentalAuthManager
    let shieldManager: ShieldManager
    @Bindable var contentEngine: ContentDeliveryEngine
    @Binding var studentGrade: Int
    @Binding var hasCompletedOnboarding: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var showDashboard = false
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false

    var body: some View {
        ZStack {
            switch appState.currentPhase {
            case .idle:
                if authManager.authStatus != .approved && !hasSkippedAuth {
                    AuthorizationGateView(authManager: authManager) {
                        hasSkippedAuth = true
                        if hasCompletedOnboarding {
                            appState.transitionTo(.idle)
                        } else {
                            appState.transitionTo(.onboarding)
                        }
                    }
                } else {
                    StudentDashboardView(
                        appState: appState,
                        contentEngine: contentEngine,
                        shieldManager: shieldManager,
                        studentGrade: studentGrade,
                        onShowParentDashboard: { showDashboard = true }
                    )
                }

            case .requestingAuth:
                AuthorizationGateView(authManager: authManager) {
                    appState.transitionTo(.idle)
                }

            case .onboarding:
                OnboardingView(
                    selectedGrade: $studentGrade,
                    authManager: authManager,
                    shieldManager: shieldManager
                ) {
                    hasCompletedOnboarding = true
                    appState.transitionTo(.idle)
                }

            case .learningBlock, .explorerMode:
                LearningBlockView(
                    appState: appState,
                    contentEngine: contentEngine,
                    grade: studentGrade,
                    onExit: {
                        appState.pauseSession()
                    }
                )

            case .gameHub:
                GameHubView(
                    appState: appState,
                    rewardTier: contentEngine.currentRewardTier,
                    onExit: {
                        appState.pauseSession()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.6), value: appState.currentPhase)
        .onAppear {
            // Check Screen Time authorization on launch
            authManager.checkAuthorizationStatus()
            appState.requestNotificationPermission()
        }
        .sheet(isPresented: $showDashboard) {
            ParentalDashboardView(authManager: authManager)
        }
    }

}

// MARK: - Simple Onboarding View

struct OnboardingView: View {
    @Binding var selectedGrade: Int
    let authManager: ParentalAuthManager
    let shieldManager: ShieldManager
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.kzuIvory.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("Welcome to Kzu")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("Select your grade to personalize your learning path.")
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Grade picker
                GlassCard {
                    VStack(spacing: 16) {
                        Text("I'm in grade...")
                            .font(KzuTypography.foundationalCaption)
                            .foregroundStyle(Color.kzuSoftNavy)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(0..<9) { grade in
                                let label = grade == 0 ? "K" : "\(grade)"
                                Button {
                                    selectedGrade = grade
                                } label: {
                                    Text(label)
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .foregroundStyle(
                                            selectedGrade == grade ? Color.kzuIvory : Color.kzuDeepNavy
                                        )
                                        .frame(width: 56, height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    selectedGrade == grade
                                                        ? Color.kzuDeepNavy
                                                        : Color.kzuSurface
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                // App selection (if authorized)
                if authManager.authStatus == .approved {
                    NeoSkeuomorphicButton("Select Distraction Apps", icon: "apps.iphone", isPrimary: false) {
                        authManager.showAppPicker()
                    }
                    .familyActivityPicker(
                        isPresented: Binding(
                            get: { authManager.isShowingPicker },
                            set: { authManager.isShowingPicker = $0 }
                        ),
                        selection: Binding(
                            get: { authManager.selectedApps },
                            set: { selection in
                                authManager.selectedApps = selection
                                shieldManager.updateSelection(selection)
                            }
                        )
                    )
                }

                Spacer()

                NeoSkeuomorphicButton("Continue", icon: "arrow.right") {
                    onComplete()
                }
                .padding(.bottom, 40)
            }
        }
    }
}
