import SwiftUI
import SwiftData

struct WeeklyPrizesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklyPrize.weekNumber) private var prizes: [WeeklyPrize]

    let currentDay: Int

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(1...WeeklyPrize.totalWeeks, id: \.self) { week in
                            row(for: week)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Weekly Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: ensurePrizesExist)
        }
    }

    @ViewBuilder
    private func row(for week: Int) -> some View {
        let range = WeeklyPrize.dayRange(for: week)
        let unlocked = currentDay >= range.upperBound
        let prize = prizeBinding(for: week)

        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(unlocked ? Theme.primary.opacity(0.18) : Color.secondary.opacity(0.10))
                Image(systemName: unlocked ? "gift.fill" : "gift")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(unlocked ? Theme.primary : Color.secondary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Week \(week)")
                        .font(.subheadline.weight(.semibold))
                    Text("Days \(range.lowerBound)–\(range.upperBound)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if unlocked {
                        Text("Unlocked")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
                TextField("Prize for this week", text: prize)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardSurface()
    }

    private func prizeBinding(for week: Int) -> Binding<String> {
        Binding(
            get: { prizes.first(where: { $0.weekNumber == week })?.prize ?? "" },
            set: { newValue in
                if let existing = prizes.first(where: { $0.weekNumber == week }) {
                    existing.prize = newValue
                } else {
                    modelContext.insert(WeeklyPrize(weekNumber: week, prize: newValue))
                }
            }
        )
    }

    private func ensurePrizesExist() {
        for week in 1...WeeklyPrize.totalWeeks {
            if !prizes.contains(where: { $0.weekNumber == week }) {
                modelContext.insert(WeeklyPrize(weekNumber: week))
            }
        }
    }
}
