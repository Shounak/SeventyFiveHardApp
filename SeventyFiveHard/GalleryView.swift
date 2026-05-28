import SwiftUI

struct GalleryView: View {
    let startDate: Date
    let totalDays: Int
    let store: PhotoStore

    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotoEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                GalleryGrid(store: store, startDate: startDate) { entry in
                    selection = entry
                }
                .padding(16)
            }
            .navigationTitle("Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selection) { entry in
                FullPhotoView(entry: entry, store: store)
            }
        }
    }
}

struct PhotoEntry: Identifiable {
    let date: Date
    let dayNumber: Int
    var id: Date { date }
}

// MARK: - Grid (built from the same primitives as the mosaic)

private struct GalleryGrid: View {
    let store: PhotoStore
    let startDate: Date
    let onTap: (PhotoEntry) -> Void

    private let columnCount = 2
    private let spacing: CGFloat = 8

    private var entries: [PhotoEntry] {
        _ = store.revision
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        return store.allPhotoDates().compactMap { date in
            let day = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
            let dayNumber = day + 1
            guard dayNumber >= 1 else { return nil }
            return PhotoEntry(date: date, dayNumber: dayNumber)
        }
    }

    var body: some View {
        let rows = chunked(entries, into: columnCount)
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let cellSide = (totalWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
            VStack(spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: spacing) {
                        ForEach(row) { entry in
                            cell(for: entry, side: cellSide)
                        }
                        if row.count < columnCount {
                            Color.clear.frame(width: cellSide, height: cellSide)
                        }
                    }
                }
            }
            .frame(width: totalWidth, alignment: .leading)
        }
        .frame(height: gridHeight(rowCount: rows.count))
    }

    @ViewBuilder
    private func cell(for entry: PhotoEntry, side: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.primary.opacity(0.05)
                .frame(width: side, height: side)

            if let img = store.thumbnail(for: entry.date, maxPixelSize: max(256, side * 3)) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipped()
            }

            Text("Day \(entry.dayNumber)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(8)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .id(store.revision)
        .onTapGesture { onTap(entry) }
    }

    // The GeometryReader needs an explicit height because it doesn't size to its children.
    private func gridHeight(rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return 0 }
        // Reserve a square area for each row using a square approximation; the actual
        // cellSide is recomputed from the parent width inside the body. We use UIScreen
        // here only for the *outer* container's height — the cells themselves still get
        // a precise size from the GeometryReader.
        let approxWidth = UIScreen.main.bounds.width - 32 // outer padding in GalleryView
        let approxCell = (approxWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        return CGFloat(rowCount) * approxCell + CGFloat(max(0, rowCount - 1)) * spacing
    }

    private func chunked(_ items: [PhotoEntry], into size: Int) -> [[PhotoEntry]] {
        guard size > 0 else { return [] }
        var result: [[PhotoEntry]] = []
        var i = 0
        while i < items.count {
            let end = min(i + size, items.count)
            result.append(Array(items[i..<end]))
            i = end
        }
        return result
    }
}

// MARK: - Full-screen viewer

private struct FullPhotoView: View {
    let entry: PhotoEntry
    let store: PhotoStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = store.loadImage(for: entry.date) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .navigationTitle("Day \(entry.dayNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
