import RunicCore
import SwiftUI

/// Inline quality rating UI for AI model interactions (1-5 stars)
struct QualityRatingView: View {
    // MARK: - Types

    struct Model {
        let requestID: String
        let provider: UsageProvider
        let model: String?
        let sessionID: String?
        let onSubmit: (Int, String?) async -> Void
    }

    // MARK: - State

    private let model: Model
    @State private var selectedRating: Int?
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?
    @FocusState private var isCommentFocused: Bool

    // MARK: - Initialization

    init(model: Model) {
        self.model = model
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            if self.didSubmit {
                self.thankYouView
            } else {
                self.ratingSelector
                if self.selectedRating != nil {
                    self.commentField
                    self.submitButton
                }
                if let error = self.errorMessage {
                    self.errorView(error)
                }
            }
        }
        .runicTypography()
        .padding(RunicSpacing.sm)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Rating Selector

    private var ratingSelector: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            Text("How would you rate this response?")
                .font(RunicFont.subheadline)
                .fontWeight(.medium)

            HStack(spacing: RunicSpacing.xs) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        self.selectRating(rating)
                    } label: {
                        Image(systemName: self.starIcon(for: rating))
                            .font(RunicFont.title2)
                            .foregroundStyle(self.starColor(for: rating))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(rating) star\(rating == 1 ? "" : "s")")
                    .accessibilityAddTraits(self.selectedRating == rating ? [.isSelected] : [])
                }
            }
        }
    }

    private func starIcon(for rating: Int) -> String {
        if let selected = self.selectedRating {
            return rating <= selected ? "star.fill" : "star"
        }
        return "star"
    }

    private func starColor(for rating: Int) -> Color {
        guard let selected = self.selectedRating else {
            return Color(nsColor: .secondaryLabelColor)
        }

        if rating <= selected {
            // Color gradient from red (1 star) to yellow (5 stars)
            switch selected {
            case 1, 2: return .red
            case 3: return .orange
            case 4, 5: return .yellow
            default: return .yellow
            }
        }

        return Color(nsColor: .tertiaryLabelColor)
    }

    private func selectRating(_ rating: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.selectedRating = rating
        }
    }

    // MARK: - Comment Field

    private var commentField: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            Text("Additional feedback (optional)")
                .font(RunicFont.caption)
                .foregroundStyle(.secondary)

            TextField("Share your thoughts...", text: self.$comment, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(RunicSpacing.xs)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .focused(self.$isCommentFocused)
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        HStack {
            Spacer()

            Button {
                Task {
                    await self.submitRating()
                }
            } label: {
                HStack(spacing: 4) {
                    if self.isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 12, height: 12)
                    }
                    Text(self.isSubmitting ? "Submitting..." : "Submit Rating")
                        .font(RunicFont.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, RunicSpacing.sm)
                .padding(.vertical, RunicSpacing.xxs)
            }
            .buttonStyle(.borderedProminent)
            .disabled(self.isSubmitting)
        }
    }

    // MARK: - Thank You View

    private var thankYouView: some View {
        HStack(spacing: RunicSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(RunicFont.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Thank you for your feedback!")
                    .font(RunicFont.subheadline)
                    .fontWeight(.medium)

                if let rating = self.selectedRating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(RunicFont.caption2)
                                .foregroundStyle(star <= rating ? .yellow : Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, RunicSpacing.xxs)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: RunicSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(RunicFont.caption)
                .foregroundStyle(.red)

            Text(message)
                .font(RunicFont.caption)
                .foregroundStyle(.red)
                .lineLimit(2)

            Spacer()

            Button("Retry") {
                Task {
                    await self.submitRating()
                }
            }
            .font(RunicFont.caption)
        }
        .padding(RunicSpacing.xs)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Submit Logic

    private func submitRating() async {
        guard let rating = self.selectedRating else { return }

        self.isSubmitting = true
        self.errorMessage = nil

        do {
            let trimmedComment = self.comment.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalComment = trimmedComment.isEmpty ? nil : trimmedComment

            await self.model.onSubmit(rating, finalComment)

            withAnimation(.easeInOut(duration: 0.3)) {
                self.didSubmit = true
            }
        } catch {
            self.errorMessage = "Failed to submit rating. Please try again."
        }

        self.isSubmitting = false
    }
}
