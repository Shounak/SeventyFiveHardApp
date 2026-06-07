import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DayEntry.date) private var entries: [DayEntry]
    @Query private var states: [ChallengeState]
    @Query(sort: \WeeklyPrize.weekNumber) private var prizes: [WeeklyPrize]

    @State private var waterReader = WaterReader()
    @State private var photoStore = PhotoStore()
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showResetConfirm = false
    @State private var pendingMissedReset = false
    @State private var showPrizes = false

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

    private func missedPriorDay() async -> Bool {
        guard
            let start = challenge?.startDate,
            start < startOfToday,
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: startOfToday)
        else {
            return false
        }

        // If the challenge had not started by the previous day, there is no prior day to miss.
        guard previousDay >= Calendar.current.startOfDay(for: start) else {
            return false
        }

        for entry in entries {
            guard Calendar.current.isDate(entry.date, inSameDayAs: previousDay) else {
                continue
            }

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
                        prizesButton
                        resetButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                ConfettiView(trigger: todayAllComplete)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: bootstrap)
            .task {
                await waterReader.requestAuthorizationAndStartObserving()
                await AppIconManager.setIcon(iconNameForToday)
            }
            .onChange(of: dayNumber) { _, _ in
                Task { await AppIconManager.setIcon(iconNameForToday) }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await waterReader.refresh()
                        await AppIconManager.setIcon(iconNameForToday)
                    }
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
            .sheet(isPresented: $showPrizes) {
                WeeklyPrizesView(currentDay: dayNumber)
                    .presentationDetents([.large])
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("DAY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.themeText)
                .tracking(4)
            Text("\(dayNumber)")
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.highlight)
                .contentTransition(.numericText())
                
            Text("of \(totalDays)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.themeText)

            MosaicProgressBar(
                store: photoStore,
                startDate: challenge?.startDate ?? startOfToday,
                totalDays: totalDays,
                currentDay: dayNumber,
                tint: .white,
                trackBackground: Color.white.opacity(0.25)
            )
            .padding(.top, 12)
            .padding(.horizontal, 4)

            MilestoneStrip(
                totalDays: totalDays,
                currentDay: dayNumber
            )
            .padding(.top, 4)
            .padding(.horizontal, 4)

            if let next = nextRewardSummary {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                    Text(next)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.themeText)
                .padding(.top, 8)
            }

            HStack(spacing: 4) {
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.caption2)
                Text("Progress photo gallery  >")
                    .font(.caption2)
            }
            .foregroundStyle(Theme.themeText)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .cardSurface(fill: Theme.primary)
    }

    @ViewBuilder
    private func checklist(for entry: DayEntry) -> some View {
        VStack(spacing: 12) {
            DietRow(entry: entry, tint: Theme.green)
            WaterRow(reader: waterReader, tint: Theme.green)
            RuleRow(
                title: "Workout",
                subtitle: "Usually CrossFit class at 5:30",
                icon: "figure.strengthtraining.traditional",
                tint: Theme.green,
                isOn: bind(\.crossfit, on: entry)
            )
            ProgressPhotoRow(
                store: photoStore,
                date: startOfToday,
                tint: Theme.green,
                onTap: { showCamera = true }
            )
            RuleRow(
                title: "10 pages reading",
                subtitle: "Non-fiction books",
                icon: "book.fill",
                tint: Theme.green,
                isOn: bind(\.reading, on: entry)
            )
            RuleRow(
                title: "In bed by 11:45",
                subtitle: "Before Hue lights go out",
                icon: "moon.stars.fill",
                tint: Theme.green,
                isOn: bind(\.inBedBy1145, on: entry)
            )
            RuleRow(
                title: "No cheating",
                subtitle: nil,
                icon: "hand.raised.fill",
                tint: Theme.green,
                isOn: bind(\.noCheating, on: entry)
            )
        }
    }

    private var prizesButton: some View {
        Button {
            showPrizes = true
        } label: {
            Label("Weekly Prizes", systemImage: "gift.fill").font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .tint(Theme.primary)
        .padding(.top, 8)
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
    }

    private var nextRewardSummary: String? {
        let today = min(max(dayNumber, 1), totalDays)
        for week in 1...WeeklyPrize.totalWeeks {
            let unlock = WeeklyPrize.unlockDay(for: week)
            if today <= unlock {
                let prizeText = prizes.first(where: { $0.weekNumber == week })?.prize ?? ""
                let remaining = unlock - today
                let countLabel: String = {
                    if remaining == 0 { return "today" }
                    if remaining == 1 { return "in 1 day" }
                    return "in \(remaining) days"
                }()
                if prizeText.trimmingCharacters(in: .whitespaces).isEmpty {
                    return "Week \(week) prize unlocks \(countLabel) — tap to set"
                }
                return "Next prize \(countLabel): \(prizeText)"
            }
        }
        return nil
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
            if await missedPriorDay() {
                pendingMissedReset = true
            }
        }
    }

    private var iconNameForToday: String? {
        let day = min(max(dayNumber, 1), totalDays)
        let countdown = totalDays - day + 1
        return String(format: "AppIconDay%02d", countdown)
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
    var trackBackground: Color = Color.secondary.opacity(0.18)

    private let trackHeight: CGFloat = 12

    var body: some View {
        _ = store.revision
        return GeometryReader { geo in
            let width = geo.size.width
            let cell = width / CGFloat(totalDays)
            let progress = CGFloat(min(max(currentDay, 0), totalDays))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackBackground)

                Capsule()
                    // .fill(tint.opacity(0.85))
                    .frame(width: max(0, cell * progress))

                HStack(spacing: 0) {
                    ForEach(0..<totalDays, id: \.self) { index in
                        thumbnail(forDayIndex: index, size: cell)
                            .frame(width: cell, height: trackHeight)
                    }
                }
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

private struct MilestoneStrip: View {
    let totalDays: Int
    let currentDay: Int
    var unlockedColor: Color = Theme.highlight
    var lockedColor: Color = Color.white.opacity(0.2)

    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                ForEach(1...WeeklyPrize.totalWeeks, id: \.self) { week in
                    let unlockDay = WeeklyPrize.unlockDay(for: week)
                    let centerX = (CGFloat(unlockDay) - 0.5) * (width / CGFloat(totalDays))
                    let unlocked = currentDay >= unlockDay
                    Image(systemName: unlocked ? "gift.fill" : "gift")
                        .font(.caption2)
                        .foregroundStyle(unlocked ? unlockedColor : lockedColor)
                        .frame(width: 16, height: 16)
                        .position(x: centerX, y: 8)
                }
            }
        }
        .frame(height: 16)
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
                        .foregroundStyle(isOn ? .white : .primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(isOn ? Color.white.opacity(0.8) : .secondary)
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? .white : Color.secondary.opacity(0.5))
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .cardSurface(fill: isOn ? tint : Theme.surface)
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
                .fill(active ? Color.white.opacity(0.22) : Color.secondary.opacity(0.10))
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(active ? .white : Color.secondary)
        }
        .frame(width: 36, height: 36)
    }
}

