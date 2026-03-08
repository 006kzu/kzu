// ParentalDashboardView.swift
// Kzu — Focus Growth parental insights

import SwiftUI
import SwiftData
import Charts

// MARK: - Parental Dashboard View

/// Protected behind FaceID/passcode. Shows Focus Growth charts,
/// session breakdowns, and accuracy trends.
struct ParentalDashboardView: View {
    @Bindable var authManager: ParentalAuthManager
    
    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @State private var selectedTimeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case allTime = "All Time"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .allTime: return nil
            }
        }
    }

    private var filteredSessions: [FocusSession] {
        guard let days = selectedTimeRange.days else { return sessions }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            dashboardContent
        }
    }



    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Hero metrics
                heroMetrics
                    .padding(.horizontal)

                // Focus Growth Chart
                focusGrowthChart
                    .padding(.horizontal)

                // Session Breakdown
                sessionBreakdown
                    .padding(.horizontal)

                // Accuracy by Subject
                accuracySection
                    .padding(.horizontal)

                // App Settings
                settingsSection
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(Color.kzuIvory.ignoresSafeArea())
        .navigationTitle("Focus Growth")
        .navigationBarTitleDisplayMode(.large)
        .familyActivityPicker(
            isPresented: $authManager.isShowingPicker,
            selection: $authManager.selectedApps
        )
        .onChange(of: authManager.isShowingPicker) { oldValue, newValue in
            if oldValue == true && newValue == false {
                authManager.saveSelection()
            }
        }
    }

    // MARK: - Hero Metrics

    private var heroMetrics: some View {
        let fq = FocusMetricsCalculator.focusQuotient(sessions: filteredSessions)
        let streak = FocusMetricsCalculator.currentStreak(sessions: Array(sessions))
        let totalMinutes = FocusMetricsCalculator.totalFocusMinutes(sessions: filteredSessions)
        let goldenRate = FocusMetricsCalculator.goldenKeyRate(sessions: filteredSessions)

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            MetricCard(
                title: "Focus Quotient",
                value: String(format: "%.0f%%", fq),
                icon: "brain.head.profile",
                color: .kzuFlowBlue
            )

            MetricCard(
                title: "Day Streak",
                value: "\(streak)",
                icon: "flame.fill",
                color: .kzuWarning
            )

            MetricCard(
                title: "Focus Minutes",
                value: String(format: "%.0f", totalMinutes),
                icon: "clock.fill",
                color: .kzuSuccess
            )

            MetricCard(
                title: "Golden Key Rate",
                value: String(format: "%.0f%%", goldenRate * 100),
                icon: "key.fill",
                color: .kzuGold
            )
        }
    }

    // MARK: - Focus Growth Chart

    private var focusGrowthChart: some View {
        let trendData = FocusMetricsCalculator.focusGrowthTrend(
            sessions: filteredSessions,
            days: selectedTimeRange.days ?? 30
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Focus Growth")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                if trendData.isEmpty {
                    Text("Complete sessions to see your growth chart.")
                        .font(KzuTypography.journeyCaption)
                        .foregroundStyle(Color.kzuSoftNavy)
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(trendData, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("FQ", item.fq)
                        )
                        .foregroundStyle(Color.kzuFlowBlue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("FQ", item.fq)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.kzuFlowBlue.opacity(0.2), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisValueLabel {
                                Text("\(value.as(Int.self) ?? 0)%")
                                    .font(.system(size: 10))
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Color.kzuSurface)
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Session Breakdown

    private var sessionBreakdown: some View {
        let completed = filteredSessions.filter(\.wasCompleted).count
        let reset = filteredSessions.filter(\.wasReset).count
        let total = filteredSessions.count

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sessions")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(total)")
                            .font(KzuTypography.dashboardMetric)
                            .foregroundStyle(Color.kzuDeepNavy)
                        Text("Total")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.kzuSoftNavy)
                    }

                    VStack(spacing: 4) {
                        Text("\(completed)")
                            .font(KzuTypography.dashboardMetric)
                            .foregroundStyle(Color.kzuSuccess)
                        Text("Completed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.kzuSoftNavy)
                    }

                    VStack(spacing: 4) {
                        Text("\(reset)")
                            .font(KzuTypography.dashboardMetric)
                            .foregroundStyle(Color.kzuWarning)
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.kzuSoftNavy)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Accuracy Section

    private var accuracySection: some View {
        let avgAccuracy = FocusMetricsCalculator.averageAccuracy(sessions: filteredSessions)
        let subjects = FocusMetricsCalculator.subjectBreakdown(sessions: filteredSessions)

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mastery")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                HStack {
                    Text("Average Accuracy")
                        .font(KzuTypography.journeyCaption)
                        .foregroundStyle(Color.kzuSoftNavy)
                    Spacer()
                    Text(String(format: "%.0f%%", avgAccuracy * 100))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)
                }

                if !subjects.isEmpty {
                    Divider()

                    ForEach(Array(subjects.keys.sorted()), id: \.self) { subject in
                        HStack {
                            Image(systemName: subject == "literacy" ? "book" : "function")
                                .foregroundStyle(Color.kzuFlowBlue)
                            Text(subject.capitalized)
                                .font(KzuTypography.journeyCaption)
                                .foregroundStyle(Color.kzuDeepNavy)
                            Spacer()
                            Text("\(subjects[subject] ?? 0) sessions")
                                .font(KzuTypography.journeyCaption)
                                .foregroundStyle(Color.kzuSoftNavy)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("App Limits")
                    .font(KzuTypography.dashboardHeadline)
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("Select the games and social media apps that should be locked while your child is focusing.")
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)

                NeoSkeuomorphicButton("Choose Apps to Lock", icon: "app.badge.checkmark", isPrimary: false) {
                    authManager.showAppPicker()
                }
            }
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                    Spacer()
                }

                Text(value)
                    .font(KzuTypography.dashboardMetric)
                    .foregroundStyle(Color.kzuDeepNavy)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
