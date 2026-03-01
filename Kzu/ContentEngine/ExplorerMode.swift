// ExplorerMode.swift
// Kzu — Enrichment content for early finishers

import SwiftUI

// MARK: - Explorer Mode View

/// Renders enrichment content when the student completes their assigned
/// curriculum before the 25-minute timer expires. No scoring — pure engagement.
struct ExplorerModeView: View {
    let content: ExplorerContent?
    @State private var drawingPaths: [[CGPoint]] = []
    @State private var currentPath: [CGPoint] = []
    @State private var patternAnswer: String = ""
    @State private var storyText: String = ""

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.kzuGold)
                Text("Explorer Mode")
                    .font(KzuTypography.foundationalTitle)
                    .foregroundStyle(Color.kzuDeepNavy)
            }
            .gentlePulse()

            Text("You've completed your journey. Explore freely until rest time.")
                .font(KzuTypography.journeyCaption)
                .foregroundStyle(Color.kzuSoftNavy)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let content {
                GlassCard {
                    explorerContent(for: content)
                }
            } else {
                defaultExplorerView
            }
        }
        .padding()
    }

    // MARK: - Content Router

    @ViewBuilder
    private func explorerContent(for content: ExplorerContent) -> some View {
        VStack(spacing: 16) {
            Text(content.title)
                .font(KzuTypography.journeyTitle)
                .foregroundStyle(Color.kzuDeepNavy)

            Text(content.instruction)
                .font(KzuTypography.journeyBody)
                .foregroundStyle(Color.kzuSoftNavy)
                .multilineTextAlignment(.center)

            switch content.type {
            case .logicPuzzle:
                logicPuzzleView(content.payload)
            case .freeDrawing:
                freeDrawingView(content.payload)
            case .patternGame:
                patternGameView(content.payload)
            case .storyStarter:
                storyStarterView(content.payload)
            case .mathChallenge:
                mathChallengeView(content.payload)
            }
        }
    }

    // MARK: - Logic Puzzle

    private func logicPuzzleView(_ payload: ExplorerPayload) -> some View {
        VStack(spacing: 12) {
            if let puzzleData = payload.puzzleData {
                Text(puzzleData)
                    .font(KzuTypography.journeyBody)
                    .foregroundStyle(Color.kzuDeepNavy)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.kzuSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("Your answer...", text: $patternAnswer)
                .font(KzuTypography.foundationalBody)
                .padding()
                .background(Color.kzuWarmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.kzuSurface, lineWidth: 1)
                )
        }
    }

    // MARK: - Free Drawing Canvas

    private func freeDrawingView(_ payload: ExplorerPayload) -> some View {
        VStack(spacing: 12) {
            if let prompt = payload.canvasPrompt {
                Text(prompt)
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .italic()
            }

            Canvas { context, size in
                for path in drawingPaths {
                    var shapePath = Path()
                    guard let first = path.first else { continue }
                    shapePath.move(to: first)
                    for point in path.dropFirst() {
                        shapePath.addLine(to: point)
                    }
                    context.stroke(shapePath, with: .color(.kzuDeepNavy), lineWidth: 3)
                }

                // Current stroke
                var currentShapePath = Path()
                if let first = currentPath.first {
                    currentShapePath.move(to: first)
                    for point in currentPath.dropFirst() {
                        currentShapePath.addLine(to: point)
                    }
                    context.stroke(currentShapePath, with: .color(.kzuFlowBlue), lineWidth: 3)
                }
            }
            .frame(height: 300)
            .background(Color.kzuWarmWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.kzuSurface, lineWidth: 2)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentPath.append(value.location)
                    }
                    .onEnded { _ in
                        drawingPaths.append(currentPath)
                        currentPath = []
                    }
            )

            NeoSkeuomorphicButton("Clear Canvas", icon: "trash", isPrimary: false) {
                drawingPaths = []
                currentPath = []
            }
        }
    }

    // MARK: - Pattern Game

    private func patternGameView(_ payload: ExplorerPayload) -> some View {
        VStack(spacing: 16) {
            if let sequence = payload.sequence {
                HStack(spacing: 12) {
                    ForEach(sequence, id: \.self) { number in
                        Text("\(number)")
                            .font(KzuTypography.foundationalBody)
                            .frame(width: 50, height: 50)
                            .background(Color.kzuFlowBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Text("?")
                        .font(KzuTypography.foundationalBody)
                        .frame(width: 50, height: 50)
                        .background(Color.kzuGold.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .gentlePulse()
                }

                TextField("Next number...", text: $patternAnswer)
                    .font(KzuTypography.foundationalBody)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.kzuWarmWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Story Starter

    private func storyStarterView(_ payload: ExplorerPayload) -> some View {
        VStack(spacing: 12) {
            if let prompt = payload.storyPrompt {
                Text("\" \(prompt) \"")
                    .font(KzuTypography.journeyBody)
                    .foregroundStyle(Color.kzuDeepNavy)
                    .italic()
                    .padding()
            }

            TextEditor(text: $storyText)
                .font(KzuTypography.journeyBody)
                .frame(minHeight: 200)
                .padding(12)
                .background(Color.kzuWarmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.kzuSurface, lineWidth: 1)
                )
        }
    }

    // MARK: - Math Challenge

    private func mathChallengeView(_ payload: ExplorerPayload) -> some View {
        VStack(spacing: 12) {
            if let puzzleData = payload.puzzleData {
                Text(puzzleData)
                    .font(KzuTypography.foundationalTitle)
                    .foregroundStyle(Color.kzuDeepNavy)
            }

            TextField("Your answer...", text: $patternAnswer)
                .font(KzuTypography.foundationalBody)
                .keyboardType(.decimalPad)
                .padding()
                .background(Color.kzuWarmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Default View

    private var defaultExplorerView: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.kzuGold)

                Text("Free Sketch")
                    .font(KzuTypography.journeyTitle)
                    .foregroundStyle(Color.kzuDeepNavy)

                Text("Draw whatever inspires you.")
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)

                Canvas { context, size in
                    for path in drawingPaths {
                        var shapePath = Path()
                        guard let first = path.first else { continue }
                        shapePath.move(to: first)
                        for point in path.dropFirst() {
                            shapePath.addLine(to: point)
                        }
                        context.stroke(shapePath, with: .color(.kzuDeepNavy), lineWidth: 3)
                    }
                }
                .frame(height: 250)
                .background(Color.kzuWarmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in currentPath.append(value.location) }
                        .onEnded { _ in
                            drawingPaths.append(currentPath)
                            currentPath = []
                        }
                )
            }
        }
    }
}
