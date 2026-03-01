// ContentDeliveryEngineTests.swift
// KzuTests — Curriculum ingest, scoring, and reward tier verification

import XCTest
@testable import Kzu

final class ContentDeliveryEngineTests: XCTestCase {

    var sut: ContentDeliveryEngine!
    var sampleUnit: CurriculumUnit!

    override func setUp() {
        super.setUp()
        sut = ContentDeliveryEngine()
        sampleUnit = createSampleUnit()
    }

    override func tearDown() {
        sut = nil
        sampleUnit = nil
        super.tearDown()
    }

    // MARK: - JSON Decoding

    func testSampleCurriculumDecoding() {
        guard let url = Bundle.main.url(forResource: "SampleCurriculum", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // Skip if not running in app bundle context
            return
        }

        let unit = try? JSONDecoder().decode(CurriculumUnit.self, from: data)
        XCTAssertNotNil(unit)
        XCTAssertEqual(unit?.unitId, "ckla-k-phonics-01")
        XCTAssertEqual(unit?.lessons.count, 8)
        XCTAssertNotNil(unit?.explorerContent)
    }

    func testModelDecoding() {
        let json = """
        {
            "unitId": "test-unit",
            "standard": "CCSS.MATH.1.NBT.A.1",
            "gradeRange": [1, 2],
            "subject": "math",
            "title": "Test Unit",
            "description": "A test unit",
            "lessons": [
                {
                    "lessonId": "test-lesson-1",
                    "type": "number_sense",
                    "content": {
                        "prompt": "What is 2 + 3?",
                        "options": ["4", "5", "6"],
                        "correctIndex": 1
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let unit = try? JSONDecoder().decode(CurriculumUnit.self, from: json)
        XCTAssertNotNil(unit)
        XCTAssertEqual(unit?.subject, .math)
        XCTAssertEqual(unit?.gradeBand, .foundational)
        XCTAssertEqual(unit?.lessons.count, 1)
    }

    // MARK: - Session Management

    func testStartSession() {
        sut.startSession(unit: sampleUnit)

        XCTAssertNotNil(sut.currentUnit)
        XCTAssertEqual(sut.currentLessonIndex, 0)
        XCTAssertFalse(sut.isInExplorerMode)
        XCTAssertTrue(sut.hasMoreLessons)
    }

    func testCurrentLesson() {
        sut.startSession(unit: sampleUnit)

        let lesson = sut.currentLesson
        XCTAssertNotNil(lesson)
        XCTAssertEqual(lesson?.lessonId, "test-1")
    }

    // MARK: - Answer Submission

    func testCorrectAnswerAdvancesLesson() {
        sut.startSession(unit: sampleUnit)
        let result = sut.submitAnswer(0)  // Correct answer

        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(sut.currentLessonIndex, 1)
    }

    func testIncorrectAnswerDoesNotAdvance() {
        sut.startSession(unit: sampleUnit)
        let result = sut.submitAnswer(2)  // Wrong answer

        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(sut.currentLessonIndex, 0)
    }

    func testLessonProgress() {
        sut.startSession(unit: sampleUnit)
        XCTAssertEqual(sut.lessonProgress, 0.0)

        sut.submitAnswer(0)  // Answer first question correctly
        XCTAssertEqual(sut.lessonProgress, 0.5, accuracy: 0.01)

        sut.submitAnswer(1)  // Answer second question correctly
        XCTAssertEqual(sut.lessonProgress, 1.0, accuracy: 0.01)
    }

    // MARK: - Explorer Mode Transition

    func testShouldTransitionToExplorer() {
        sut.startSession(unit: sampleUnit)
        XCTAssertFalse(sut.shouldTransitionToExplorer)

        // Complete all lessons
        sut.submitAnswer(0)
        sut.submitAnswer(1)

        XCTAssertTrue(sut.shouldTransitionToExplorer)
    }

    func testEnterExplorerMode() {
        sut.startSession(unit: sampleUnit)
        sut.submitAnswer(0)
        sut.submitAnswer(1)
        sut.enterExplorerMode()

        XCTAssertTrue(sut.isInExplorerMode)
        XCTAssertFalse(sut.shouldTransitionToExplorer) // Already in explorer
    }

    // MARK: - Scoring

    func testHighAccuracyGivesGoldenKey() {
        sut.startSession(unit: sampleUnit)
        // Answer both correctly on first attempt
        sut.submitAnswer(0)
        sut.submitAnswer(1)

        XCTAssertEqual(sut.currentRewardTier, .goldenKey)
    }

    func testEngagementTracking() {
        sut.startSession(unit: sampleUnit)
        sut.submitAnswer(0)

        XCTAssertGreaterThan(sut.currentEngagement, 0)
    }

    // MARK: - Grade Band

    func testGradeBandFoundational() {
        XCTAssertEqual(sampleUnit.gradeBand, .foundational)
    }

    func testGradeBandExploration() {
        let upperUnit = CurriculumUnit(
            unitId: "upper-test",
            standard: "CCSS.MATH.5.NF.A.1",
            gradeRange: [3, 5],
            subject: .math,
            title: "Fractions",
            description: "Test",
            lessons: [],
            explorerContent: nil
        )
        XCTAssertEqual(upperUnit.gradeBand, .exploration)
    }

    // MARK: - Helpers

    private func createSampleUnit() -> CurriculumUnit {
        CurriculumUnit(
            unitId: "test-unit-01",
            standard: "CCSS.ELA-LITERACY.RF.K.2",
            gradeRange: [0, 2],
            subject: .literacy,
            title: "Test Phonics",
            description: "Test unit",
            lessons: [
                Lesson(
                    lessonId: "test-1",
                    type: .phonicsDrill,
                    content: LessonContent(
                        prompt: "What sound does A make?",
                        instruction: "Listen carefully",
                        options: ["ah", "buh", "kuh"],
                        correctIndex: 0,
                        expectedAnswer: nil,
                        acceptableVariations: nil,
                        passageTitle: nil,
                        passageText: nil,
                        comprehensionQuestions: nil,
                        mediaAsset: nil,
                        audioAsset: nil,
                        expression: nil,
                        numericAnswer: nil,
                        tolerance: nil
                    )
                ),
                Lesson(
                    lessonId: "test-2",
                    type: .phonicsDrill,
                    content: LessonContent(
                        prompt: "What sound does B make?",
                        instruction: nil,
                        options: ["ah", "buh", "kuh"],
                        correctIndex: 1,
                        expectedAnswer: nil,
                        acceptableVariations: nil,
                        passageTitle: nil,
                        passageText: nil,
                        comprehensionQuestions: nil,
                        mediaAsset: nil,
                        audioAsset: nil,
                        expression: nil,
                        numericAnswer: nil,
                        tolerance: nil
                    )
                )
            ],
            explorerContent: nil
        )
    }
}
