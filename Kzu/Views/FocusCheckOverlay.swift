// FocusCheckOverlay.swift
// Kzu — FocusFlow State 2: The Focus Check (121s–140s)
//
// Centered pulsing ring with live countdown, soft haptics via manager,
// and a tap-anywhere gesture to reset the inactivity timer.

import SwiftUI

// MARK: - Focus Check Overlay

struct FocusCheckOverlay: View {
    let secondsLeft: Int
    let onInteraction: () -> Void   // resets the inactivity timer

    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.7

    var body: some View {
        ZStack {
            // ── Scrim ────────────────────────────────────────────────────
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onInteraction() }

            // ── Pulsing ring + countdown ─────────────────────────────────
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    .scaleEffect(ringScale * 1.25)
                    .opacity(ringOpacity * 0.5)

                // Main pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), Color.kzuFlowBlue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                // Inner content
                VStack(spacing: 8) {
                    Text("\(secondsLeft)")
                        .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.3), value: secondsLeft)

                    Text("Still with us?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .tracking(1.2)

                    Text("Tap anywhere to continue")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 2)
                }
            }
            .frame(width: 200, height: 200)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                ringScale = 1.08
                ringOpacity = 1.0
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
    }
}
