// Transitions.swift
// Kzu — Intentional, aspirational transition animations

import SwiftUI

// MARK: - Curtain Open Transition

/// The "curtain opening" effect: content splits from center and reveals what's beneath.
/// Used for the LEARNING_BLOCK → GAME_HUB transition to make it feel like a deliberate reward.
struct CurtainOpenModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: isActive ? 0 : geo.size.width / 2)
                        Spacer(minLength: 0)
                        Rectangle()
                            .frame(width: isActive ? 0 : geo.size.width / 2)
                    }
                    .animation(.easeInOut(duration: 0.9), value: isActive)
                }
            )
    }
}

// MARK: - Phase Transition Container

/// Wraps a view with the appropriate transition based on the phase change direction.
struct PhaseTransition: ViewModifier {
    let phase: AppPhase

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95))
                        .animation(.easeOut(duration: 0.6)),
                    removal: .opacity.combined(with: .scale(scale: 1.03))
                        .animation(.easeIn(duration: 0.4))
                )
            )
    }
}

// MARK: - Shimmer Effect (Golden Key)

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.kzuGoldenShine.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: -geo.size.width * 0.2 + phase * geo.size.width * 1.4)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 2.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 1
                        }
                    }
                }
            )
            .clipped()
    }
}

// MARK: - Gentle Pulse

struct GentlePulse: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.03 : 1.0)
            .opacity(isPulsing ? 0.85 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// "Curtain opening" reveal — used when transitioning to Game Hub
    func curtainOpen(isRevealed: Bool) -> some View {
        modifier(CurtainOpenModifier(isActive: !isRevealed))
    }

    /// Phase-appropriate transition
    func phaseTransition(_ phase: AppPhase) -> some View {
        modifier(PhaseTransition(phase: phase))
    }

    /// Golden shimmer for premium reward items
    func goldenShimmer() -> some View {
        modifier(ShimmerEffect())
    }

    /// Gentle breathing pulse for active timer elements
    func gentlePulse() -> some View {
        modifier(GentlePulse())
    }
}
