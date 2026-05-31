import SwiftUI

extension PerformanceDashboardView {
    var qualityRatingSection: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Quality Ratings")
                .font(self.fonts.headline)
                .fontWeight(.semibold)

            let aggregated = self.aggregateStats()

            if aggregated.totalRatings == 0 {
                Text("No quality ratings yet")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(height: 100)
            } else {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack {
                        Text("Average Rating:")
                            .font(self.fonts.subheadline)
                            .foregroundStyle(self.runicTheme.secondaryText)

                        if let avg = aggregated.avgQualityRating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(avg.rounded()) ? "star.fill" : "star")
                                        .font(self.fonts.caption)
                                        .foregroundStyle(.yellow)
                                }
                                Text(String(format: "%.1f", avg))
                                    .font(self.fonts.subheadline)
                                    .fontWeight(.medium)
                            }
                        }

                        Spacer()

                        Text("\(aggregated.totalRatings) ratings")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }

                    self.ratingDistribution(aggregated)
                }
            }
        }
    }

    func ratingDistribution(_ aggregated: AggregatedStats) -> some View {
        VStack(spacing: RunicSpacing.xxs) {
            ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                let count = self.ratingCount(rating, from: aggregated)
                let percent = aggregated.totalRatings > 0
                    ? Double(count) / Double(aggregated.totalRatings) * 100
                    : 0

                HStack(spacing: RunicSpacing.xs) {
                    Text("\(rating)")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(width: 12)

                    Image(systemName: "star.fill")
                        .font(self.fonts.caption2)
                        .foregroundStyle(.yellow)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(nsColor: .tertiaryLabelColor).opacity(0.2))

                            Capsule()
                                .fill(Color.yellow)
                                .frame(width: geo.size.width * (percent / 100))
                        }
                    }
                    .frame(height: 6)

                    Text("\(count)")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    func ratingCount(_ rating: Int, from aggregated: AggregatedStats) -> Int {
        switch rating {
        case 1: aggregated.rating1Count
        case 2: aggregated.rating2Count
        case 3: aggregated.rating3Count
        case 4: aggregated.rating4Count
        case 5: aggregated.rating5Count
        default: 0
        }
    }
}
