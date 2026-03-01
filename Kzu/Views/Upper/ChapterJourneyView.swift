// ChapterJourneyView.swift
// Kzu — 3rd–8th grade "Deep Exploration" views

import SwiftUI

// MARK: - Chapter Journey View

/// Rich-text reading + conceptual problem-solving for grades 3-8.
/// Clean, book-like typography with serif fonts and generous margins.
struct ChapterJourneyView: View {
    let lesson: Lesson
    let onAnswer: (Int) -> Bool
    let onFreeResponse: (String) -> Bool
    let onNumericAnswer: (Double) -> Bool

    @State private var selectedIndex: Int? = nil
    @State private var isCorrect: Bool? = nil
    @State private var showFeedback = false
    @State private var freeResponseText = ""
    @State private var numericText = ""

    var body: some View {
        VStack(spacing: 24) {
            // Lesson type badge
            lessonTypeBadge

            // Content based on lesson type
            switch lesson.type {
            case .readingPassage:
                readingPassageView
            case .vocabularyBuilder:
                vocabularyView
            case .mathProblem:
                mathProblemView
            case .conceptualQuestion:
                conceptualQuestionView
            default:
                multipleChoiceView
            }

            // Feedback
            if showFeedback, let correct = isCorrect {
                journeyFeedback(correct: correct)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showFeedback)
    }

    // MARK: - Lesson Type Badge

    private var lessonTypeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: lessonTypeIcon)
                .font(.system(size: 12))
            Text(lessonTypeLabel)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .tracking(1.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(Color.kzuSoftNavy)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.kzuSurface)
        )
    }

    // MARK: - Reading Passage

    private var readingPassageView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let title = lesson.content.passageTitle {
                Text(title)
                    .font(KzuTypography.journeyTitle)
                    .foregroundStyle(Color.kzuDeepNavy)
            }

            if let passage = lesson.content.passageText {
                GlassCard {
                    Text(passage)
                        .font(KzuTypography.journeyBody)
                        .foregroundStyle(Color.kzuDeepNavy)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Comprehension questions
            if let questions = lesson.content.comprehensionQuestions {
                ForEach(questions) { question in
                    comprehensionQuestionView(question)
                }
            }
        }
    }

    private func comprehensionQuestionView(_ question: ComprehensionQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.question)
                .font(KzuTypography.journeyBody)
                .foregroundStyle(Color.kzuDeepNavy)
                .fontWeight(.medium)

            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                JourneyOptionButton(
                    text: option,
                    letter: String(Character(UnicodeScalar(65 + index)!)),
                    isSelected: selectedIndex == index,
                    isCorrect: selectedIndex == index ? isCorrect : nil
                ) {
                    handleMultipleChoice(index)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Vocabulary Builder

    private var vocabularyView: some View {
        VStack(spacing: 20) {
            if let instruction = lesson.content.instruction {
                Text(instruction)
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .italic()
            }

            Text(lesson.content.prompt)
                .font(KzuTypography.journeyTitle)
                .foregroundStyle(Color.kzuDeepNavy)
                .multilineTextAlignment(.center)

            if let options = lesson.content.options {
                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        JourneyOptionButton(
                            text: option,
                            letter: String(Character(UnicodeScalar(65 + index)!)),
                            isSelected: selectedIndex == index,
                            isCorrect: selectedIndex == index ? isCorrect : nil
                        ) {
                            handleMultipleChoice(index)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Math Problem

    private var mathProblemView: some View {
        VStack(spacing: 24) {
            if let instruction = lesson.content.instruction {
                Text(instruction)
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
            }

            GlassCard {
                VStack(spacing: 16) {
                    if let expression = lesson.content.expression {
                        Text(expression)
                            .font(.system(size: 36, weight: .light, design: .serif))
                            .foregroundStyle(Color.kzuDeepNavy)
                    } else {
                        Text(lesson.content.prompt)
                            .font(KzuTypography.journeyBody)
                            .foregroundStyle(Color.kzuDeepNavy)
                    }
                }
            }

            // Numeric input or multiple choice
            if lesson.content.numericAnswer != nil {
                numericInputView
            } else if let options = lesson.content.options {
                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        JourneyOptionButton(
                            text: option,
                            letter: String(Character(UnicodeScalar(65 + index)!)),
                            isSelected: selectedIndex == index,
                            isCorrect: selectedIndex == index ? isCorrect : nil
                        ) {
                            handleMultipleChoice(index)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Conceptual Question

    private var conceptualQuestionView: some View {
        VStack(spacing: 20) {
            Text(lesson.content.prompt)
                .font(KzuTypography.journeyBody)
                .foregroundStyle(Color.kzuDeepNavy)
                .multilineTextAlignment(.center)

            if lesson.content.options != nil {
                multipleChoiceView
            } else {
                freeResponseView
            }
        }
    }

    // MARK: - Multiple Choice (Generic)

    private var multipleChoiceView: some View {
        VStack(spacing: 20) {
            if let instruction = lesson.content.instruction {
                Text(instruction)
                    .font(KzuTypography.journeyCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
            }

            Text(lesson.content.prompt)
                .font(KzuTypography.journeyBody)
                .foregroundStyle(Color.kzuDeepNavy)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            if let options = lesson.content.options {
                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        JourneyOptionButton(
                            text: option,
                            letter: String(Character(UnicodeScalar(65 + index)!)),
                            isSelected: selectedIndex == index,
                            isCorrect: selectedIndex == index ? isCorrect : nil
                        ) {
                            handleMultipleChoice(index)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Numeric Input

    private var numericInputView: some View {
        HStack(spacing: 12) {
            TextField("Your answer", text: $numericText)
                .font(KzuTypography.journeyBody)
                .keyboardType(.decimalPad)
                .padding()
                .background(Color.kzuWarmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.kzuSurface, lineWidth: 1)
                )

            NeoSkeuomorphicButton("Check", icon: "checkmark") {
                if let value = Double(numericText) {
                    handleNumericAnswer(value)
                }
            }
        }
    }

    // MARK: - Free Response

    private var freeResponseView: some View {
        VStack(spacing: 12) {
            TextEditor(text: $freeResponseText)
                .font(KzuTypography.journeyBody)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.kzuWarmWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.kzuSurface, lineWidth: 1)
                )

            NeoSkeuomorphicButton("Submit", icon: "arrow.up.circle") {
                handleFreeResponse()
            }
        }
    }

    // MARK: - Answer Handlers

    private func handleMultipleChoice(_ index: Int) {
        selectedIndex = index
        let correct = onAnswer(index)
        isCorrect = correct
        showFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + (correct ? 1.0 : 1.5)) {
            showFeedback = false
            selectedIndex = nil
            isCorrect = nil
        }
    }

    private func handleNumericAnswer(_ value: Double) {
        let correct = onNumericAnswer(value)
        isCorrect = correct
        showFeedback = true

        if correct {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showFeedback = false
                isCorrect = nil
                numericText = ""
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showFeedback = false
                isCorrect = nil
            }
        }
    }

    private func handleFreeResponse() {
        let correct = onFreeResponse(freeResponseText)
        isCorrect = correct
        showFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showFeedback = false
            isCorrect = nil
            if correct { freeResponseText = "" }
        }
    }

    // MARK: - Feedback

    private func journeyFeedback(correct: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(correct ? Color.kzuSuccess : Color.kzuError)
            Text(correct ? "Excellent thinking." : "Not quite — consider it again.")
                .font(KzuTypography.journeyCaption)
                .foregroundStyle(Color.kzuDeepNavy)
        }
        .padding()
        .background(
            Capsule()
                .fill(correct ? Color.kzuSuccess.opacity(0.1) : Color.kzuError.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private var lessonTypeIcon: String {
        switch lesson.type {
        case .readingPassage:     return "book"
        case .vocabularyBuilder:  return "textformat.abc"
        case .mathProblem:        return "function"
        case .conceptualQuestion: return "lightbulb"
        default:                  return "questionmark.circle"
        }
    }

    private var lessonTypeLabel: String {
        switch lesson.type {
        case .readingPassage:     return "Reading"
        case .vocabularyBuilder:  return "Vocabulary"
        case .mathProblem:        return "Mathematics"
        case .conceptualQuestion: return "Deep Thinking"
        default:                  return "Lesson"
        }
    }
}

// MARK: - Journey Option Button

struct JourneyOptionButton: View {
    let text: String
    let letter: String
    let isSelected: Bool
    let isCorrect: Bool?
    let action: () -> Void

    private var borderColor: Color {
        if let correct = isCorrect {
            return correct ? Color.kzuSuccess : Color.kzuError
        }
        return isSelected ? Color.kzuFlowBlue : Color.kzuSurface
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Letter indicator
                Text(letter)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(isSelected ? Color.kzuIvory : Color.kzuSoftNavy)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.kzuFlowBlue : Color.kzuSurface)
                    )

                // Option text
                Text(text)
                    .font(KzuTypography.journeyBody)
                    .foregroundStyle(Color.kzuDeepNavy)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Correctness indicator
                if let correct = isCorrect {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? Color.kzuSuccess : Color.kzuError)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.kzuCardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
