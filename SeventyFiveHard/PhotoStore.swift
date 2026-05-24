import Foundation
import UIKit
import Observation

@Observable
final class PhotoStore {
    /// Bumped whenever a photo is saved/deleted so SwiftUI views relying on it re-render.
    private(set) var revision: Int = 0

    private let directory: URL

    init() {
        let fm = FileManager.default
        let support = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = support.appendingPathComponent("photos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.directory = dir
    }

    func url(for date: Date) -> URL {
        directory.appendingPathComponent(Self.filename(for: date))
    }

    func hasPhoto(for date: Date) -> Bool {
        FileManager.default.fileExists(atPath: url(for: date).path)
    }

    func loadImage(for date: Date) -> UIImage? {
        let path = url(for: date).path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    @discardableResult
    func save(_ image: UIImage, for date: Date) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return false }
        do {
            try data.write(to: url(for: date), options: .atomic)
            revision &+= 1
            return true
        } catch {
            return false
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func filename(for date: Date) -> String {
        "\(filenameFormatter.string(from: date)).jpg"
    }
}
