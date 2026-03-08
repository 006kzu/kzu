// FlowFreezeOverlay.swift
// Kzu — FocusFlow State 3: Bilateral Resume Action
//
// Two frosted-glass circles rest at the left and right edges.
// The student slides both thumbs inward simultaneously; when they
// merge at the center a success haptic fires and the session resumes.
// Lifting either thumb before merge snaps both circles back to the edges.

import SwiftUI
import UIKit

// MARK: - Flow Freeze Overlay

struct FlowFreezeOverlay: View {
    let onRecover: () -> Void

    // Normalised x-positions [0…1] of each circle (nil = not touched)
    @State private var leftX:  CGFloat? = nil   // left thumb
    @State private var rightX: CGFloat? = nil   // right thumb
    @State private var merged  = false
    @State private var particlePulse = false
    @State private var lastHapticIntensity: CGFloat = 0

    // Starting anchors
    private let leftAnchor:  CGFloat = 0.10
    private let rightAnchor: CGFloat = 0.90
    private let mergeThreshold: CGFloat = 0.08   // normalised overlap distance

    private let haptic   = UIImpactFeedbackGenerator(style: .medium)
    private let successH = UINotificationFeedbackGenerator()

    // Current x as fraction of screen width
    private var leftFraction:  CGFloat { leftX  ?? leftAnchor  }
    private var rightFraction: CGFloat { rightX ?? rightAnchor }

    // Distance between circles (normalised 0…1)
    private var normDistance: CGFloat {
        max(0, rightFraction - leftFraction)
    }

    // Haptic intensity 0…1  (closer → stronger)
    private var hapticIntensity: CGFloat {
        let initialDist = rightAnchor - leftAnchor   // ≈ 0.80
        return max(0, min(1, 1.0 - normDistance / initialDist))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Frosted glass backdrop ─────────────────────────────────
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                // Soft background glow
                Circle()
                    .fill(Color.kzuFlowBlue.opacity(0.07))
                    .frame(width: 500, height: 500)
                    .blur(radius: 80)
                    .scaleEffect(particlePulse ? 1.12 : 0.92)
                    .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true),
                               value: particlePulse)

                // ── Instructional text ─────────────────────────────────────
                VStack(spacing: 10) {
                    Text("Slide both thumbs to the center")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    Text("to resume your flow")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .offset(y: -geo.size.height * 0.18)

                // ── Multi-touch canvas ─────────────────────────────────────
                MultiTouchCanvas(
                    leftAnchor:  leftAnchor,
                    rightAnchor: rightAnchor,
                    onUpdate: { lx, rx in
                        leftX  = lx
                        rightX = rx
                        checkMerge(geo: geo)
                        fireHaptic()
                    },
                    onLift: {
                        // Snap back with elastic animation
                        withAnimation(.spring(duration: 0.45, bounce: 0.55)) {
                            leftX  = nil
                            rightX = nil
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                // ── Left circle ────────────────────────────────────────────
                GlowCircle(
                    fraction: leftFraction,
                    color: Color.kzuFlowBlue,
                    yFraction: 0.5,
                    size: 72,
                    geo: geo
                )
                .allowsHitTesting(false)   // let touches pass through to MultiTouchCanvas
                .animation(leftX == nil
                           ? .spring(duration: 0.45, bounce: 0.55)
                           : .interactiveSpring(duration: 0.12),
                           value: leftFraction)

                // ── Right circle ───────────────────────────────────────────
                GlowCircle(
                    fraction: rightFraction,
                    color: Color.kzuGold,
                    yFraction: 0.5,
                    size: 72,
                    geo: geo
                )
                .allowsHitTesting(false)   // let touches pass through to MultiTouchCanvas
                .animation(rightX == nil
                           ? .spring(duration: 0.45, bounce: 0.55)
                           : .interactiveSpring(duration: 0.12),
                           value: rightFraction)

                // ── Merge flash ────────────────────────────────────────────
                if merged {
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 160, height: 160)
                        .blur(radius: 30)
                        .scaleEffect(merged ? 1.6 : 0.4)
                        .transition(.scale.combined(with: .opacity))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
        }
        .onAppear {
            particlePulse = true
            haptic.prepare()
            successH.prepare()
        }
        .transition(
            .asymmetric(
                insertion: .opacity.animation(.easeIn(duration: 0.5)),
                removal:   .opacity.animation(.easeOut(duration: 0.4))
            )
        )
    }

    // MARK: - Merge Detection

    private func checkMerge(geo: GeometryProxy) {
        guard !merged, leftX != nil, rightX != nil else { return }
        if normDistance <= mergeThreshold {
            merged = true
            successH.notificationOccurred(.success)
            // Brief triumph pause before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onRecover()
            }
        }
    }

    // MARK: - Haptic Feedback

    private func fireHaptic() {
        guard leftX != nil, rightX != nil else { return }
        if abs(hapticIntensity - lastHapticIntensity) > 0.04 {
            haptic.impactOccurred(intensity: hapticIntensity)
            lastHapticIntensity = hapticIntensity
        }
    }
}

