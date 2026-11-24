import CryptoKit
import Foundation

enum JournalAssets {
    struct Entry: Decodable {
        let bucket: String
        let key: String
        let sha256: String
        let size: Int
    }
    private struct Index: Decodable {
        let release: String
        let files: [String: Entry]
    }
    private static let publishedRelease: String? = {
        guard let url = Bundle.main.url(forResource: "storage-release", withExtension: "json", subdirectory: "Configuration"),
              let release = try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: url)) else { return nil }
        return release["publishedRelease"]
    }()

    private static let index: Index? = {
        guard let url = Bundle.main.url(forResource: "storage-assets", withExtension: "json", subdirectory: "Configuration"),
              let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(Index.self, from: data) else { return nil }
        return index
    }()
    private static let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RoroAssets", isDirectory: true)

    private static func entry(_ path: String) -> (String, Entry)? {
        guard path.hasPrefix("assets/") else { return nil }
        let relative = String(path.dropFirst(7))
        guard let entry = index?.files[relative] else { return nil }
        return (relative, entry)
    }

    private static func local(_ relative: String, _ entry: Entry) -> URL {
        cache.appendingPathComponent(entry.sha256 + "-" + (relative as NSString).lastPathComponent)
    }

    // Synchronous UIKit consumers use verified cached bytes or the packaged copy.
    static func url(_ path: String) -> URL? {
        guard let (relative, entry) = entry(path) else { return nil }
        let cached = local(relative, entry)
        if FileManager.default.fileExists(atPath: cached.path) { return cached }
        guard let file = Bundle.main.resourceURL?.appendingPathComponent(relative),
              FileManager.default.fileExists(atPath: file.path) else { return nil }
        return file
    }

    static func fetch(_ path: String, token: String? = nil) async throws -> URL {
        guard let (relative, entry) = entry(path) else { throw roroError("This asset is unavailable.") }
        if entry.bucket == "roro-sources" || publishedRelease == nil || publishedRelease != index?.release {
            guard let file = url(path) else { throw roroError("This asset is unavailable.") }
            return file
        }
        let restricted = entry.bucket == "roro-media"
        guard !restricted || token != nil else { throw roroError("Please log in to view this media.") }
        let destination = local(relative, entry)
        do {
            return try await assetDownloads.file(destination: destination) {
                let config = try JournalAuthentication.Configuration.load()
                let access = restricted ? "authenticated" : "public"
                let endpoint = config.projectURL.appendingPathComponent("storage/v1/object")
                    .appendingPathComponent(access).appendingPathComponent(entry.bucket)
                    .appendingPathComponent(entry.key)
                var request = URLRequest(url: endpoint)
                if restricted, let token {
                    request.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
                    request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
                }
                let (data, response) = try await JournalAuthentication.transport.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count == entry.size,
                      SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == entry.sha256 else {
                    throw roroError("This asset could not be downloaded.")
                }
                try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
                try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                return destination
            }
        } catch {
            if let packaged = Bundle.main.resourceURL?.appendingPathComponent(relative),
               FileManager.default.fileExists(atPath: packaged.path) { return packaged }
            throw error
        }
    }

    private static let assetDownloads = Downloads()
    private actor Downloads {
        var requests: [URL: Task<URL, Error>] = [:]
        func file(destination: URL, download: @escaping () async throws -> URL) async throws -> URL {
            if FileManager.default.fileExists(atPath: destination.path) { return destination }
            if let task = requests[destination] { return try await task.value }
            let task = Task { try await download() }
            requests[destination] = task
            defer { requests[destination] = nil }
            return try await task.value
        }
    }
}
