import SwiftUI
import SwiftData
import LocalAuthentication

// MARK: - Student Dashboard View

struct StudentDashboardView: View {
    @Bindable var appState: AppStateManager
    @Bindable var contentEngine: ContentDeliveryEngine
    let shieldManager: ShieldManager
    let studentGrade: Int
    let onShowParentDashboard: () -> Void

    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @State private var selectedSubject: Subject? = nil
    @State private var showEndSessionError = false
    @State private var isLoadingVisionary = false
    @AppStorage("shieldsActive", store: UserDefaults(suiteName: KzuConstants.appGroupIdentifier)) private var shieldsActive = false

    private let orchestrator = CurriculumOrchestrator()

    var body: some View {
        ZStack(alignment: .top) {

            if let subject = selectedSubject {
                SubjectPathView(
                    subject: subject,
                    studentGrade: studentGrade,
                    contentEngine: contentEngine,
                    shieldManager: shieldManager,
                    appState: appState,
                    onBack: { selectedSubject = nil }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .trailing))
            } else {
                VStack(spacing: 0) {
                    // Countdown banner (when session is paused)
                    if appState.isSessionPaused {
                        sessionPausedBanner
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            headerSection
                                .padding(.top, 16)
                            quickStatsRow
                                .padding(.horizontal, 20)
                            subjectSection
                                .padding(.horizontal, 20)
                            if !recentSessions.isEmpty {
                                recentActivitySection
                                    .padding(.horizontal, 20)
                            }
                            footerSection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .leading))
            }
        }
        .background(Color.kzuIvory.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: selectedSubject)
        .alert("Verification Failed", isPresented: $showEndSessionError) {
            Button("OK") { }
        } message: {
            Text("Face ID or passcode verification is required to end the session.")
        }
    }

    // MARK: - Session Paused Banner

    private var sessionPausedBanner: some View {
        VStack(spacing: 10) {
            // Countdown
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                Text("Session paused — \(Int(appState.dashboardCountdown))s to return")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(
                            width: geo.size.width * (appState.dashboardCountdown / KzuConstants.backgroundGracePeriod),
                            height: 4
                        )
                        .animation(.linear(duration: 1), value: appState.dashboardCountdown)
                }
            }
            .frame(height: 4)

            // Buttons
            HStack(spacing: 12) {
                // Resume button
                Button {
                    appState.resumeSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Resume")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.kzuDeepNavy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
                }

                // End Session (no Face ID in banner)
                Button {
                    appState.endSession()
                    shieldManager.clearShields()
                    KzuActivitySchedule.stopMonitoring()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text("End Session")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.25)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.85), Color.orange.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Face ID / Passcode Authentication

    private func authenticate(reason: String, action: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if device supports biometrics or passcode
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        action()
                    } else {
                        // User cancelled or authentication failed
                        print("Authentication failed or cancelled: \(authError?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        } else {
            // No biometrics or passcode set up on device — allow by default
            action()
        }
    }

    // MARK: - Data

    private var todaySessions: [FocusSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.date) }
    }

    private var recentSessions: [FocusSession] {
        Array(sessions.prefix(3))
    }

    private var focusQuotient: Double {
        FocusMetricsCalculator.focusQuotient(sessions: Array(sessions.prefix(20)))
    }

    private var streak: Int {
        FocusMetricsCalculator.currentStreak(sessions: Array(sessions))
    }

    private var totalMinutesToday: Double {
        todaySessions.map(\.focusMinutes).reduce(0, +)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)

                HStack(spacing: 8) {
                    Text("Kzu")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)
                    
                    if shieldsActive {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.kzuSuccess)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            Spacer()

            // Streak badge
            if streak > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.kzuGold)
                    Text("\(streak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.kzuGold.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.kzuGold.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            QuickStatPill(
                icon: "checkmark.circle.fill",
                value: "\(todaySessions.filter(\.wasCompleted).count)",
                label: "Today",
                color: .kzuSuccess
            )

            QuickStatPill(
                icon: "brain.head.profile",
                value: String(format: "%.0f%%", focusQuotient),
                label: "Focus",
                color: .kzuFlowBlue
            )

            QuickStatPill(
                icon: "clock.fill",
                value: String(format: "%.0f", totalMinutesToday),
                label: "Minutes",
                color: .kzuGold
            )
        }
    }

    // MARK: - Subject Cards

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose Your Path")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kzuDeepNavy)

            VStack(spacing: 14) {
                SubjectCard(
                    subject: .literacy,
                    title: "Literacy",
                    subtitle: "Reading, phonics & vocabulary",
                    icon: "book.fill",
                    gradient: [
                        Color(red: 0.29, green: 0.56, blue: 0.85),
                        Color(red: 0.22, green: 0.44, blue: 0.72)
                    ]
                ) {
                    selectedSubject = .literacy
                }

                SubjectCard(
                    subject: .math,
                    title: "Mathematics",
                    subtitle: "Number sense, patterns & problems",
                    icon: "function",
                    gradient: [
                        Color(red: 0.36, green: 0.72, blue: 0.48),
                        Color(red: 0.28, green: 0.58, blue: 0.38)
                    ]
                ) {
                    selectedSubject = .math
                }

                // ── Visionary: individual theme tiles ────────────────────
                VisionaryThemeTileRow(
                    leftTheme:  .ai,
                    rightTheme: .robotics,
                    grade: studentGrade
                ) { theme in startVisionarySession(theme: theme) }

                VisionaryThemeTileRow(
                    leftTheme:  .data,
                    rightTheme: .ethics,
                    grade: studentGrade
                ) { theme in startVisionarySession(theme: theme) }
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.kzuDeepNavy)
                Spacer()
            }

            GlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        RecentSessionRow(session: session)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 16) {
            if shieldsActive {
                // End Session — requires Face ID
                Button {
                    authenticate(reason: "Verify to turn off Focus Mode") {
                        appState.endSession()
                        shieldManager.clearShields()
                        KzuActivitySchedule.stopMonitoring()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "faceid")
                            .font(.system(size: 14))
                        Text("Turn Off Focus Mode")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.75))
                    )
                }
            } else {
                // Start Global Session — Locks distraction apps
                Button {
                    authenticate(reason: "Verify to enable Focus Mode") {
                        try? shieldManager.applyShields()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14))
                        Text("Enable Focus Mode")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.kzuSuccess)
                    )
                }
            }

            Button {
                authenticate(reason: "Verify to access Parent Dashboard") {
                    onShowParentDashboard()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                    Text("Parent Dashboard")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.kzuSoftNavy.opacity(0.5))
            }
        }
    }

    // MARK: - Start Session

    private func startSession(subject: Subject) {
        Task {
            if let unit = await contentEngine.loadUnit(for: studentGrade, subject: subject) {
                await MainActor.run {
                    contentEngine.startSession(unit: unit)
                    try? shieldManager.applyShields()
                    try? KzuActivitySchedule.startLearningBlock()
                    appState.transitionTo(.learningBlock)
                }
            }
        }
    }

    /// Loads a themed Visionary unit and jumps straight to LearningBlock
    /// (skips SubjectPathView entirely — visionary has no roadmap UI).
    private func startVisionarySession(theme: VisionaryTheme) {
        let adapter = InnovationAdapter()
        if let unit = adapter.fetchUnit(for: studentGrade, theme: theme)
                    ?? adapter.randomUnit(for: studentGrade) {
            contentEngine.startSession(unit: unit)
        }
        try? shieldManager.applyShields()
        try? KzuActivitySchedule.startLearningBlock()
        appState.transitionTo(.learningBlock)
    }
}

