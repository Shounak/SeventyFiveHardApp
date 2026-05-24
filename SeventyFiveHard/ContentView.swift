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
            let waterMet = (await waterReader.ouncesOn(date: entry.date)) >= WaterReader.goalFlOz
            let photoTaken = photoStore.hasPhoto(for: entry.date)
            if !entry.allComplete(waterMetGoal: waterMet, photoTaken: photoTaken) {
                return true
            }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Button { showGallery = true } label: { header }
                            .buttonStyle(.plain)
                        if let entry = todayEntry {
                            checklist(for: entry)
                        }
                        resetButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                ConfettiView(trigger: todayAllComplete)
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
        VStack(spacing: 6) {
            Text("DAY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.maroon.opacity(0.7))
                .tracking(4)
            Text("\(dayNumber)")
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.maroon)
                .contentTransition(.numericText())
            Text("of \(totalDays)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            MosaicProgressBar(
                store: photoStore,
                startDate: challenge?.startDate ?? startOfToday,
                totalDays: totalDays,
                currentDay: dayNumber,
                tint: Theme.maroon
            )
            .padding(.top, 12)
            .padding(.horizontal, 4)

            HStack(spacing: 4) {
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.caption2)
                Text("Tap for progress photo gallery")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .cardSurface()
    }

    @ViewBuilder
    private func checklist(for entry: DayEntry) -> some View {
        VStack(spacing: 12) {
            RuleRow(
                title: "CrossFit class",
                subtitle: "Usually 5:30",
                icon: "figure.strengthtraining.traditional",
                tint: Theme.green,
                isOn: bind(\.crossfit, on: entry)
            )
            RuleRow(
                title: "In bed by 11:45",
                subtitle: "Before Hue lights go out",
                icon: "moon.stars.fill",
                tint: Theme.green,
                isOn: bind(\.inBedBy1145, on: entry)
            )
            ProgressPhotoRow(
                store: photoStore,
                date: startOfToday,
                tint: Theme.green,
                onTap: { showCamera = true }
            )
            RuleRow(
                title: "10 pages reading",
                subtitle: "Prefer reading ADHD books",
                icon: "book.fill",
                tint: Theme.green,
                isOn: bind(\.reading, on: entry)
            )
            WaterRow(reader: waterReader, tint: Theme.green)
            DietRow(entry: entry, tint: Theme.green)
            RuleRow(
                title: "No cheating",
                subtitle: nil,
                icon: "hand.raised.fill",
                tint: Theme.green,
                isOn: bind(\.noCheating, on: entry)
            )
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showResetConfirm = true
        } label: {
            Label("Reset to Day 1", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.medium))
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
        let waterMet = waterReader.metGoal
        let photoTaken = photoStore.hasPhoto(for: startOfToday)
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

private struct MosaicProgressBar: View {
    let store: PhotoStore
    let startDate: Date
    let totalDays: Int
    let currentDay: Int
    let tint: Color

    private let trackHeight: CGFloat = 12

    var body: some View {
        _ = store.revision
        return GeometryReader { geo in
            let width = geo.size.width
            let cell = width / CGFloat(totalDays)
            let progress = CGFloat(min(max(currentDay, 0), totalDays))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))

                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: max(0, cell * progress))

                HStack(spacing: 0) {
                    ForEach(0..<totalDays, id: \.self) { index in
                        thumbnail(forDayIndex: index, size: cell)
                            .frame(width: cell, height: trackHeight)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: trackHeight)
        }
        .frame(height: trackHeight)
    }

    @ViewBuilder
    private func thumbnail(forDayIndex index: Int, size: CGFloat) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? startDate
        if let img = store.thumbnail(for: date, maxPixelSize: max(32, size * 4)) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: trackHeight)
                .clipped()
        } else {
            Color.clear
        }
    }
}

private struct RuleRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: icon, tint: tint, active: isOn)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
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
                    .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.5))
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}

private struct IconBadge: View {
    let systemName: String
    let tint: Color
    let active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(active ? tint.opacity(0.18) : Color.secondary.opacity(0.10))
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(active ? tint : Color.secondary)
        }
        .frame(width: 36, height: 36)
    }
}

private struct DietRow: View {
    @Bindable var entry: DayEntry
    let tint: Color
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    IconBadge(systemName: "fork.knife", tint: tint, active: entry.dietComplete)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Follow diet")
                            .font(.body.weight(.medium))
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
                        .foregroundStyle(entry.dietComplete ? tint : Color.secondary.opacity(0.5))
                        .symbolEffect(.bounce, value: entry.dietComplete)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 8) {
                    SubItemRow(title: "Solid meal 1", icon: "frying.pan.fill", tint: tint, isOn: $entry.meal1)
                    SubItemRow(title: "Fruit 1", icon: "applelogo", tint: tint, isOn: $entry.fruit1)
                    SubItemRow(title: "Protein shake 1", icon: "takeoutbag.and.cup.and.straw.fill", tint: tint, isOn: $entry.shake1)
                    SubItemRow(title: "Solid meal 2", icon: "fork.knife", tint: tint, isOn: $entry.meal2)
                    SubItemRow(title: "Fruit 2", icon: "carrot.fill", tint: tint, isOn: $entry.fruit2)
                    SubItemRow(title: "Protein shake 2", icon: "cup.and.saucer.fill", tint: tint, isOn: $entry.shake2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardSurface()
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
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(isOn ? tint : Color.secondary)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.5))
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.background.opacity(0.6))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WaterRow: View {
    let reader: WaterReader
    let tint: Color

    private var goal: Double { WaterReader.goalFlOz }
    private var ounces: Double { reader.ounces }
    private var fraction: Double { min(ounces / goal, 1.0) }
    private var met: Bool { reader.metGoal }

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemName: "drop.fill", tint: tint, active: met)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("1 gallon water")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(ounces.rounded())) / \(Int(goal)) fl oz")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(met ? tint : .secondary)
                }
                ProgressView(value: fraction)
                    .tint(tint)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(met ? tint : Color.secondary.opacity(0.5))
                .symbolEffect(.bounce, value: met)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardSurface()
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
    let tint: Color
    let onTap: () -> Void

    private var hasPhoto: Bool { _ = store.revision; return store.hasPhoto(for: date) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                IconBadge(systemName: "camera.fill", tint: tint, active: hasPhoto)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take a Progress Photo")
                        .font(.body.weight(.medium))
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
                    .foregroundStyle(hasPhoto ? tint : Color.secondary.opacity(0.5))
                    .symbolEffect(.bounce, value: hasPhoto)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, ChallengeState.self], inMemory: true)
}