private struct DietRow: View {
    @Bindable var entry: DayEntry
    let tint: Color
    @State private var expanded = false

    private var complete: Bool { entry.dietComplete }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    IconBadge(systemName: "fork.knife", tint: tint, active: complete)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Follow diet")
                            .font(.body.weight(.medium))
                            .foregroundStyle(complete ? .white : .primary)
                        Text(dietSummary)
                            .font(.caption)
                            .foregroundStyle(complete ? Color.white.opacity(0.8) : .secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(complete ? Color.white.opacity(0.8) : .secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                    Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(complete ? .white : Color.secondary.opacity(0.5))
                        .symbolEffect(.bounce, value: complete)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 8) {
                    SubItemRow(title: "Breakfast", icon: "frying.pan.fill", tint: tint, parentComplete: complete, isOn: $entry.meal1)
                    SubItemRow(title: "Fruit 1", icon: "applelogo", tint: tint, parentComplete: complete, isOn: $entry.fruit1)
                    SubItemRow(title: "Protein shake 1", icon: "takeoutbag.and.cup.and.straw.fill", tint: tint, parentComplete: complete, isOn: $entry.shake1)
                    SubItemRow(title: "Dinner", icon: "fork.knife", tint: tint, parentComplete: complete, isOn: $entry.meal2)
                    SubItemRow(title: "Fruit 2", icon: "carrot.fill", tint: tint, parentComplete: complete, isOn: $entry.fruit2)
                    SubItemRow(title: "Protein shake 2", icon: "cup.and.saucer.fill", tint: tint, parentComplete: complete, isOn: $entry.shake2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardSurface(fill: complete ? tint : Theme.surface)
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
    let parentComplete: Bool
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
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(parentComplete ? .white : .primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checkColor)
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(rowFill)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if parentComplete { return .white }
        return isOn ? tint : Color.secondary
    }

    private var checkColor: Color {
        if parentComplete { return .white }
        return isOn ? tint : Color.secondary.opacity(0.5)
    }

    private var rowFill: Color {
        if parentComplete { return Color.white.opacity(0.18) }
        return Theme.background.opacity(0.6)
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
                    Text("Drink 1 gallon of water")
                        .font(.body.weight(.medium))
                        .foregroundStyle(met ? .white : .primary)
                    Spacer()
                    Text("\(Int(ounces.rounded())) / \(Int(goal)) fl. oz.")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(met ? Color.white.opacity(0.9) : .secondary)
                }
                ProgressView(value: fraction)
                    .tint(met ? .white : tint)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(met ? Color.white.opacity(0.8) : .secondary)
            }
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(met ? .white : Color.secondary.opacity(0.5))
                .symbolEffect(.bounce, value: met)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardSurface(fill: met ? tint : Theme.surface)
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
                    Text("Take a progress photo")
                        .font(.body.weight(.medium))
                        .foregroundStyle(hasPhoto ? .white : .primary)
                    Text(hasPhoto ? "Tap to retake" : "Before post-workout shower")
                        .font(.caption)
                        .foregroundStyle(hasPhoto ? Color.white.opacity(0.8) : .secondary)
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
                    .foregroundStyle(hasPhoto ? .white : Color.secondary.opacity(0.5))
                    .symbolEffect(.bounce, value: hasPhoto)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .cardSurface(fill: hasPhoto ? tint : Theme.surface)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, ChallengeState.self], inMemory: true)
}