// MARK: - Visionary Theme Tile Row

/// Full-width themed tile rows (one tile per row, matching SubjectCard dimensions).
struct VisionaryThemeTileRow: View {
    let leftTheme: VisionaryTheme
    let rightTheme: VisionaryTheme
    let grade: Int
    let onSelect: (VisionaryTheme) -> Void

    var body: some View {
        VStack(spacing: 14) {
            VisionaryThemeTile(theme: leftTheme)  { onSelect(leftTheme) }
            VisionaryThemeTile(theme: rightTheme) { onSelect(rightTheme) }
        }
    }
}

// MARK: - Visionary Theme Tile

struct VisionaryThemeTile: View {
    let theme: VisionaryTheme
    let action: () -> Void

    @State private var pressed = false

    private var icon: String {
        switch theme {
        case .ai:       return "brain.head.profile"
        case .robotics: return "cpu.fill"
        case .data:     return "chart.bar.fill"
        case .ethics:   return "scale.3d"
        }
    }

    private var shortLabel: String {
        switch theme {
        case .ai:       return "Artificial Intelligence"
        case .robotics: return "Robotics"
        case .data:     return "Data Science"
        case .ethics:   return "AI Ethics"
        }
    }

    private var subtitle: String {
        switch theme {
        case .ai:       return "Machine learning & how computers think"
        case .robotics: return "Programming, sensors & automation"
        case .data:     return "Patterns, statistics & visualisation"
        case .ethics:   return "Fairness, bias & responsible AI"
        }
    }

