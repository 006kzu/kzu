// GameHubView.swift
// Kzu — "Rest & Reflect" Game Hub collection view

import SwiftUI
import SpriteKit

// MARK: - Game Definition

struct GameDefinition: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let isPremium: Bool
    let sceneBuilder: () -> KzuGameScene

    static let allGames: [GameDefinition] = [
        GameDefinition(
            id: "zen_garden",
            title: "Zen Garden",
            subtitle: "Paint with light and nature",
            icon: "leaf.fill",
            accentColor: Color(red: 0.36, green: 0.72, blue: 0.48),
            isPremium: false,
            sceneBuilder: { ZenGardenScene() }
        ),
        GameDefinition(
            id: "physics_sandbox",
            title: "Physics Play",
            subtitle: "Drop, bounce, and discover",
            icon: "circle.hexagongrid.fill",
            accentColor: Color(red: 0.29, green: 0.56, blue: 0.85),
            isPremium: false,
            sceneBuilder: { PhysicsSandboxScene() }
        ),
        GameDefinition(
            id: "rhythm_flow",
            title: "Rhythm Flow",
            subtitle: "Tap to the pulse of light",
            icon: "waveform.path",
            accentColor: Color(red: 0.55, green: 0.42, blue: 0.58),
            isPremium: true,
            sceneBuilder: { RhythmFlowScene() }
        ),
    ]
}

// MARK: - Game Hub View

struct GameHubView: View {
    @Bindable var appState: AppStateManager
    let rewardTier: RewardTier
    let onExit: () -> Void

    @State private var selectedGame: GameDefinition? = nil
    @State private var isShowingCurtain = true

    var body: some View {
        ZStack {
            // Dark, calming background
            Color.kzuDeepNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back to dashboard
                HStack {
                    Button {
                        onExit()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Dashboard")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color.kzuIvory.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Header with timer
                gameHubHeader

                if selectedGame != nil {
                    // Back to game selection
                    HStack {
                        Button {
                            withAnimation { selectedGame = nil }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Switch Game")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(Color.kzuIvory.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Active game view
                    activeGameView
                        .transition(.opacity)
                } else {
                    // Game selection grid
                    gameSelectionGrid
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: selectedGame?.id)

            // Curtain overlay
            if isShowingCurtain {
                curtainReveal
            }
        }
        .onAppear {
            // Trigger curtain open
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                isShowingCurtain = false
            }
        }
    }

    // MARK: - Header

    private var gameHubHeader: some View {
        VStack(spacing: 8) {
            // Timer bar
            CompactFlowTimer(
                timeRemaining: appState.timeRemaining,
                totalDuration: KzuConstants.gameHubDuration
            )

            HStack(spacing: 8) {
                Image(systemName: rewardTier.icon)
                    .foregroundStyle(rewardTier == .goldenKey ? Color.kzuGold : Color.kzuIvory.opacity(0.5))
                Text(rewardTier.displayName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuIvory.opacity(0.6))
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Game Selection Grid

    private var gameSelectionGrid: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Choose Your Rest")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.kzuIvory)
                    .padding(.top, 20)

                Text("Every game ends peacefully when your break is over.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.kzuIvory.opacity(0.4))
                    .padding(.bottom, 8)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(GameDefinition.allGames) { game in
                        GameCard(
                            game: game,
                            isLocked: game.isPremium && rewardTier != .goldenKey,
                            rewardTier: rewardTier
                        ) {
                            selectedGame = game
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Active Game

    private var activeGameView: some View {
        GeometryReader { geo in
            if let game = selectedGame {
                SpriteView(scene: configuredScene(game, size: geo.size))
                    .ignoresSafeArea()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
    }

    private func configuredScene(_ game: GameDefinition, size: CGSize) -> KzuGameScene {
        let scene = game.sceneBuilder()
        scene.size = size
        scene.scaleMode = .resizeFill
        scene.rewardTier = rewardTier
        scene.timeRemaining = appState.timeRemaining
        scene.onGameComplete = {
            selectedGame = nil
        }
        return scene
    }

    // MARK: - Curtain Reveal

    private var curtainReveal: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.kzuIvory)
                    .frame(width: isShowingCurtain ? geo.size.width / 2 : 0)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(Color.kzuIvory)
                    .frame(width: isShowingCurtain ? geo.size.width / 2 : 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameDefinition
    let isLocked: Bool
    let rewardTier: RewardTier
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLocked { action() }
        }) {
            VStack(spacing: 14) {
                ZStack {
                    // Icon background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    game.accentColor.opacity(isLocked ? 0.1 : 0.3),
                                    game.accentColor.opacity(isLocked ? 0.05 : 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 90)

                    Image(systemName: isLocked ? "lock.fill" : game.icon)
                        .font(.system(size: 32))
                        .foregroundStyle(
                            isLocked
                                ? Color.kzuIvory.opacity(0.2)
                                : game.accentColor
                        )
                }

                VStack(spacing: 4) {
                    Text(game.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isLocked ? Color.kzuIvory.opacity(0.3) : Color.kzuIvory
                        )

                    Text(isLocked ? "Earn a Golden Key" : game.subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.kzuIvory.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isLocked ? Color.clear : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
            .overlay {
                if game.isPremium && !isLocked {
                    RoundedRectangle(cornerRadius: 20)
                        .goldenShimmer()
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isLocked ? 0.97 : 1.0)
        .opacity(isLocked ? 0.6 : 1.0)
    }
}
