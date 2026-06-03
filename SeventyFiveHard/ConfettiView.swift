import SwiftUI
import UIKit
import AVFoundation

struct ConfettiView: View {
    let trigger: Bool

    @State private var burstID: UUID?
    @State private var cheerPlayer: AVAudioPlayer?

    var body: some View {
        Group {
            if let id = burstID {
                ConfettiCanvas()
                    .id(id)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, newValue in
            guard newValue else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            playRandomCheer()
            let id = UUID()
            burstID = id
            Task {
                try? await Task.sleep(for: .seconds(4))
                if burstID == id {
                    withAnimation(.easeOut(duration: 0.4)) { burstID = nil }
                }
            }
        }
    }

    private func playRandomCheer() {
        let wavUrls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: "SoundEffects") ?? []
        let flacUrls = Bundle.main.urls(forResourcesWithExtension: "flac", subdirectory: "SoundEffects") ?? []
        let mp3Urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "SoundEffects") ?? []
        let urls = wavUrls + flacUrls + mp3Urls
        guard let url = urls.randomElement() else { return }
        cheerPlayer = try? AVAudioPlayer(contentsOf: url)
        cheerPlayer?.prepareToPlay()
        cheerPlayer?.play()
    }
}

private struct ConfettiCanvas: View {
    private let pieces: [Piece]
    private let start = Date()

    init() {
        var rng = SystemRandomNumberGenerator()
        self.pieces = (0..<140).map { _ in Piece(rng: &rng) }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    piece.draw(in: context, size: size, t: t)
                }
            }
        }
    }
}

private struct Piece {
    let startXRatio: Double
    let initialY: Double
    let driftX: Double
    let velocityY: Double
    let rotationSpeed: Double
    let initialRotation: Double
    let color: Color
    let size: CGSize

    init(rng: inout SystemRandomNumberGenerator) {
        startXRatio = .random(in: 0...1, using: &rng)
        initialY = .random(in: -260 ... -20, using: &rng)
        driftX = .random(in: -70...70, using: &rng)
        velocityY = .random(in: 220...460, using: &rng)
        rotationSpeed = .random(in: -7...7, using: &rng)
        initialRotation = .random(in: 0...(2 * .pi), using: &rng)
        color = palette.randomElement(using: &rng) ?? .red
        size = CGSize(
            width: .random(in: 6...10, using: &rng),
            height: .random(in: 10...16, using: &rng)
        )
    }

    func draw(in context: GraphicsContext, size canvasSize: CGSize, t: TimeInterval) {
        let x = startXRatio * canvasSize.width + driftX * t
        let y = initialY + velocityY * t
        let rot = initialRotation + rotationSpeed * t
        let opacity = max(0, min(1, 1.6 - t / 3.0))

        var ctx = context
        ctx.opacity = opacity
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: .radians(rot))
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
    }
}

private let palette: [Color] = [
    .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink
]