    private var accentColor: Color {
        switch theme {
        case .ai:       return Color.vizAccent
        case .robotics: return Color(red: 0.55, green: 0.85, blue: 0.60)
        case .data:     return Color(red: 0.88, green: 0.65, blue: 0.30)
        case .ethics:   return Color(red: 0.75, green: 0.55, blue: 0.92)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon circle — matches SubjectCard's 56×56
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(accentColor)
                }

                // Text block
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortLabel)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vizText)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.vizSubtext)
                }

                Spacer()

                // Arrow
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(accentColor.opacity(0.6))
            }
            .padding(20)  // matches SubjectCard
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.vizSurface)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(pressed ? 0.7 : 0.28), lineWidth: 1.5)
                }
            )
            .shadow(color: accentColor.opacity(pressed ? 0.30 : 0.14), radius: 10, x: 0, y: 6)
            .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 2)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.18), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: - Quick Stat Pill

struct QuickStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kzuDeepNavy)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.kzuSoftNavy)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.kzuCardBg)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Subject Card

struct SubjectCard: View {
    let subject: Subject
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    var isVisionary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                // Arrow
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Visionary: electric cyan shimmer overlay
                    if isVisionary {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.vizAccent.opacity(0.25), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Inner highlight
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )

                    // Visionary "FUTURE TECH" micro-badge
                    if isVisionary {
                        VStack {
                            HStack {
                                Spacer()
                                Text("✦ AI · ROBOTICS")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.vizAccent.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.vizAccent.opacity(0.18)))
                                    .padding(.top, 10)
                                    .padding(.trailing, 10)
                            }
                            Spacer()
                        }
                    }
                }
            )
            .shadow(color: isVisionary ? Color.vizAccent.opacity(0.35) : gradient[0].opacity(0.3), radius: 10, x: 0, y: 6)
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Session Row

struct RecentSessionRow: View {
    let session: FocusSession

    private var subjectIcon: String {
        switch session.subject {
        case "literacy":  return "book.fill"
        case "math":      return "function"
        case "visionary": return "cpu.fill"
        default:          return "star.fill"
        }
    }

    private var subjectColor: Color {
        switch session.subject {
        case "literacy":  return .kzuFlowBlue
        case "math":      return .kzuSuccess
        case "visionary": return .vizAccent
        default:          return .kzuGold
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(session.date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Subject icon
            Image(systemName: subjectIcon)
                .font(.system(size: 14))
                .foregroundStyle(subjectColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(subjectColor.opacity(0.12))
                )

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(session.subject.capitalized)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("\(Int(session.focusMinutes)) min · \(Int(session.accuracy * 100))% accuracy")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)
            }

            Spacer()

            // Status + time
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(session.wasCompleted ? Color.kzuSuccess : Color.kzuWarning)

                Text(timeAgo)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
    }
}
