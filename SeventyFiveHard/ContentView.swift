import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]
    @Query private var states: [ChallengeState]

    @State private var waterReader = WaterReader()
    @State private var photoStore = PhotoStore()
    @State private var showCamera = false
    @State private var showGallery = false
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

    private func anyMissedPriorDay() async -> Bool {
        guard let start = challenge?.startDate, start < startOfToday else { return false }
        for entry in entries {
            if Calendar.current.isDate(entry.date, inSameDayAs: startOfToday) { continue }
            guard entry.date >= start, entry.date < startOfToday else { continue }
            let waterMet = (await waterReader.ouncesOn(date: entry.date)) >= WaterReader.goalFlOz || entry.water
            let photoTaken = photoStore.hasPhoto(for: entry.date) || entry.progressPhoto
            if !entry.allComplete(waterMetGoal: waterMet, photoTaken: photoTaken) {
                return true
            }
        }
        return false
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
                        Button { showGallery = true } label: { header }
                            .buttonStyle(.plain)
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
            .task {
                await waterReader.requestAuthorizationAndStartObserving()
                await AppIconManager.setIcon(todayAllComplete ? "AppIconDay01" : nil)
            }
            .onChange(of: todayAllComplete) { _, complete in
                Task { await AppIconManager.setIcon(complete ? "AppIconDay01" : nil) }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await waterReader.refresh() }
                }
            }
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    photoStore.save(image, for: startOfToday)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showGallery) {
                GalleryView(
                    startDate: challenge?.startDate ?? startOfToday,
                    totalDays: totalDays,
                    store: photoStore
                )
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
            ProgressPhotoRow(
                store: photoStore,
                date: startOfToday,
                manualOverride: bind(\.progressPhoto, on: entry),
                onTap: { entry.progressPhoto.toggle() } // TEMP: manual toggle for testing; was: showCamera = true
            )
            RuleRow(
                title: "10 pages reading",
                subtitle: "Prefer reading ADHD books",
                icon: "book.fill",
                isOn: bind(\.reading, on: entry)
            )
            WaterRow(reader: waterReader, manualOverride: bind(\.water, on: entry))
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
        Task {
            if await anyMissedPriorDay() {
                pendingMissedReset = true
            }
        }
    }

    private var todayAllComplete: Bool {
        guard let entry = todayEntry else { return false }
        let waterMet = waterReader.metGoal || entry.water
        let photoTaken = photoStore.hasPhoto(for: startOfToday) || entry.progressPhoto
        return entry.allComplete(waterMetGoal: waterMet, photoTaken: photoTaken)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 8) {
                    SubItemRow(title: "Solid meal 1", icon: .symbol("frying.pan.fill"), isOn: $entry.meal1)
                    SubItemRow(title: "Fruit 1", icon: .emoji("🍌"), isOn: $entry.fruit1)
                    SubItemRow(title: "Protein shake 1", icon: .symbol("takeoutbag.and.cup.and.straw.fill"), isOn: $entry.shake1)
                    SubItemRow(title: "Solid meal 2", icon: .symbol("fork.knife"), isOn: $entry.meal2)
                    SubItemRow(title: "Fruit 2", icon: .emoji("🍎"), isOn: $entry.fruit2)
                    SubItemRow(title: "Protein shake 2", icon: .symbol("cup.and.saucer.fill"), isOn: $entry.shake2)
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

enum RowIcon {
    case symbol(String)
    case emoji(String)
}

private struct SubItemRow: View {
    let title: String
    let icon: RowIcon
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                iconView
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.subheadline)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
        case .emoji(let glyph):
            Text(glyph)
                .font(.subheadline)
                .saturation(0)
                .opacity(isOn ? 1.0 : 0.6)
        }
    }
}

private struct WaterRow: View {
    let reader: WaterReader

    private var goal: Double { WaterReader.goalFlOz }
    private var ounces: Double { reader.ounces }
    private var fraction: Double { min(ounces / goal, 1.0) }
    private var met: Bool { reader.metGoal }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "drop.fill")
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(met ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("1 gallon water")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(ounces.rounded())) / \(Int(goal)) fl oz")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(met ? Color.accentColor : .secondary)
                }
                ProgressView(value: fraction)
                    .tint(met ? Color.accentColor : Color.accentColor.opacity(0.6))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(met ? Color.accentColor : .secondary)
                .symbolEffect(.bounce, value: met)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: ounces)
    }

    private var subtitle: String {
        switch reader.authStatus {
        case .unknown: "Connecting to Apple Health…"
        case .denied: "Health access denied — enable in Settings to auto-track"
        case .unavailable: "Apple Health unavailable on this device"
        case .authorized: "From Apple Health (logged via WaterLlama)"
        }
    }
}

private struct ProgressPhotoRow: View {
    let store: PhotoStore
    let date: Date
    let onTap: () -> Void

    private var hasPhoto: Bool { _ = store.revision; return store.hasPhoto(for: date) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(hasPhoto ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take a Progress Photo")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(hasPhoto ? "Tap to retake" : "Before post-workout shower")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let image = store.loadImage(for: date) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Image(systemName: hasPhoto ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(hasPhoto ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: hasPhoto)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, ChallengeState.self], inMemory: true)
}
