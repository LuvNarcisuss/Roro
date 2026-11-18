import Foundation
import CryptoKit
import ZIPFoundation

final class PageArchive {
    func prepare() throws -> URL {
        let manager = FileManager.default
        guard let source = Bundle.main.url(forResource: "RoroWeb", withExtension: "zip", subdirectory: "AppResources"),
              let hashFile = Bundle.main.url(forResource: "RoroWeb", withExtension: "sha256", subdirectory: "AppResources") else {
            throw roroError("The photo library pages are missing. Please reinstall the app.")
        }
        let expected = try String(contentsOf: hashFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = SHA256.hash(data: try Data(contentsOf: source)).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw roroError("The app pages could not be read. Please reinstall the app.") }
        let root = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("RoroPages", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        // Re-extract immutable app pages each launch; private state lives elsewhere.
        let destination = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        do {
            let archive = try Archive(url: source, accessMode: .read)
            var total: UInt64 = 0
            var paths = Set<String>()
            for entry in archive {
                let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false)
                guard !entry.path.hasPrefix("/"), !entry.path.contains("\\"), !parts.contains(".."),
                      !parts.contains("."), entry.type != .symlink, paths.insert(entry.path).inserted else {
                    throw roroError("The app page package is invalid.")
                }
                total += UInt64(entry.uncompressedSize)
                guard total <= 150 * 1024 * 1024, paths.count <= 2000 else { throw roroError("The app page package is too large.") }
                _ = try archive.extract(entry, to: destination.appendingPathComponent(entry.path))
            }
            guard manager.fileExists(atPath: destination.appendingPathComponent("index.html").path) else { throw roroError("The app home page is missing.") }
            for old in try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where old != destination {
                try? manager.removeItem(at: old)
            }
            return destination
        } catch {
            try? manager.removeItem(at: destination)
            throw error
        }
    }
}
