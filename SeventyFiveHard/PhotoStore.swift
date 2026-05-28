import Foundation
import UIKit
import ImageIO
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

    /// All dates that have a saved photo, sorted most recent first.
    func allPhotoDates() -> [Date] {
        _ = revision
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
        let dates: [Date] = names.compactMap { name in
            guard name.hasSuffix(".jpg") else { return nil }
            let stem = String(name.dropLast(4))
            return Self.filenameFormatter.date(from: stem)
        }
        return dates.sorted(by: >)
    }

    func hasPhoto(for date: Date) -> Bool {
        FileManager.default.fileExists(atPath: url(for: date).path)
    }

    func loadImage(for date: Date) -> UIImage? {
        let path = url(for: date).path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private var thumbnailCache: [String: UIImage] = [:]

    func thumbnail(for date: Date, maxPixelSize: CGFloat = 64) -> UIImage? {
        let url = url(for: date)
        let key = "\(url.lastPathComponent)|\(Int(maxPixelSize))|\(revision)"
        if let cached = thumbnailCache[key] { return cached }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return nil
        }
        let img = UIImage(cgImage: cg)
        thumbnailCache[key] = img
        return img
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
