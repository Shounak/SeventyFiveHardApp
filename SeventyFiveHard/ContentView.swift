import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]
    @Query private var states: [ChallengeState]

    @State private var showResetConfirm = false
    @State private var pendingMissedReset = false

    private let totalDays = 75

    private var challenge: ChallengeState? { states.first }

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var dayNumber: Int {
        guard let start = challenge?.startDate else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: startOfToday).day ?? 0
        return days + 1
    }

    private var todayEntry: DayEntry? {
        entries.first { Calendar.current.isDate($0.date, inSameDayAs: startOfToday) }
    }

    private var missedYesterday: DayEntry? {
        guard let start = challenge?.startDate, start < startOfToday else { return nil }
        return entries.first { entry in
            !Calendar.current.isDate(entry.date, inSameDayAs: startOfToday) &&
            entry.date >= start &&
            entry.date < startOfToday &&
            !entry.allComplete
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        if let entry = todayEntry {
                            checklist(for: entry)
                        }
                        resetButton
                    }
                    .padding()
                }
            }
            .navigationTitle("75 Hard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: bootstrap)
            .alert("Missed a day", isPresented: $pendingMissedReset) {
                Button("Reset to Day 1", role: .destructive) { resetChallenge() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("75 Hard rules: missing any task on a day means starting over. Reset now?")
            }
            .confirmationDialog(
                "Reset to Day 1?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { resetChallenge() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This wipes all 75 Hard progress and restarts from today.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("DAY")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(4)
            Text("\(dayNumber)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .contentTransition(.numericText())
            Text("of \(totalDays)")
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(min(dayNumber, totalDays)), total: Double(totalDays))
                .tint(Color.accentColor)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func checklist(for entry: DayEntry) -> some View {
        VStack(spacing: 12) {
            RuleRow(
                title: "CrossFit class",
                subtitle: "Usually 5:30",
                icon: "figure.strengthtraining.traditional",
                isOn: bind(\.crossfit, on: entry)
            )
            RuleRow(
                title: "In bed by 11:45",
                subtitle: "Before hue lights go out",
                icon: "moon.stars.fill",
                isOn: bind(\.inBedBy1145, on: entry)
            )
            RuleRow(
                title: "Progress photo",
                subtitle: "Before post-workout shower",
                icon: "camera.fill",
                isOn: bind(\.progressPhoto, on: entry)
            )
            RuleRow(
                title: "10 pages reading",
                subtitle: "Prefer reading ADHD books",
                icon: "book.fill",
                isOn: bind(\.reading, on: entry)
            )
            RuleRow(
                title: "1 gallon water",
                subtitle: "Track in WaterLlama app. 1 gallon = 16 cups = 128 fl oz",
                icon: "drop.fill",
                isOn: bind(\.water, on: entry)
            )
            DietRow(entry: entry)
            RuleRow(
                title: "No cheating",
                subtitle: nil,
                icon: "hand.raised.fill",
                isOn: bind(\.noCheating, on: entry)
            )
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetConfirm = true
        } label: {
            Label("Reset to Day 1", systemImage: "arrow.counterclockwise")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .padding(.top, 8)
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<DayEntry, Bool>, on entry: DayEntry) -> Binding<Bool> {
        Binding(
            get: { entry[keyPath: keyPath] },
            set: { entry[keyPath: keyPath] = $0 }
        )
    }

    private func bootstrap() {
        if challenge == nil {
            modelContext.insert(ChallengeState(startDate: startOfToday))
        }
        if todayEntry == nil {
            modelContext.insert(DayEntry(date: startOfToday))
        }
        if missedYesterday != nil {
            pendingMissedReset = true
        }
    }

    private func resetChallenge() {
        for entry in entries {
            modelContext.delete(entry)
        }
        if let state = challenge {
            state.startDate = startOfToday
        } else {
            modelContext.insert(ChallengeState(startDate: startOfToday))
        }
        modelContext.insert(DayEntry(date: startOfToday))
    }
}

private struct RuleRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DietRow: View {
    @Bindable var entry: DayEntry
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .frame(width: 32)
                        .foregroundStyle(entry.dietComplete ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Follow diet")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(dietSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                    Image(systemName: entry.dietComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(entry.dietComplete ? Color.accentColor : .secondary)
                        .symbolEffect(.bounce, value: entry.dietComplete)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 8) {
                    SubItemRow(title: "Solid meal 1", isOn: $entry.meal1)
                    SubItemRow(title: "Solid meal 2", isOn: $entry.meal2)
                    SubItemRow(title: "Fruit 1", isOn: $entry.fruit1)
                    SubItemRow(title: "Fruit 2", isOn: $entry.fruit2)
                    SubItemRow(title: "Protein shake 1", isOn: $entry.shake1)
                    SubItemRow(title: "Protein shake 2", isOn: $entry.shake2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dietSummary: String {
        let count = [entry.meal1, entry.meal2, entry.fruit1, entry.fruit2, entry.shake1, entry.shake2]
            .filter { $0 }
            .count
        return "\(count) of 6 complete"
    }
}

private struct SubItemRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, ChallengeState.self], inMemory: true)
}
