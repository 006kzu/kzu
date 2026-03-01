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
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            ) { _ in
                appState.appDidEnterBackground()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
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

    var body: some View {
        ZStack {
            switch appState.currentPhase {
            case .idle:
                if authManager.authStatus != .approved {
                    AuthorizationGateView(authManager: authManager) {
                        if hasCompletedOnboarding {
                            appState.transitionTo(.idle)
                        } else {
                            appState.transitionTo(.onboarding)
                        }
                    }
                } else {
                    idleView
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
                    grade: studentGrade
                )

            case .gameHub:
                GameHubView(
                    appState: appState,
                    rewardTier: contentEngine.currentRewardTier
                )
            }
        }
        .animation(.easeInOut(duration: 0.6), value: appState.currentPhase)
        .sheet(isPresented: $showDashboard) {
            ParentalDashboardView()
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        ZStack {
            Color.kzuIvory.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Branding
                VStack(spacing: 8) {
                    Text("Kzu")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)

                    Text("Your focus journey awaits")
                        .font(KzuTypography.journeyCaption)
                        .foregroundStyle(Color.kzuSoftNavy)
                }

                // Session count
                if appState.sessionsCompletedToday > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.kzuGold)
                        Text("\(appState.sessionsCompletedToday) sessions today")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.kzuSoftNavy)
                    }
                }

                Spacer()

                // Begin Flow button
                NeoSkeuomorphicButton("Begin Your Flow", icon: "play.fill") {
                    startLearningSession()
                }

                // Parent dashboard access
                Button {
                    showDashboard = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                        Text("Parent Dashboard")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy.opacity(0.5))
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Start Session

    private func startLearningSession() {
        // Load curriculum for the student's grade
        let subject: Subject = Bool.random() ? .literacy : .math  // Alternate for MVP
        if let unit = contentEngine.loadUnit(for: studentGrade, subject: subject) {
            contentEngine.startSession(unit: unit)
        }

        // Apply shields
        try? shieldManager.applyShields()

        // Start DeviceActivity monitoring
        try? KzuActivitySchedule.startLearningBlock()

        // Transition
        appState.transitionTo(.learningBlock)
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
