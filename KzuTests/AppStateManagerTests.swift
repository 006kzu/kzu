// AppStateManagerTests.swift
// KzuTests — State machine & timer verification

import XCTest
@testable import Kzu

final class AppStateManagerTests: XCTestCase {

    var sut: AppStateManager!

    override func setUp() {
        super.setUp()
        sut = AppStateManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.currentPhase, .idle)
    }

    func testInitialTimeIs25Minutes() {
        XCTAssertEqual(sut.timeRemaining, 25 * 60)
    }

    // MARK: - Phase Transitions

    func testTransitionToLearningBlock() {
        sut.transitionTo(.learningBlock)
        XCTAssertEqual(sut.currentPhase, .learningBlock)
        XCTAssertEqual(sut.timeRemaining, 25 * 60)
    }

    func testTransitionToGameHub() {
        sut.transitionTo(.gameHub)
        XCTAssertEqual(sut.currentPhase, .gameHub)
        XCTAssertEqual(sut.timeRemaining, 5 * 60)
    }

    func testBeginFlowFromIdle() {
        sut.beginFlow()
        XCTAssertEqual(sut.currentPhase, .learningBlock)
    }

    func testBeginFlowIgnoredDuringLearningBlock() {
        sut.transitionTo(.learningBlock)
        sut.beginFlow()
        // Should remain in learningBlock, not restart
        XCTAssertEqual(sut.currentPhase, .learningBlock)
    }

    // MARK: - Reset Penalty

    func testResetPenaltyResetsTimer() {
        sut.transitionTo(.learningBlock)

        // Simulate some time passing
        sut.applyResetPenalty()

        XCTAssertEqual(sut.timeRemaining, 25 * 60, "Timer should reset to 25:00")
        XCTAssertEqual(sut.totalResets, 1)
    }

    func testResetPenaltyIncrements() {
        sut.transitionTo(.learningBlock)
        sut.applyResetPenalty()
        sut.applyResetPenalty()
        sut.applyResetPenalty()

        XCTAssertEqual(sut.totalResets, 3)
    }

    func testResetPenaltyIgnoredInGameHub() {
        sut.transitionTo(.gameHub)
        let initialTime = sut.timeRemaining
        sut.applyResetPenalty()

        XCTAssertEqual(sut.timeRemaining, initialTime, "Reset should not affect Game Hub")
        XCTAssertEqual(sut.totalResets, 0)
    }

    // MARK: - Explorer Mode

    func testExplorerModeTransition() {
        sut.transitionTo(.learningBlock)
        sut.transitionToExplorerMode()

        XCTAssertEqual(sut.currentPhase, .explorerMode)
    }

    func testExplorerModePreservesTimer() {
        sut.transitionTo(.learningBlock)
        let timeBeforeExplorer = sut.timeRemaining
        sut.transitionToExplorerMode()

        XCTAssertEqual(sut.timeRemaining, timeBeforeExplorer,
                       "Explorer mode should not reset the timer")
    }

    func testResetPenaltyWorksInExplorerMode() {
        sut.transitionTo(.learningBlock)
        sut.transitionToExplorerMode()
        sut.applyResetPenalty()

        XCTAssertEqual(sut.timeRemaining, 25 * 60)
        XCTAssertEqual(sut.totalResets, 1)
    }

    // MARK: - Formatted Output

    func testFormattedTimeRemaining() {
        sut.transitionTo(.learningBlock)
        XCTAssertEqual(sut.formattedTimeRemaining, "25:00")
    }

    func testPhaseLabels() {
        XCTAssertEqual(sut.phaseLabel, "Ready to Begin")

        sut.transitionTo(.learningBlock)
        XCTAssertEqual(sut.phaseLabel, "In Your Flow")

        sut.transitionTo(.gameHub)
        XCTAssertEqual(sut.phaseLabel, "Rest & Reflect")
    }

    func testProgressCalculation() {
        sut.transitionTo(.learningBlock)
        XCTAssertEqual(sut.progress, 0.0, accuracy: 0.01)
    }

    // MARK: - Reward Tier

    func testDefaultRewardTierIsStandard() {
        XCTAssertEqual(sut.rewardTier, .standard)
    }

    func testUpdateRewardTier() {
        sut.updateRewardTier(.goldenKey)
        XCTAssertEqual(sut.rewardTier, .goldenKey)
    }

    // MARK: - Background Detection

    func testBackgroundWithinGracePeriodNoReset() {
        sut.transitionTo(.learningBlock)
        sut.appDidEnterBackground()

        // Immediately return (within 10s grace)
        sut.appWillEnterForeground()

        XCTAssertEqual(sut.totalResets, 0, "No reset within grace period")
    }
}
