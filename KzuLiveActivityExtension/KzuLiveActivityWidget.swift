// KzuLiveActivityWidget.swift
// KzuLiveActivityExtension — Lock Screen & Dynamic Island layouts
//
// Shows a real-time 20-second countdown whenever the student leaves Kzu
// during an active learning or explorer session.

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget Declaration

struct KzuLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KzuLiveActivityAttributes.self) { context in
            // ── Lock Screen / Notification Banner ──────────────────────────
            LockScreenView(state: context.state)

        } dynamicIsland: { context in
            // ── Dynamic Island ─────────────────────────────────────────────
            DynamicIsland {
                // Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.fill")
                        .foregroundStyle(.yellow)
                        .font(.title2)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Circular countdown timer
                    ProgressView(
                        timerInterval: Date.now...context.state.deadline,
                        countsDown: true
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: "timer")
                            .foregroundStyle(.yellow)
                    }
                    .progressViewStyle(.circular)
                    .tint(.yellow)
                    .frame(width: 44, height: 44)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Come back! 📚")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: Date.now...context.state.deadline,
                        countsDown: true,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .tint(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                // Small pill — leading side: book icon
                Image(systemName: "book.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .padding(.leading, 4)

            } compactTrailing: {
                // Small pill — trailing side: circular timer
                ProgressView(
                    timerInterval: Date.now...context.state.deadline,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(.yellow)
                .frame(width: 22, height: 22)

            } minimal: {
                // Tiny dot (when two activities compete)
                ProgressView(
                    timerInterval: Date.now...context.state.deadline,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    Image(systemName: "book.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 8))
                }
                .progressViewStyle(.circular)
                .tint(.yellow)
                .frame(width: 20, height: 20)
            }
            .widgetURL(URL(string: "kzu://resume"))
            .keylineTint(.yellow)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let state: KzuLiveActivityAttributes.ContentState

    /// Fraction of time elapsed (0 = just started, 1 = deadline reached).
    private var elapsedFraction: Double {
        let now = Date.now
        let elapsed = now.distance(to: state.deadline)  // seconds remaining
        let ratio = elapsed / state.totalSeconds         // remaining / total
        // ratio goes 1 → 0 as time elapses; invert for a "draining" bar
        return max(0, min(1, 1 - ratio))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.yellow)
                    .font(.title3)

                Text("Return to Kzu!")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                // Live countdown clock
                Text(state.deadline, style: .timer)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.trailing)
            }

            // Descriptive text
            Text("Your learning session will reset in")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            // Progress bar (drains left → right as deadline approaches)
            ProgressView(
                timerInterval: Date.now...state.deadline,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.linear)
            .tint(.yellow)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())

            Text("20 seconds until session reset")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.09, green: 0.12, blue: 0.28),   // deep navy
                                    Color(red: 0.15, green: 0.10, blue: 0.35)    // deep purple
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.85)
                )
        )
        .activityBackgroundTint(Color(red: 0.09, green: 0.12, blue: 0.28))
        .activitySystemActionForegroundColor(.yellow)
    }
}