// MARK: - Glow Circle

private struct GlowCircle: View {
    let fraction:  CGFloat     // normalised x [0…1]
    let color:     Color
    let yFraction: CGFloat
    let size:      CGFloat
    let geo:       GeometryProxy

    private var x: CGFloat { fraction * geo.size.width }
    private var y: CGFloat { yFraction * geo.size.height }

    var body: some View {
        ZStack {
            // Outer diffuse glow
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: size * 2.0, height: size * 2.0)
                .blur(radius: 28)

            // Mid glow halo
            Circle()
                .fill(color.opacity(0.45))
                .frame(width: size * 1.35, height: size * 1.35)
                .blur(radius: 12)

            // Main disc — radial inner glow, no border
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.95),
                            color.opacity(0.72),
                            color.opacity(0.45)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 1.6
                    )
                )
                .frame(width: size, height: size)

            // Inner specular highlight (top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
        }
        .position(x: x, y: y)
    }
}

// MARK: - Multi-Touch Canvas (UIViewRepresentable)
//
// Tracks up to two simultaneous touches. Identifies left vs. right touch
// by their x-position at first contact, then tracks them independently
// through movement. Reports normalised x-fractions [0…1].

private struct MultiTouchCanvas: UIViewRepresentable {
    let leftAnchor:  CGFloat
    let rightAnchor: CGFloat
    let onUpdate: (_ leftX: CGFloat?, _ rightX: CGFloat?) -> Void
    let onLift:   () -> Void

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        v.onUpdate = onUpdate
        v.onLift   = onLift
        return v
    }

    func updateUIView(_ uiView: TouchView, context: Context) {
        uiView.onUpdate = onUpdate
        uiView.onLift   = onLift
    }

    // MARK: TouchView

    final class TouchView: UIView {
        var onUpdate: ((_ leftX: CGFloat?, _ rightX: CGFloat?) -> Void)?
        var onLift:   (() -> Void)?

        // We track touches by identity (UITouch object)
        private var leftTouch:  UITouch?
        private var rightTouch: UITouch?

        // The touch on the left half of screen is "left", right half is "right"
        private func assign(_ touches: Set<UITouch>) {
            for touch in touches {
                let nx = touch.location(in: self).x / bounds.width
                if nx < 0.5 {
                    if leftTouch == nil  { leftTouch  = touch }
                } else {
                    if rightTouch == nil { rightTouch = touch }
                }
            }
        }

        private func report() {
            let lx = leftTouch.map  { $0.location(in: self).x / bounds.width }
            let rx = rightTouch.map { $0.location(in: self).x / bounds.width }
            DispatchQueue.main.async { self.onUpdate?(lx, rx) }
        }

        private func liftAll() {
            leftTouch  = nil
            rightTouch = nil
            DispatchQueue.main.async { self.onLift?() }
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            assign(touches)
            report()
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            // Follow whichever tracked touch moved
            if let t = touches.first(where: { $0 === leftTouch })  { _ = t }
            if let t = touches.first(where: { $0 === rightTouch }) { _ = t }
            report()
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            let ended = Set(touches.compactMap { $0 as UITouch })
            if ended.contains(where: { $0 === leftTouch  }) { leftTouch  = nil }
            if ended.contains(where: { $0 === rightTouch }) { rightTouch = nil }
            // If either thumb lifted, snap everything back
            if leftTouch == nil || rightTouch == nil { liftAll() }
            else { report() }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            liftAll()
        }
    }
}
