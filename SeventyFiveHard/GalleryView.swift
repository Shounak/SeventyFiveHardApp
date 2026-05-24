import SwiftUI

struct GalleryView: View {
    let startDate: Date
    let totalDays: Int
    let store: PhotoStore

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDayIndex: Int?

    private let columns = [GridItem](repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<totalDays, id: \.self) { dayIndex in
                        let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: startDate) ?? startDate
                        GalleryCell(dayNumber: dayIndex + 1, date: date, store: store)
                            .onTapGesture {
                                if store.hasPhoto(for: date) {
                                    selectedDayIndex = dayIndex
                                }
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { selectedDayIndex.map { GallerySelection(dayIndex: $0) } },
                set: { selectedDayIndex = $0?.dayIndex }
            )) { sel in
                let date = Calendar.current.date(byAdding: .day, value: sel.dayIndex, to: startDate) ?? startDate
                FullPhotoView(dayNumber: sel.dayIndex + 1, date: date, store: store)
            }
        }
    }
}

private struct GallerySelection: Identifiable {
    let dayIndex: Int
    var id: Int { dayIndex }
}

private struct GalleryCell: View {
    let dayNumber: Int
    let date: Date
    let store: PhotoStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = store.loadImage(for: date) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        Image(systemName: "camera")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    )
            }

            Text("\(dayNumber)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .id(store.revision)
    }
}

private struct FullPhotoView: View {
    let dayNumber: Int
    let date: Date
    let store: PhotoStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = store.loadImage(for: date) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .navigationTitle("Day \(dayNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
