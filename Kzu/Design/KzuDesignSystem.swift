// KzuDesignSystem.swift
// Kzu — "Think Different" era Neo-Skeuomorphic Design System

import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary palette — warm, aspirational, human
    static let kzuIvory       = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let kzuWarmWhite   = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let kzuDeepNavy    = Color(red: 0.10, green: 0.12, blue: 0.22)
    static let kzuSoftNavy    = Color(red: 0.18, green: 0.22, blue: 0.36)
    static let kzuGold        = Color(red: 0.85, green: 0.68, blue: 0.32)
    static let kzuGoldenShine = Color(red: 0.95, green: 0.82, blue: 0.45)

    // Functional accents
    static let kzuSuccess     = Color(red: 0.36, green: 0.72, blue: 0.48)
    static let kzuWarning     = Color(red: 0.92, green: 0.58, blue: 0.30)
    static let kzuError       = Color(red: 0.82, green: 0.28, blue: 0.28)
    static let kzuFlowBlue    = Color(red: 0.29, green: 0.56, blue: 0.85)

    // Surface layers
    static let kzuSurface     = Color(red: 0.94, green: 0.92, blue: 0.87)
    static let kzuCardBg      = Color(red: 0.97, green: 0.95, blue: 0.91)
}

// MARK: - Typography

struct KzuTypography {
    // K-2: SF Rounded — friendly, tactile
    static let foundationalTitle   = Font.system(size: 34, weight: .bold, design: .rounded)
    static let foundationalBody    = Font.system(size: 24, weight: .medium, design: .rounded)
    static let foundationalCaption = Font.system(size: 18, weight: .regular, design: .rounded)

    // 3-8: Serif — scholarly, book-like
    static let journeyTitle        = Font.system(size: 28, weight: .bold, design: .serif)
    static let journeyBody         = Font.system(size: 18, weight: .regular, design: .serif)
    static let journeyCaption      = Font.system(size: 14, weight: .regular, design: .serif)

    // System-wide
    static let timerDisplay        = Font.system(size: 56, weight: .ultraLight, design: .rounded)
    static let timerLabel          = Font.system(size: 14, weight: .medium, design: .rounded)
    static let buttonLabel         = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let dashboardHeadline   = Font.system(size: 22, weight: .bold, design: .rounded)
    static let dashboardMetric     = Font.system(size: 42, weight: .thin, design: .rounded)
}

// MARK: - Neo-Skeuomorphic Button

struct NeoSkeuomorphicButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isPrimary: Bool = true

    init(_ title: String, icon: String? = nil, isPrimary: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
                Text(title)
                    .font(KzuTypography.buttonLabel)
            }
            .foregroundStyle(isPrimary ? Color.kzuIvory : Color.kzuDeepNavy)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Base gradient — subtle, physical
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isPrimary
                                ? LinearGradient(
                                    colors: [Color.kzuDeepNavy, Color.kzuSoftNavy],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [Color.kzuCardBg, Color.kzuSurface],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )

                    // Inner highlight (top edge light reflection)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPrimary ? 0.15 : 0.6),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            // Outer shadow — depth
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.kzuCardBg.opacity(0.85))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Tactile Button (K-2)

struct TactileButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KzuTypography.foundationalBody)
                .foregroundStyle(Color.kzuIvory)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(
                    ZStack {
                        // Bottom shadow layer (gives the "raised" look)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(color.opacity(0.6))
                            .offset(y: isPressed ? 1 : 4)

                        // Top face
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .offset(y: isPressed ? 2 : 0)

                        // Glossy highlight
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .offset(y: isPressed ? 2 : 0)
                    }
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Flow Ring (Timer Visual)

struct FlowRing: View {
    let progress: Double  // 0.0 to 1.0
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.kzuSurface, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.kzuFlowBlue,
                            Color.kzuFlowBlue.opacity(0.7),
                            Color.kzuGold
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Glow at progress tip
            Circle()
                .fill(Color.kzuGold.opacity(0.6))
                .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
                .blur(radius: 4)
                .offset(y: -(UIScreen.main.bounds.width * 0.3))
                .rotationEffect(.degrees(360 * progress - 90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}
